class_name Crop
extends Node2D
## Visual for one planted crop. Holds no rules; FarmGrid tells it what to show.
## The node origin sits on the tile's bottom edge so tall crops y-sort properly.

var _data: CropData

@onready var _sprite: Sprite2D = $Sprite2D


## Call after the node is in the tree.
func setup(data: CropData, days_grown: int) -> void:
	_data = data
	_sprite.texture = data.growth_sheet
	_sprite.hframes = data.stage_count
	# Lift the sprite so its bottom edge rests on the node origin.
	_sprite.offset.y = -data.growth_sheet.get_height() / 2.0
	set_growth(days_grown)


func set_growth(days_grown: int) -> void:
	_sprite.frame = _data.stage_for(days_grown)
