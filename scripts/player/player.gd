class_name Player
extends CharacterBody2D
## Movement and facing. Item use and interaction live in child nodes.
## The node origin is at the character's feet (used for y-sorting and for
## working out which tile the player stands on).

# Columns of the character sheet. Facing left is the side frame flipped.
const FRAME_DOWN := 0
const FRAME_SIDE := 1
const FRAME_UP := 2

@export var move_speed: float = 80.0

## Cardinal direction the character is looking.
var facing := Vector2.DOWN
## True while an action animation (a tool swing) plays. Movement is locked.
var busy: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _camera: Camera2D = $Camera2D


func _physics_process(_delta: float) -> void:
	if busy:
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = input * move_speed
	if input != Vector2.ZERO:
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
	_sprite.flip_h = facing.x < 0
	if facing.y > 0:
		_sprite.frame = FRAME_DOWN
	elif facing.y < 0:
		_sprite.frame = FRAME_UP
	else:
		_sprite.frame = FRAME_SIDE


## Stops the camera from showing past the edge of the map.
func set_camera_limits(bounds: Rect2i) -> void:
	_camera.limit_left = bounds.position.x
	_camera.limit_top = bounds.position.y
	_camera.limit_right = bounds.end.x
	_camera.limit_bottom = bounds.end.y
