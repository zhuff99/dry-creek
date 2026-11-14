class_name BuiltPiece
extends StaticBody2D
## One thing the player built, standing on its tile. It holds no rules:
## FarmGrid puts it there and tells it which neighbours it joins and how
## damaged it is, and it picks the picture to match.

## How the sprite sheet is laid out.
## SINGLE: one picture.
## FENCE: 16 columns, one per mix of joined sides (see the bits below), and
## a second row of the same pieces broken.
## GATE: two frames, hung across (0) or along (1) the way you walk.
enum Look { SINGLE, FENCE, GATE }

## Bits of `connections`: which sides have a piece to join.
const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const DAMAGED_TINT := Color(0.74, 0.66, 0.62)

@export var look: Look = Look.SINGLE

var connections: int = 0
var damage: int = 0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_show()


## Safe to call before the node is ready (the farm is rebuilt from saved
## state while its scene is still loading).
func refresh(joined_sides: int, damage_taken: int) -> void:
	connections = joined_sides
	damage = damage_taken
	_show()


func _show() -> void:
	if not is_node_ready():
		return
	var hurt := damage > 0
	match look:
		Look.FENCE:
			_sprite.frame_coords = Vector2i(connections, 1 if hurt else 0)
		Look.GATE:
			var along := connections & (NORTH | SOUTH) != 0 and connections & (EAST | WEST) == 0
			_sprite.frame = 1 if along else 0
			_sprite.modulate = DAMAGED_TINT if hurt else Color.WHITE
		_:
			_sprite.modulate = DAMAGED_TINT if hurt else Color.WHITE
