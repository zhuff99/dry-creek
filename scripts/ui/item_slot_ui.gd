class_name ItemSlotUI
extends Button
## One inventory slot: icon, stack count, a gauge for tools that hold
## something (water in the can), and a highlight border.
## Used by both the hotbar and the backpack panel.

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count
@onready var _highlight: Panel = $Highlight
@onready var _gauge: ColorRect = $Gauge
@onready var _gauge_fill: ColorRect = $Gauge/Fill


func display(stack: ItemStack) -> void:
	if stack == null:
		_icon.texture = null
		_count.text = ""
		tooltip_text = ""
		_gauge.hide()
		return
	_icon.texture = stack.item.icon
	_count.text = str(stack.count) if stack.count > 1 else ""
	tooltip_text = stack.item.display_name
	var capacity := stack.capacity()
	_gauge.visible = capacity > 0
	if capacity > 0:
		_gauge_fill.size.x = roundf(_gauge.size.x * stack.charge / float(capacity))


func set_highlighted(on: bool) -> void:
	_highlight.visible = on
