class_name CropData
extends Resource
## Definition of a plantable crop.

@export var id: StringName
@export var display_name: String
## Horizontal strip with one frame per growth stage, left to right.
## The last frame is the ripe plant. Frames can be taller than 16px.
@export var growth_sheet: Texture2D
@export_range(2, 12) var stage_count: int = 5
## Watered days needed before the crop can be harvested.
@export_range(1, 60) var days_to_mature: int = 4
@export var harvest_item: ItemData
@export_range(1, 20) var harvest_min: int = 1
@export_range(1, 20) var harvest_max: int = 1
## Watered days until it can be picked again. 0 = single harvest, plant is removed.
@export_range(0, 30) var regrow_days: int = 0


func is_mature(days_grown: int) -> bool:
	return days_grown >= days_to_mature


## Which frame of growth_sheet to show.
func stage_for(days_grown: int) -> int:
	if is_mature(days_grown):
		return stage_count - 1
	# Spread the unripe frames evenly across the growing period.
	return int(float(days_grown) / days_to_mature * (stage_count - 1))
