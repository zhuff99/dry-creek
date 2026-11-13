class_name Crop
extends Node2D
## Visual for one planted crop. Holds no rules; FarmGrid tells it what to show.
## The node origin sits on the tile's bottom edge so tall crops y-sort properly.

var _data: CropData
var _days_grown: int = 0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_show()


## Safe to call before the node is ready: when the farm is rebuilt from saved
## state, crops are added while the scene is still loading.
func setup(data: CropData, days_grown: int) -> void:
	_data = data
	_days_grown = days_grown
	_show()


func set_growth(days_grown: int) -> void:
	_days_grown = days_grown
	_show()


func _show() -> void:
	if _data == null or not is_node_ready():
		return
	_sprite.texture = _data.growth_sheet
	_sprite.hframes = _data.stage_count
	# Lift the sprite so its bottom edge rests on the node origin.
	_sprite.offset.y = -_data.growth_sheet.get_height() / 2.0
	_sprite.frame = _data.stage_for(_days_grown)
