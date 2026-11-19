class_name BuildMenu
extends SidePanel
## The build menu, the way survival games do it: with the saw in hand,
## right-click (build_menu) opens it. Tabs along the top pick a category,
## the grid shows that category's pieces, and the panel below says what the
## piece under the mouse is and what it costs, in red if you are short.
## Click a piece to build it next; the menu closes and the saw's preview
## shows it on the ground.
##
## Everything here comes from ItemDB.buildables(), so a new BuildableData
## resource appears in the menu, in its own category tab if it names a new
## one, with no change here.

const CELL := Vector2(22, 22)
const COLUMNS := 8
## A piece you cannot afford: dimmed, and its cost in red.
const SHORT := Color(1.0, 0.45, 0.4)
const CANNOT_AFFORD := Color(1, 1, 1, 0.35)
const ICON_SIZE := 16

var _category: String = ""
var _tabs: Dictionary[String, Button] = {}
var _pieces: Dictionary[StringName, Button] = {}
var _tab_group := ButtonGroup.new()
## The piece the details are about: the one under the mouse, or else the
## one the saw is set to.
var _shown: BuildableData

@onready var _tab_row: HBoxContainer = $Margin/VBox/Tabs
@onready var _grid: GridContainer = $Margin/VBox/Grid
@onready var _name_label: Label = $Margin/VBox/Details/Name
@onready var _cost_label: Label = $Margin/VBox/Details/Cost
@onready var _about_label: Label = $Margin/VBox/Details/About


func _ready() -> void:
	super()
	_grid.columns = COLUMNS
	for piece: BuildableData in ItemDB.buildables():
		if not _tabs.has(piece.category):
			_tabs[piece.category] = _make_tab(piece.category)
		_pieces[piece.id] = _make_piece_button(piece)
	GameState.inventory.changed.connect(_refresh)
	EventBus.blueprint_changed.connect(_refresh)
	# Putting the saw away closes the menu.
	EventBus.hotbar_slot_selected.connect(func(_index: int) -> void:
		if visible and not _holding_saw():
			close())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build_menu"):
		if visible:
			close()
			get_viewport().set_input_as_handled()
		elif _holding_saw() and not _player_armed():
			open()
			get_viewport().set_input_as_handled()
		return
	super(event)


## The button for the piece with this id.
func piece_button(id: StringName) -> Button:
	return _pieces[id]


func tab_button(category: String) -> Button:
	return _tabs[category]


func shown_category() -> String:
	return _category


func _on_opened() -> void:
	var current := GameState.blueprint()
	_choose_category(current.category if current != null else _tabs.keys()[0])
	_show_details(current)


## Makes `piece` what the saw builds and closes the menu.
func choose(piece: BuildableData) -> void:
	GameState.set_blueprint(piece.id)
	Audio.play(&"ui_place")
	close()


func _choose_category(category: String) -> void:
	_category = category
	_tabs[category].button_pressed = true
	for id: StringName in _pieces:
		_pieces[id].visible = ItemDB.get_buildable(id).category == category
	_refresh()
	reset_size()


func _make_tab(category: String) -> Button:
	var tab := Button.new()
	tab.text = category
	tab.toggle_mode = true
	tab.button_group = _tab_group
	tab.focus_mode = Control.FOCUS_NONE
	tab.pressed.connect(func() -> void:
		Audio.play(&"select")
		_choose_category(category))
	_tab_row.add_child(tab)
	return tab


func _make_piece_button(piece: BuildableData) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CELL
	button.focus_mode = Control.FOCUS_NONE
	button.icon = _menu_icon(piece.icon)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.toggle_mode = true
	button.tooltip_text = piece.display_name
	button.pressed.connect(choose.bind(piece))
	button.mouse_entered.connect(_show_details.bind(piece))
	button.mouse_exited.connect(func() -> void: _show_details(GameState.blueprint()))
	_grid.add_child(button)
	return button


## Icons taller than a tile (the lantern post) show their top tile only, so
## every cell is drawn at whole pixels.
func _menu_icon(icon: Texture2D) -> Texture2D:
	if icon.get_height() <= ICON_SIZE:
		return icon
	var top := AtlasTexture.new()
	top.atlas = icon
	top.region = Rect2(0, 0, ICON_SIZE, ICON_SIZE)
	return top


func _show_details(piece: BuildableData) -> void:
	_shown = piece
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	var current := GameState.blueprint()
	for id: StringName in _pieces:
		var piece := ItemDB.get_buildable(id)
		var button := _pieces[id]
		button.modulate = Color.WHITE if _can_afford(piece) else CANNOT_AFFORD
		# The piece the saw is set to stays pressed in.
		button.set_pressed_no_signal(piece == current)
	if _shown == null:
		_name_label.text = ""
		_cost_label.text = ""
		_about_label.text = ""
		return
	var have := GameState.inventory.count_of(_shown.material)
	_name_label.text = _shown.display_name
	_cost_label.text = "%s %d   (you have %d)" % [_shown.material.display_name, _shown.material_count, have]
	_cost_label.modulate = Color.WHITE if have >= _shown.material_count else SHORT
	_about_label.text = _shown.description


func _can_afford(piece: BuildableData) -> bool:
	return GameState.inventory.count_of(piece.material) >= piece.material_count


func _holding_saw() -> bool:
	var stack := GameState.selected_stack()
	return stack != null and stack.item is ToolData and (stack.item as ToolData).tool_type == ToolData.ToolType.SAW


func _player_armed() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	return player != null and player.armed
