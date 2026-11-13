extends Node2D
## Hotbar selection and using the selected item on a tile.
##
## The target is the tile under the mouse, clamped to the tiles touching the
## player. A cursor shows it: bright when the click would do something.

enum Action { NONE, HARVEST, TILL, WATER, PLANT }

## How many tiles away from the player a tile can be targeted.
const REACH := 1
const CURSOR_VALID := Color(1, 1, 1, 0.9)
const CURSOR_INVALID := Color(1, 0.35, 0.3, 0.45)

var target_cell: Vector2i

var _farm_grid: FarmGrid

@onready var _player: Player = owner
@onready var _cursor: Sprite2D = $TileCursor


func _process(_delta: float) -> void:
	var grid := _get_farm_grid()
	if grid == null:
		_cursor.hide()
		return
	var player_cell := grid.cell_at(_player.global_position)
	var offset := grid.cell_at(get_global_mouse_position()) - player_cell
	target_cell = player_cell + offset.clampi(-REACH, REACH)
	_cursor.global_position = grid.cell_center(target_cell)
	var usable := action_at(target_cell) != Action.NONE
	_cursor.modulate = CURSOR_VALID if usable else CURSOR_INVALID
	# No cursor at all while holding something that never acts on tiles.
	_cursor.visible = usable or _holding_farm_item()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"primary_action"):
		use_item_at(target_cell)
	elif event.is_action_pressed(&"hotbar_next"):
		GameState.select_slot(GameState.selected_slot + 1)
	elif event.is_action_pressed(&"hotbar_prev"):
		GameState.select_slot(GameState.selected_slot - 1)
	else:
		for i: int in GameState.HOTBAR_SIZE:
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				GameState.select_slot(i)
				return


## What clicking `cell` would do with the currently selected item.
func action_at(cell: Vector2i) -> Action:
	var grid := _get_farm_grid()
	if grid == null:
		return Action.NONE
	# Ripe crops can be picked no matter what is in hand.
	if grid.can_harvest(cell):
		return Action.HARVEST
	var stack := GameState.selected_stack()
	if stack == null:
		return Action.NONE
	if stack.item is ToolData:
		match (stack.item as ToolData).tool_type:
			ToolData.ToolType.HOE:
				return Action.TILL if grid.can_till(cell) else Action.NONE
			ToolData.ToolType.WATERING_CAN:
				return Action.WATER if grid.can_water(cell) else Action.NONE
	elif stack.item is SeedData:
		return Action.PLANT if grid.can_plant(cell) else Action.NONE
	return Action.NONE


func use_item_at(cell: Vector2i) -> void:
	var grid := _get_farm_grid()
	if grid == null:
		return
	var where := grid.cell_center(cell)
	match action_at(cell):
		Action.HARVEST:
			_harvest(grid, cell, where)
		Action.TILL:
			grid.till(cell)
		Action.WATER:
			grid.water(cell)
		Action.PLANT:
			var seed_item := GameState.selected_stack().item as SeedData
			if grid.plant(cell, seed_item.crop):
				GameState.inventory.remove_from_slot(GameState.selected_slot, 1)
				EventBus.report(&"crop_planted", _player, where, {"crop": seed_item.crop.id})


func _harvest(grid: FarmGrid, cell: Vector2i, where: Vector2) -> void:
	var crop := grid.crop_at(cell)
	# Check for room first so a full bag never destroys a harvest.
	if not GameState.inventory.can_fit(crop.harvest_item, crop.harvest_max):
		EventBus.toast_requested.emit("Your bag is full.")
		return
	var picked := grid.harvest(cell)
	GameState.inventory.add_item(picked.item, picked.count)
	EventBus.toast_requested.emit("+%d %s" % [picked.count, picked.item.display_name])
	EventBus.report(&"crop_harvested", _player, where, {"crop": crop.id, "count": picked.count})


func _holding_farm_item() -> bool:
	var stack := GameState.selected_stack()
	return stack != null and (stack.item is ToolData or stack.item is SeedData)


## The farm grid of the current area, or null where there is no farmland.
func _get_farm_grid() -> FarmGrid:
	if not is_instance_valid(_farm_grid):
		_farm_grid = get_tree().get_first_node_in_group(&"farm_grid") as FarmGrid
	return _farm_grid
