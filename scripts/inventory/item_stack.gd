class_name ItemStack
extends RefCounted
## A quantity of one item occupying one inventory slot.

var item: ItemData
var count: int


func _init(p_item: ItemData, p_count: int = 1) -> void:
	item = p_item
	count = p_count
