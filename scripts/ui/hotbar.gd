extends HBoxContainer
## The first HOTBAR_SIZE inventory slots, always on screen. Click to select.

const SLOT_SCENE := preload("res://scenes/ui/item_slot.tscn")

var _slots: Array[ItemSlotUI] = []


func _ready() -> void:
	for i: int in GameState.HOTBAR_SIZE:
		var slot: ItemSlotUI = SLOT_SCENE.instantiate()
		add_child(slot)
		slot.pressed.connect(GameState.select_slot.bind(i))
		_slots.append(slot)
	GameState.inventory.changed.connect(_refresh)
	EventBus.hotbar_slot_selected.connect(_on_slot_selected)
	_refresh()


func _refresh() -> void:
	for i: int in _slots.size():
		_slots[i].display(GameState.inventory.get_slot(i))
		_slots[i].set_highlighted(i == GameState.selected_slot)


func _on_slot_selected(_index: int) -> void:
	_refresh()
