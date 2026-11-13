extends Node2D
## Hotbar selection and using the selected item on a tile.
##
## The target is the tile under the mouse, clamped to the tiles touching the
## player. A cursor shows it: bright when the click would do something.
## Holding the button keeps working, one use after another.

enum Action { NONE, HARVEST, TILL, WATER, REFILL, PLANT, CLEAR }

## How many tiles away from the player a tile can be targeted.
const REACH := 1
const CURSOR_VALID := Color(1, 1, 1, 0.9)
const CURSOR_INVALID := Color(1, 0.35, 0.3, 0.45)

var target_cell: Vector2i

var _farm_grid: FarmGrid
## True from a click that reached the world until the button is let go.
var _primary_held: bool = false

@onready var _player: Player = owner
@onready var _animator: PlayerToolAnimator = owner.get_node("ToolAnimator")
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

	if _primary_held:
		if not Input.is_action_pressed(&"primary_action"):
			_primary_held = false
		elif usable and not _player.busy:
			use_item_at(target_cell)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"primary_action"):
		# Only clicks that reach the world count; clicks on UI never get here.
		_primary_held = true
		_explain_if_useless(target_cell)
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
				if grid.is_water(cell):
					return Action.REFILL if stack.charge < stack.capacity() else Action.NONE
				if grid.can_water(cell) and _has_charge(stack):
					return Action.WATER
			_:
				# Axe, pickaxe, scythe: each clears its own kind of debris.
				if _can_clear(grid, cell, stack.item as ToolData):
					return Action.CLEAR
	elif stack.item is SeedData:
		return Action.PLANT if grid.can_plant(cell) else Action.NONE
	return Action.NONE


## Uses the selected item on `cell`. Tools play an animation first, so await
## this if you need to know when the use is over.
func use_item_at(cell: Vector2i) -> void:
	var grid := _get_farm_grid()
	if grid == null or _player.busy:
		return
	var where := grid.cell_center(cell)
	match action_at(cell):
		Action.HARVEST:
			_harvest(grid, cell, where)
		Action.TILL:
			await _use_tool(grid, cell, _held_tool().use_animation, _till.bind(grid, cell))
		Action.WATER:
			await _use_tool(grid, cell, _held_tool().use_animation, _pour_water.bind(grid, cell))
		Action.REFILL:
			await _use_tool(grid, cell, ToolData.UseAnimation.DIP, _refill_can, &"refill")
		Action.CLEAR:
			var chips := grid.debris_at(cell).chip_color
			var swish := _held_tool().start_sound
			await _use_tool(grid, cell, _held_tool().use_animation, _hit_debris.bind(grid, cell), swish, chips)
		Action.PLANT:
			var seed_item := GameState.selected_stack().item as SeedData
			if grid.plant(cell, seed_item.crop):
				GameState.inventory.remove_from_slot(GameState.selected_slot, 1)
				Audio.play(&"plant")
				EventBus.report(&"crop_planted", _player, where, {"crop": seed_item.crop.id})


## Plays a tool animation toward `cell`. `effect` runs when the tool lands.
## `start_sound` is the cue played as the motion begins; left out, it is the
## tool's own. `chips` colours the burst thrown up on impact.
func _use_tool(
	grid: FarmGrid,
	cell: Vector2i,
	motion: ToolData.UseAnimation,
	effect: Callable,
	start_sound: StringName = &"",
	chips: Color = PlayerToolAnimator.DIRT_COLOR,
) -> void:
	var tool_item := _held_tool()
	Audio.play(start_sound if start_sound != &"" else tool_item.start_sound)
	# One of eight directions; the tile underfoot uses wherever we already face.
	var offset := cell - grid.cell_at(_player.global_position)
	var direction := Vector2(offset).normalized() if offset != Vector2i.ZERO else _player.facing
	_player.busy = true
	_player.face(direction)
	await _animator.play(motion, tool_item.icon, direction, grid.cell_center(cell), effect, chips)
	_player.busy = false


func _till(grid: FarmGrid, cell: Vector2i) -> void:
	var stack := GameState.selected_stack()
	if grid.till(cell) and stack != null and stack.item is ToolData:
		Audio.play((stack.item as ToolData).use_sound)


