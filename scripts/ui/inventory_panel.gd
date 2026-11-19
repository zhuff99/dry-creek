extends PanelContainer
## The backpack. Opens with the toggle_inventory action, at the top of the
## screen on whichever side the player is not, so it never covers them. The game keeps running while it is
## open: the player can walk, but clicks in the world do nothing
## (GameState.backpack_open).
##
## Stacks are dragged between slots (see ItemSlotUI), or clicked: click a
## slot, then another, to move or swap. The first HOTBAR_SIZE slots are the
## hotbar and sit in their own framed strip, like the hotbar on screen.
##
## A stack let go over the panel itself, between the slots, stays where it
## was; let go outside the panel, it is dropped on the ground.

const SLOT_SCENE := preload("res://scenes/ui/item_slot.tscn")
const NO_SLOT := -1
const EDGE := 4.0
const TOP := 22.0
## The player has to be this far past the middle of the screen before the
## backpack moves to the other side, so it does not flick back and forth.
const SIDE_SWAP_MARGIN := 40.0

var _slots: Array[ItemSlotUI] = []
## Slot picked up by the first click, waiting for a destination.
var _held_index: int = NO_SLOT

@onready var _grid: GridContainer = $Margin/VBox/Grid
@onready var _hotbar_grid: GridContainer = $Margin/VBox/HotbarStrip/HotbarGrid


func _ready() -> void:
	hide()
	for i: int in GameState.inventory.size():
		var slot: ItemSlotUI = SLOT_SCENE.instantiate()
		slot.index = i
		(_hotbar_grid if i < GameState.HOTBAR_SIZE else _grid).add_child(slot)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		_slots.append(slot)
	GameState.inventory.changed.connect(_refresh)
	EventBus.hotbar_slot_selected.connect(func(_index: int) -> void: _refresh())


func _process(_delta: float) -> void:
	if visible:
		_keep_clear_of_player()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_inventory"):
		toggle()
		get_viewport().set_input_as_handled()


## The button showing inventory slot `index`.
func slot_node(index: int) -> ItemSlotUI:
	return _slots[index]


func toggle() -> void:
	# Not while the night screen or a door has the game paused.
	if not visible and get_tree().paused:
		return
	visible = not visible
	GameState.backpack_open = visible
	if visible:
		reset_size()
		_keep_clear_of_player(true)
	Audio.play(&"ui_open" if visible else &"ui_close")
	_held_index = NO_SLOT
	_refresh()


func _on_slot_pressed(index: int) -> void:
	if _held_index == NO_SLOT:
		if GameState.inventory.get_slot(index) != null:
			_held_index = index
			Audio.play(&"ui_pick")
			_refresh()
		return
	Audio.play(&"ui_place")
	var from := _held_index
	_held_index = NO_SLOT
	GameState.inventory.move_slot(from, index)
	# move_slot does not emit when nothing moved (same slot), so redraw anyway.
	_refresh()


## Sits on the left of the screen while the player is on the right, and the
## other way about.
func _keep_clear_of_player(choose_now: bool = false) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var screen := get_viewport_rect().size
	var on_left := position.x < screen.x / 2.0
	if player != null:
		var player_x := player.get_global_transform_with_canvas().origin.x
		var middle := screen.x / 2.0
		var margin := 0.0 if choose_now else SIDE_SWAP_MARGIN
		if player_x < middle - margin:
			on_left = false
		elif player_x > middle + margin:
			on_left = true
	position = Vector2(EDGE if on_left else screen.x - size.x - EDGE, TOP)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return ItemSlotUI.is_slot_drag(data)


func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	pass  # Taking the drop is what keeps it out of the world.


func _refresh() -> void:
	if not visible:
		return
	for i: int in _slots.size():
		_slots[i].display(GameState.inventory.get_slot(i))
		# The click-picked slot, else the hotbar slot in hand.
		var marked := _held_index if _held_index != NO_SLOT else GameState.selected_slot
		_slots[i].set_highlighted(i == marked)
