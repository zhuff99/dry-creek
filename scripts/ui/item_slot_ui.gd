class_name ItemSlotUI
extends Button
## One inventory slot: icon, stack count, a gauge for tools that hold
## something (water in the can), and a highlight border.
## Used by both the hotbar and the backpack panel.
##
## Stacks are dragged between slots with the mouse: drop on another slot to
## move, merge or swap; hold split_stack (Shift) as the drag starts to take
## half. Let go anywhere that is not a slot or a panel and the stack is
## dropped on the ground at the player's feet (EventBus.item_drop_requested).

## What a slot's drag carries: {"kind": DRAG_KIND, "index": slot, "count": n}.
const DRAG_KIND := &"inventory_slot"
const DRAGGED_FROM_ALPHA := 0.35

## Which inventory slot this shows.
@export var index: int = -1

## How many the current drag from this slot is carrying. 0 when not dragging.
var _drag_count: int = 0

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


static func is_slot_drag(data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == DRAG_KIND


func _get_drag_data(_at_position: Vector2) -> Variant:
	var stack := GameState.inventory.get_slot(index)
	if stack == null:
		return null
	var count := stack.count
	if Input.is_action_pressed(&"split_stack") and count > 1:
		# Half, rounded up, so a stack of 3 splits 2 and 1.
		count = (count + 1) / 2
	_drag_count = count
	set_drag_preview(_preview(stack, count))
	_icon.modulate.a = DRAGGED_FROM_ALPHA
	Audio.play(&"ui_pick")
	return {"kind": DRAG_KIND, "index": index, "count": count}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return is_slot_drag(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.index == index:
		return
	if GameState.inventory.move_part(data.index, index, data.count):
		Audio.play(&"ui_place")
	else:
		Audio.play(&"error")


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or _drag_count == 0:
		return
	var count := _drag_count
	_drag_count = 0
	_icon.modulate.a = 1.0
	# Nothing took it: it was let go over the world.
	if not get_viewport().gui_is_drag_successful():
		EventBus.item_drop_requested.emit(index, count)


## What follows the mouse: the icon, centred on the pointer, with its count.
func _preview(stack: ItemStack, count: int) -> Control:
	var holder := Control.new()
	var icon := TextureRect.new()
	icon.texture = stack.item.icon
	icon.position = -stack.item.icon.get_size() / 2.0
	holder.add_child(icon)
	if count > 1:
		var label := Label.new()
		label.text = str(count)
		label.position = Vector2(1, -2)
		holder.add_child(label)
	return holder