func _pour_water(grid: FarmGrid, cell: Vector2i) -> void:
	var stack := GameState.selected_stack()
	# The player may have switched items mid-animation; only a can pours.
	if stack == null or not _has_charge(stack) or not grid.water(cell):
		return
	if stack.capacity() > 0:
		GameState.inventory.set_charge(GameState.selected_slot, stack.charge - 1)


func _refill_can() -> void:
	var stack := GameState.selected_stack()
	if stack == null or stack.capacity() <= 0:
		return
	GameState.inventory.set_charge(GameState.selected_slot, stack.capacity())
	EventBus.toast_requested.emit("%s filled." % stack.item.display_name)


## One tool hit on the debris at `cell`. The last hit removes it and hands
## over whatever it drops.
func _hit_debris(grid: FarmGrid, cell: Vector2i) -> void:
	var debris := grid.debris_at(cell)
	if debris == null:
		return
	if not grid.hit_debris(cell):
		Audio.play(debris.hit_sound)
		return
	Audio.play(debris.break_sound)
	var amount := randi_range(debris.drop_min, debris.drop_max)
	if debris.drop_item != null and amount > 0:
		GameState.inventory.add_item(debris.drop_item, amount)
		EventBus.toast_requested.emit("+%d %s" % [amount, debris.drop_item.display_name])
	EventBus.report(&"debris_cleared", _player, grid.cell_center(cell), {"debris": debris.id})


func _can_clear(grid: FarmGrid, cell: Vector2i, tool_item: ToolData) -> bool:
	var debris := grid.debris_at(cell)
	return debris != null and debris.tool == tool_item.tool_type and _has_room_for(debris)


## Checked before the first swing so a full bag never wastes the drop.
func _has_room_for(debris: DebrisData) -> bool:
	if debris.drop_item == null or debris.drop_max <= 0:
		return true
	return GameState.inventory.can_fit(debris.drop_item, debris.drop_max)


func _harvest(grid: FarmGrid, cell: Vector2i, where: Vector2) -> void:
	var crop := grid.crop_at(cell)
	# Check for room first so a full bag never destroys a harvest.
	if not GameState.inventory.can_fit(crop.harvest_item, crop.harvest_max):
		EventBus.toast_requested.emit("Your bag is full.")
		Audio.play(&"error")
		return
	var picked := grid.harvest(cell)
	GameState.inventory.add_item(picked.item, picked.count)
	Audio.play(&"harvest")
	EventBus.toast_requested.emit("+%d %s" % [picked.count, picked.item.display_name])
	EventBus.report(&"crop_harvested", _player, where, {"crop": crop.id, "count": picked.count})


## Says why a click did nothing, for the cases that are not obvious.
func _explain_if_useless(cell: Vector2i) -> void:
	var grid := _get_farm_grid()
	var stack := GameState.selected_stack()
	if grid == null or stack == null or action_at(cell) != Action.NONE:
		return
	var tool_item := stack.item as ToolData
	if tool_item == null:
		return
	var debris := grid.debris_at(cell)
	var reason := ""
	if tool_item.tool_type == ToolData.ToolType.WATERING_CAN and grid.can_water(cell) and not _has_charge(stack):
		reason = "The can is empty. Fill it at the river."
	elif debris != null and debris.tool != tool_item.tool_type:
		reason = "%s: use the %s." % [debris.display_name, _tool_name(debris.tool)]
	elif debris != null and not _has_room_for(debris):
		reason = "Your bag is full."
	if reason != "":
		EventBus.toast_requested.emit(reason)
		Audio.play(&"error")


## "pickaxe", "watering can": the enum name in plain words.
func _tool_name(type: ToolData.ToolType) -> String:
	var key: String = ToolData.ToolType.keys()[type]
	return key.to_lower().replace("_", " ")


func _held_tool() -> ToolData:
	return GameState.selected_stack().item as ToolData


## True if the tool has uses left, or never runs out.
func _has_charge(stack: ItemStack) -> bool:
	return stack.capacity() <= 0 or stack.charge > 0


func _holding_farm_item() -> bool:
	var stack := GameState.selected_stack()
	return stack != null and (stack.item is ToolData or stack.item is SeedData)


## The farm grid of the current area, or null where there is no farmland.
func _get_farm_grid() -> FarmGrid:
	if not is_instance_valid(_farm_grid):
		_farm_grid = get_tree().get_first_node_in_group(&"farm_grid") as FarmGrid
	return _farm_grid
