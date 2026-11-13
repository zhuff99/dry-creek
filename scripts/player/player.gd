class_name Player
extends CharacterBody2D
## Movement, facing and the walk cycle. Item use and interaction live in
## child nodes. The node origin is at the character's feet (used for y-sorting
## and for working out which tile the player stands on).

# The walk sheet has one column per direction and one row per frame.
const COLUMN_DOWN := 0
const COLUMN_UP := 1
const COLUMN_LEFT := 2
const COLUMN_RIGHT := 3
const WALK_FRAMES := 4
const WALK_FPS := 8.0
## Seconds after being hurt during which nothing else can hurt you.
const HURT_GRACE := 0.6
const HURT_TINT := Color(1.0, 0.35, 0.3)
const HURT_SHAKE := 3.0

@export var move_speed: float = 80.0

## Cardinal direction the character is looking.
var facing := Vector2.DOWN
## True while an action animation (a tool swing) plays. Movement is locked.
var busy: bool = false
## True while a gun is drawn. Tools stay put away.
var armed: bool = false
## While true, walking does not turn the character (aiming decides that).
var facing_locked: bool = false
## Walking speed multiplier. Aiming and reloading slow you down.
var speed_factor: float = 1.0
## True while the body is in the aiming stance: arm thrust out, no walk cycle.
var aim_pose: bool = false:
	set(value):
		aim_pose = value
		if is_node_ready():
			_update_sprite()

## Which of the four walk frames is showing (0 when standing).
var walk_frame: int = 0

var _walk_time: float = 0.0
var _grace_left: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _aim_sprite: Sprite2D = $AimSprite
@onready var _sprite_home: Vector2 = _sprite.position
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group(&"player")


func _physics_process(delta: float) -> void:
	_grace_left = maxf(0.0, _grace_left - delta)
	var input := Vector2.ZERO
	if not busy:
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = input * move_speed * speed_factor
	if input == Vector2.ZERO:
		_walk_time = 0.0
		_update_sprite()
		return
	_walk_time += delta
	if facing_locked:
		_update_sprite()
	else:
		face(input)
	move_and_slide()


## Turns to the cardinal direction closest to `direction`. Zero is ignored.
func face(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	if absf(direction.x) >= absf(direction.y):
		facing = Vector2(signf(direction.x), 0)
	else:
		facing = Vector2(0, signf(direction.y))
	_update_sprite()


func _update_sprite() -> void:
	var column := COLUMN_DOWN
	if facing.y < 0:
		column = COLUMN_UP
	elif facing.x < 0:
		column = COLUMN_LEFT
	elif facing.x > 0:
		column = COLUMN_RIGHT
	_sprite.visible = not aim_pose
	_aim_sprite.visible = aim_pose
	if aim_pose:
		_aim_sprite.frame = column
		# The stance has no walk cycle; a one-pixel bob stands in for steps.
		var bob := int(_walk_time * WALK_FPS) % 2 if _walk_time > 0.0 else 0
		_aim_sprite.position = _sprite_home + Vector2(0, bob)
		walk_frame = 0
		return
	# Standing still shows the first frame; walking starts on the second so
	# the first step is visible straight away.
	var row := 0
	if _walk_time > 0.0:
		row = (int(_walk_time * WALK_FPS) + 1) % WALK_FRAMES
	walk_frame = row
	_sprite.frame_coords = Vector2i(column, row)


## Something hurt the player. Health itself lives in GameState; this is the
## flinch, and the moment of grace so one bite is not three.
func take_damage(amount: int) -> void:
	if _grace_left > 0.0 or amount <= 0:
		return
	_grace_left = HURT_GRACE
	Audio.play(&"hurt")
	shake(HURT_SHAKE)
	_sprite.modulate = HURT_TINT
	_aim_sprite.modulate = HURT_TINT
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "modulate", Color.WHITE, HURT_GRACE)
	tween.tween_property(_aim_sprite, "modulate", Color.WHITE, HURT_GRACE)
	GameState.hurt(amount)


## Knocks the body a little way and lets it settle back (a gun's recoil).
func kick(offset: Vector2) -> void:
	_sprite.offset = offset
	_aim_sprite.offset = offset
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "offset", Vector2.ZERO, 0.14)
	tween.tween_property(_aim_sprite, "offset", Vector2.ZERO, 0.14)


## A short jolt of the camera, for a gunshot.
func shake(pixels: float) -> void:
	_camera.offset = Vector2.from_angle(randf() * TAU) * pixels
	create_tween().tween_property(_camera, "offset", Vector2.ZERO, 0.12)


## Stops the camera from showing past the edge of the map. A place smaller
## than the screen (a room) is centred on it instead.
func set_camera_limits(bounds: Rect2i) -> void:
	var spare := (Vector2i(get_viewport_rect().size) - bounds.size).max(Vector2i.ZERO)
	var before := spare / 2
	bounds = bounds.grow_individual(before.x, before.y, spare.x - before.x, spare.y - before.y)
	_camera.limit_left = bounds.position.x
	_camera.limit_top = bounds.position.y
	_camera.limit_right = bounds.end.x
	_camera.limit_bottom = bounds.end.y
