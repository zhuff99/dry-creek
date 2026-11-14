class_name Coyote
extends CharacterBody2D
## A coyote on a night raid. It has a job, eating a crop or tearing at the
## cabin, and it gets on with it unless the player comes close or shoots it,
## in which case it goes for the player instead.
##
## Its pack (CoyotePack) hands out the jobs and the PathGrid finds the way.

signal died

enum State { TRAVEL, WORK, CHASE, RECOVER, DEAD }
enum Job { NONE, CROP, CABIN, HUNT }

## Seconds between looking for a new way to a moving target.
const REPATH_SECONDS := 0.4
## Close enough to a point on the way to head for the next one.
const WAYPOINT_REACH := 4.0
## Close enough to the job to start on it.
const JOB_REACH := 9.0
## Seconds it stays after the player once shot, however far they run.
const GRUDGE_SECONDS := 8.0
const RUN_FPS := 7.0
const FADE_SECONDS := 0.6

@export var data: CreatureData

var state: State = State.TRAVEL
var job: Job = Job.NONE
var health: int = 0
## The crop tile it is after, when the job is a crop.
var job_cell := Vector2i(-1, -1)

var _pack: CoyotePack
var _player: Player
var _paths: PathGrid
var _goal := Vector2.ZERO
var _route := PackedVector2Array()
var _route_index: int = 0
var _repath_wait: float = 0.0
var _state_time: float = 0.0
var _anim_time: float = 0.0
var _grudge: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	add_to_group(&"coyotes")
	health = data.max_health
	_sprite.texture = data.sprite_sheet
	_hurtbox.shot.connect(_on_shot)


## Called by the pack once the coyote is on the map.
func join(pack: CoyotePack, paths: PathGrid) -> void:
	_pack = pack
	_paths = paths
	_take_job()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	_state_time += delta
	_anim_time += delta
	_grudge = maxf(_grudge - delta, 0.0)
	_repath_wait -= delta
	var to_player := Vector2.INF
	if _player != null:
		to_player = _player.global_position - global_position
	var distance := to_player.length()

	match state:
		State.TRAVEL:
			if distance <= data.notice_radius or job == Job.HUNT:
				_enter(State.CHASE)
			elif _follow_route(data.move_speed):
				_arrive()
		State.WORK:
			velocity = Vector2.ZERO
			if distance <= data.notice_radius:
				_enter(State.CHASE)
			elif _state_time >= data.work_seconds:
				_finish_work()
		State.CHASE:
			if distance <= data.strike_radius:
				velocity = Vector2.ZERO
				_face(to_player)
				Audio.play(data.attack_sound)
				_player.take_damage(data.damage)
				_enter(State.RECOVER)
			elif distance > data.calm_radius and _grudge <= 0.0 and job != Job.HUNT:
				_take_job()
			else:
				if _repath_wait <= 0.0:
					_route_to(_player.global_position)
				_follow_route(data.chase_speed)
		State.RECOVER:
			# A step back before it comes in again.
			velocity = -to_player.normalized() * data.move_speed * 0.5 if to_player.is_finite() else Vector2.ZERO
			move_and_slide()
			if _state_time >= data.recover_seconds:
				_enter(State.CHASE)
	_update_sprite()


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0
	_repath_wait = 0.0


## Asks the pack what to do next and sets off.
func _take_job() -> void:
	job_cell = Vector2i(-1, -1)
	job = Job.HUNT
	if _pack != null:
		job = _pack.job_for(self)
	match job:
		Job.CROP:
			job_cell = _pack.crop_for(self)
			_goal = _pack.farm_grid.cell_center(job_cell)
		Job.CABIN:
			_goal = _pack.cabin_spot()
		_:
			_goal = global_position
	_route_to(_goal)
	_enter(State.TRAVEL)


func _arrive() -> void:
	match job:
		Job.CROP:
			# Someone may have picked it, or another coyote got there first.
			if _pack.farm_grid.crop_at(job_cell) == null:
				_take_job()
				return
			_enter(State.WORK)
		Job.CABIN:
			_face(Vector2.UP)
			_enter(State.WORK)
		_:
			_take_job()


func _finish_work() -> void:
	match job:
		Job.CROP:
			if GameState.farm.eat_crop(job_cell):
				Audio.play(&"crop_eaten")
				EventBus.report(&"crop_eaten", self, global_position, {"cell": job_cell})
			_take_job()
		Job.CABIN:
			Audio.play(&"cabin_hit")
			GameState.damage_cabin(1)
			# Keeps at it until the wall can take no more, then finds other work.
			if GameState.cabin_damage >= GameState.CABIN_MAX_DAMAGE:
				_take_job()
			else:
				_enter(State.WORK)
		_:
			_take_job()


func _route_to(where: Vector2) -> void:
	_repath_wait = REPATH_SECONDS
	_route = _paths.path(global_position, where) if _paths != null else PackedVector2Array([where])
	# The first point is the tile it already stands on.
	_route_index = 1 if _route.size() > 1 else 0


## Walks along the route. True once the end is reached (or there is no way).
func _follow_route(speed: float) -> bool:
	if _route_index >= _route.size():
		velocity = Vector2.ZERO
		return true
	var target := _route[_route_index]
	var last := _route_index == _route.size() - 1
	if global_position.distance_to(target) <= (JOB_REACH if last else WAYPOINT_REACH):
		_route_index += 1
		return _route_index >= _route.size()
	velocity = global_position.direction_to(target) * speed
	_face(velocity)
	move_and_slide()
	return false


func _face(direction: Vector2) -> void:
	if absf(direction.x) > 0.1 and direction.is_finite():
		# The sheet faces right.
		_sprite.flip_h = direction.x < 0.0


func _update_sprite() -> void:
	var moving := velocity.length() > 1.0 and state != State.RECOVER
	var frame := 0
	if moving:
		frame = int(_anim_time * RUN_FPS) % 2
	elif state == State.WORK:
		# Head down and up: worrying at a crop or a wall.
		frame = int(_state_time * 5.0) % 2
	_sprite.frame = frame


func _on_shot(hit: Shot) -> void:
	if state == State.DEAD:
		return
	health -= hit.damage
	if health <= 0:
		_die()
		return
	Audio.play(data.warn_sound)
	_sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)
	_grudge = GRUDGE_SECONDS
	_enter(State.CHASE)


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_hurtbox.set_deferred(&"monitorable", false)
	$Hurtbox/CollisionShape2D.set_deferred(&"disabled", true)
	$CollisionShape2D.set_deferred(&"disabled", true)
	Audio.play(data.death_sound)
	var amount := randi_range(data.drop_min, data.drop_max)
	if data.drop_item != null and amount > 0:
		var left_over := GameState.inventory.add_item(data.drop_item, amount)
		if left_over < amount:
			EventBus.toast_requested.emit("+%d %s" % [amount - left_over, data.drop_item.display_name])
		else:
			EventBus.toast_requested.emit("Your bag is full.")
	GameState.coyotes_killed_tonight += 1
	EventBus.report(&"creature_killed", _player, global_position, {"creature": data.id})
	died.emit()
	_sprite.flip_v = true
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)
