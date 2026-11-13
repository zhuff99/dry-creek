class_name Player
extends CharacterBody2D
## Movement only. Item use and interaction live in child nodes.
## The node origin is at the character's feet (used for y-sorting and for
## working out which tile the player stands on).

@export var move_speed: float = 80.0

## Last direction moved. Drives sprite facing once real art is in.
var facing := Vector2.DOWN

@onready var _camera: Camera2D = $Camera2D


func _physics_process(_delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = input * move_speed
	if input != Vector2.ZERO:
		facing = input
	move_and_slide()


## Stops the camera from showing past the edge of the map.
func set_camera_limits(bounds: Rect2i) -> void:
	_camera.limit_left = bounds.position.x
	_camera.limit_top = bounds.position.y
	_camera.limit_right = bounds.end.x
	_camera.limit_bottom = bounds.end.y
