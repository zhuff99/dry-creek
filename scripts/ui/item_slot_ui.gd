class_name ItemSlotUI
extends Button
## One inventory slot: icon, stack count, and a highlight border.
## Used by both the hotbar and the backpack panel.

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count
@onready var _highlight: Panel = $Highlight


func display(stack: ItemStack) -> void:
	if stack == null:
		_icon.texture = null
		_count.text = ""
		tooltip_text = ""
		return
	_icon.texture = stack.item.icon
	_count.text = str(stack.count) if stack.count > 1 else ""
	tooltip_text = stack.item.display_name


func set_highlighted(on: bool) -> void:
	_highlight.visible = on
