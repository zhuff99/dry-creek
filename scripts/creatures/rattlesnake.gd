class_name Rattlesnake
extends CharacterBody2D
## A rattlesnake. It minds its own business until someone comes near, then
## coils and rattles. Back off and it settles; come closer and it strikes,
## then has to gather itself before it can strike again.
##
## It is hard to see against the dirt on purpose: the rattle is the warning.
## One hit on its Hurtbox per point of health kills it.

signal died

enum State { IDLE, WARN, STRIKE, RECOVER, DEAD }

const COLUMN_DOWN := 0
const COLUMN_UP := 1
const COLUMN_LEFT := 2
const COLUMN_RIGHT := 3
const FRAMES := 4
const AMBLE_FPS := 4.0
const RATTLE_FPS := 14.0
## Seconds between rattle sounds while it warns.
const RATTLE_EVERY := 0.3
## How close the strike has to get to the player's feet to count.
const BITE_RANGE := 9.0
const FADE_SECONDS := 0.5

@export var data: CreatureData

var state: State = State.IDLE
var health: int = 0
var facing := Vector2.DOWN

var _home: Vector2
var _player: Player
## Seconds spent in the current state.
var _state_time: float = 0.0
var _anim_time: float = 0.0
var _rattle_wait: float = 0.0
## Idle: where it is ambling to, and how long until it picks again.
var _amble_direction := Vector2.ZERO
var _amble_left: float = 0.0
var _strike_direction := Vector2.ZERO
var _has_bitten: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _alert: Label = $Alert
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _sprite_home: Vector2 = _sprite.position


func _ready() -> void:
	add_to_group(&"wildlife")
	health = data.max_health
	_home = global_position
	_sprite.texture = data.sprite_sheet
	_alert.hide()
	_hurtbox.shot.connect(_on_shot)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	_state_time += delta
	_anim_time += delta
	var to_player := Vector2.INF
	if _player != null:
		to_player = _player.global_position - global_position
	var distance := to_player.length()

	match state:
		State.IDLE:
			_amble(delta)
			if distance <= data.notice_radius:
				_enter(State.WARN)
		State.WARN:
			velocity = Vector2.ZERO
			_face(to_player)
			_rattle(delta)
			if distance > data.calm_radius:
				_enter(State.IDLE)
			elif distance <= data.strike_radius and _state_time >= data.warn_seconds:
				_strike_direction = to_player.normalized()
				_has_bitten = false
				Audio.play(data.attack_sound)
				_enter(State.STRIKE)
		State.STRIKE:
			velocity = _strike_direction * data.strike_reach / data.strike_seconds
			move_and_slide()
			if not _has_bitten and distance <= BITE_RANGE:
				_has_bitten = true
				_player.take_damage(data.damage)
			if _state_time >= data.strike_seconds:
				_enter(State.RECOVER)
		State.RECOVER:
			velocity = Vector2.ZERO
			if _state_time >= data.recover_seconds:
				# Straight back to warning; it has already said its piece.
				_enter(State.WARN)
				_state_time = data.warn_seconds
	_update_sprite()


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0
	_rattle_wait = 0.0
	_alert.visible = next == State.WARN


## Slow, aimless wandering near where it started.
func _amble(delta: float) -> void:
	_amble_left -= delta
	if _amble_left <= 0.0:
		_amble_left = randf_range(1.0, 3.0)
		if randf() < 0.5:
			_amble_direction = Vector2.ZERO
		else:
			_amble_direction = Vector2.from_angle(randf() * TAU)
			# Too far from home: head back.
			if global_position.distance_to(_home) > data.wander_radius:
				_amble_direction = global_position.direction_to(_home)
	velocity = _amble_direction * data.move_speed
	if _amble_direction != Vector2.ZERO:
		_face(_amble_direction)
		move_and_slide()


func _rattle(delta: float) -> void:
	_rattle_wait -= delta
	if _rattle_wait <= 0.0:
		_rattle_wait = RATTLE_EVERY
		Audio.play(data.warn_sound)


func _face(direction: Vector2) -> void:
	if direction == Vector2.ZERO or not direction.is_finite():
		return
	if absf(direction.x) >= absf(direction.y):
		facing = Vector2(signf(direction.x), 0)
	else:
		facing = Vector2(0, signf(direction.y))


func _update_sprite() -> void:
	var column := COLUMN_DOWN
	if facing.y < 0:
		column = COLUMN_UP
	elif facing.x < 0:
		column = COLUMN_LEFT
	elif facing.x > 0:
		column = COLUMN_RIGHT
	var row := 0
	var shiver := 0.0
	match state:
		State.IDLE:
			if velocity != Vector2.ZERO:
				row = int(_anim_time * AMBLE_FPS) % FRAMES
		State.WARN:
			# Coiled and buzzing: quick frames and a one-pixel shiver.
			row = int(_anim_time * RATTLE_FPS) % FRAMES
			shiver = 1.0 if int(_anim_time * RATTLE_FPS * 2.0) % 2 == 0 else 0.0
		State.STRIKE:
			row = 1
	_sprite.frame_coords = Vector2i(column, row)
	_sprite.position = _sprite_home + Vector2(shiver, 0.0)


func _on_shot(hit: Shot) -> void:
	if state == State.DEAD:
		return
	health -= hit.damage
	if health <= 0:
		_die()
		return
	# Hurt but alive: it is done warning.
	_sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)
	_enter(State.WARN)
	_state_time = data.warn_seconds


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_alert.hide()
	_hurtbox.set_deferred(&"monitorable", false)
	$Hurtbox/CollisionShape2D.set_deferred(&"disabled", true)
	Audio.play(data.death_sound)
	var amount := randi_range(data.drop_min, data.drop_max)
	if data.drop_item != null and amount > 0:
		var left_over := GameState.inventory.add_item(data.drop_item, amount)
		if left_over < amount:
			EventBus.toast_requested.emit("+%d %s" % [amount - left_over, data.drop_item.display_name])
		else:
			EventBus.toast_requested.emit("Your bag is full.")
	EventBus.report(&"creature_killed", _player, global_position, {"creature": data.id})
	died.emit()
	# Roll onto its back and fade.
	_sprite.flip_v = true
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)
