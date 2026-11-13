extends PanelContainer
## Full backpack view. Opens with the toggle_inventory action and pauses the
## game while open. Click a slot, then another, to move or swap stacks.

const SLOT_SCENE := preload("res://scenes/ui/item_slot.tscn")
const NO_SLOT := -1

var _slots: Array[ItemSlotUI] = []
## Slot picked up by the first click, waiting for a destination.
var _held_index: int = NO_SLOT

@onready var _grid: GridContainer = $Margin/VBox/Grid


func _ready() -> void:
	hide()
	for i: int in GameState.inventory.size():
		var slot: ItemSlotUI = SLOT_SCENE.instantiate()
		_grid.add_child(slot)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		_slots.append(slot)
	GameState.inventory.changed.connect(_refresh)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_inventory"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	# If something else paused the game (the day transition), stay closed.
	if not visible and get_tree().paused:
		return
	visible = not visible
	get_tree().paused = visible
	_held_index = NO_SLOT
	_refresh()


func _on_slot_pressed(index: int) -> void:
	if _held_index == NO_SLOT:
		if GameState.inventory.get_slot(index) != null:
			_held_index = index
			_refresh()
		return
	var from := _held_index
	_held_index = NO_SLOT
	GameState.inventory.move_slot(from, index)
	# move_slot does not emit when nothing moved (same slot), so redraw anyway.
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	for i: int in _slots.size():
		_slots[i].display(GameState.inventory.get_slot(i))
		_slots[i].set_highlighted(i == _held_index)
