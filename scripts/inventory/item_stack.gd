class_name ItemStack
extends RefCounted
## A quantity of one item occupying one inventory slot.

var item: ItemData
var count: int
## Uses left in a tool that has a capacity (water in the can). Unused otherwise.
var charge: int = 0


func _init(p_item: ItemData, p_count: int = 1) -> void:
	item = p_item
	count = p_count
	# Tools start full.
	charge = capacity()


## How many uses this stack's tool can hold, or 0 if it never runs out.
func capacity() -> int:
	var tool_item := item as ToolData
	return tool_item.capacity if tool_item != null else 0
