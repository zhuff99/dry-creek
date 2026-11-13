class_name FarmPlot
extends RefCounted
## State of one tilled tile. Plain data so it can be saved as-is.

var watered: bool = false
## Empty when nothing is planted.
var crop_id: StringName = &""
## Number of days the crop was watered, which is what drives growth.
var days_grown: int = 0


func has_crop() -> bool:
	return crop_id != &""
