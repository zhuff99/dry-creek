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

@export var move_speed: float = 80.0

## Cardinal direction the character is looking.
var facing := Vector2.DOWN
## True while an action animation (a tool swing) plays. Movement is locked.
var busy: bool = false

var _walk_time: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _camera: Camera2D = $Camera2D


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not busy:
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = input * move_speed
	if input == Vector2.ZERO:
		_walk_time = 0.0
		_update_sprite()
		return
	_walk_time += delta
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
	# Standing still shows the first frame; walking starts on the second so
	# the first step is visible straight away.
	var row := 0
	if _walk_time > 0.0:
		row = (int(_walk_time * WALK_FPS) + 1) % WALK_FRAMES
	_sprite.frame_coords = Vector2i(column, row)


## Stops the camera from showing past the edge of the map.
func set_camera_limits(bounds: Rect2i) -> void:
	_camera.limit_left = bounds.position.x
	_camera.limit_top = bounds.position.y
	_camera.limit_right = bounds.end.x
	_camera.limit_bottom = bounds.end.y
