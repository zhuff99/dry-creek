extends Node2D
## Hotbar selection and using the selected item on a tile.
##
## The target is the tile under the mouse, clamped to the tiles touching the
## player. A cursor shows it: bright when the click would do something.
## Holding the button keeps working, one use after another.

enum Action { NONE, HARVEST, TILL, WATER, REFILL, PLANT, CLEAR, REPAIR, BUILD }

## How many tiles away from the player a tile can be targeted.
const REACH := 1
const CURSOR_VALID := Color(1, 1, 1, 0.9)
const CURSOR_INVALID := Color(1, 0.35, 0.3, 0.45)
## What mending is done with: one of these for each point of damage.
const REPAIR_ITEM := &"wood"
const GHOST_TINT := Color(1, 1, 1, 0.55)

var target_cell: Vector2i

var _farm_grid: FarmGrid
## True from a click that reached the world until the button is let go.
var _primary_held: bool = false

@onready var _player: Player = owner
@onready var _animator: PlayerToolAnimator = owner.get_node("ToolAnimator")
@onready var _cursor: Sprite2D = $TileCursor
## A see-through picture of what the saw is about to build.
@onready var _ghost: Sprite2D = $BuildGhost


func _ready() -> void:
	# Hidden until the first frame places it; a new area arrives paused.
	_cursor.hide()
	_ghost.hide()
	_ghost.modulate = GHOST_TINT


func _process(_delta: float) -> void:
	var grid := _get_farm_grid()
	# No tile work indoors, or with a gun in hand.
	if grid == null or _player.armed:
		_cursor.hide()
		_ghost.hide()
		_primary_held = false
		return
	var player_cell := grid.cell_at(_player.global_position)
	var offset := grid.cell_at(get_global_mouse_position()) - player_cell
	target_cell = player_cell + offset.clampi(-REACH, REACH)
	_cursor.global_position = grid.cell_center(target_cell)
	var usable := action_at(target_cell) != Action.NONE
	_cursor.modulate = CURSOR_VALID if usable else CURSOR_INVALID
	# No cursor at all while holding something that never acts on tiles.
	_cursor.visible = usable or _holding_farm_item()
	_show_ghost(grid)

	if _primary_held:
		if not Input.is_action_pressed(&"primary_action"):
			_primary_held = false
		elif usable and not _player.busy:
			use_item_at(target_cell)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"primary_action"):
		if _player.armed:
			return
		# Only clicks that reach the world count; clicks on UI never get here.
		_primary_held = true
		_explain_if_useless(target_cell)
		_explain_if_tired(target_cell)
		use_item_at(target_cell)
	elif event.is_action_pressed(&"aim") and _holding_tool(ToolData.ToolType.SAW) and not _player.armed:
		dismantle_at(target_cell)
	elif event.is_action_pressed(&"cycle_blueprint") and _holding_tool(ToolData.ToolType.SAW):
		GameState.cycle_blueprint()
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
			ToolData.ToolType.HAMMER:
				return Action.REPAIR if _can_repair(grid, cell) else Action.NONE
			ToolData.ToolType.SAW:
				return Action.BUILD if _can_build(grid, cell) else Action.NONE
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
	var action := action_at(cell)
	# Too tired: nothing happens. With the button held, work picks up again
	# by itself as stamina comes back.
	var cost := stamina_cost_of(action)
	if not GameState.can_exert(cost):
		return
	GameState.exert(cost)
	match action:
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
		Action.REPAIR:
			await _use_tool(grid, cell, _held_tool().use_animation, _repair.bind(grid, cell))
		Action.BUILD:
			await _use_tool(grid, cell, _held_tool().use_animation, _build.bind(grid, cell))
		Action.PLANT:
			var seed_item := GameState.selected_stack().item as SeedData
			if grid.plant(cell, seed_item.crop):
				GameState.inventory.remove_from_slot(GameState.selected_slot, 1)
				Audio.play(&"plant")
				EventBus.report(&"crop_planted", _player, where, {"crop": seed_item.crop.id})


## Stamina `action` takes with the item in hand. Swinging or pouring a tool
## is work; planting, picking and filling the can are not.
func stamina_cost_of(action: Action) -> float:
	match action:
		Action.TILL, Action.WATER, Action.CLEAR, Action.REPAIR, Action.BUILD:
			return _held_tool().stamina_cost
	return 0.0


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


## Takes down what is built at `cell` and hands back its wood, less a piece
## for each blow it had taken. True if there was something to take down.
func dismantle_at(cell: Vector2i) -> bool:
	var grid := _get_farm_grid()
	if grid == null or _player.busy:
		return false
	var damage: int = GameState.farm.built_damage.get(cell, 0)
	var piece := GameState.farm.unbuild(cell)
	if piece == null:
		return false
	Audio.play(&"chop")
	var back := maxi(piece.material_count - damage, 0)
	if back > 0:
		GameState.inventory.add_item(piece.material, back)
		EventBus.toast_requested.emit("+%d %s" % [back, piece.material.display_name])
	return true


## One swing of the hammer at `cell`: a point of damage mended for a piece
## of wood.
func _repair(grid: FarmGrid, cell: Vector2i) -> void:
	if not _can_repair(grid, cell):
		return
	GameState.inventory.remove_item(ItemDB.get_item(REPAIR_ITEM), 1)
	if GameState.farm.built_damage.get(cell, 0) > 0:
		GameState.farm.repair_built(cell, 1)
	else:
		_repairable_at(grid, cell).repair(1)
	Audio.play(&"chop")
	if _damage_at(grid, cell) <= 0:
		EventBus.toast_requested.emit("Mended.")


func _build(grid: FarmGrid, cell: Vector2i) -> void:
	if not _can_build(grid, cell):
		return
	var piece := GameState.blueprint()
	GameState.inventory.remove_item(piece.material, piece.material_count)
	GameState.farm.build(cell, piece)
	Audio.play(&"chop")
	EventBus.report(&"piece_built", _player, grid.cell_center(cell), {"piece": piece.id})


func _can_repair(grid: FarmGrid, cell: Vector2i) -> bool:
	return _damage_at(grid, cell) > 0 and GameState.inventory.count_of(ItemDB.get_item(REPAIR_ITEM)) > 0


## Points of damage on whatever is at `cell`: something built there, or a
## building that covers the tile.
func _damage_at(grid: FarmGrid, cell: Vector2i) -> int:
	var damage: int = GameState.farm.built_damage.get(cell, 0)
	if damage > 0:
		return damage
	var thing := _repairable_at(grid, cell)
	return thing.repair_needed() if thing != null else 0


## The building at `cell` that can be mended (a node in the "repairable"
## group, like the cabin), or null.
func _repairable_at(grid: FarmGrid, cell: Vector2i) -> Node:
	for thing: Node in get_tree().get_nodes_in_group(&"repairable"):
		if thing.covers_cell(grid, cell):
			return thing
	return null


## True if the saw's current piece can go up at `cell`: bare ground, not
## underfoot, and the wood to make it.
func _can_build(grid: FarmGrid, cell: Vector2i) -> bool:
	var piece := GameState.blueprint()
	return piece != null and grid.can_build(cell) and cell != grid.cell_at(_player.global_position) \
			and GameState.inventory.count_of(piece.material) >= piece.material_count


func _show_ghost(grid: FarmGrid) -> void:
	var piece := GameState.blueprint()
	_ghost.visible = piece != null and not _player.busy and action_at(target_cell) == Action.BUILD
	if not _ghost.visible:
		return
	_ghost.texture = piece.icon
	# Standing on the bottom edge of the tile, as the real piece will.
	_ghost.offset = Vector2(0, -piece.icon.get_height() / 2.0)
	_ghost.global_position = grid.cell_center(target_cell) + Vector2(0, grid.ground_layer.tile_set.tile_size.y / 2.0)


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
	var piece := GameState.blueprint()
	if tool_item.tool_type == ToolData.ToolType.HAMMER and _damage_at(grid, cell) > 0:
		reason = "You need wood to mend that."
	elif tool_item.tool_type == ToolData.ToolType.SAW and piece != null and grid.can_build(cell) \
			and GameState.inventory.count_of(piece.material) < piece.material_count:
		reason = "A %s takes %d %s." % [piece.display_name.to_lower(), piece.material_count, piece.material.display_name.to_lower()]
	elif tool_item.tool_type == ToolData.ToolType.WATERING_CAN and grid.can_water(cell) and not _has_charge(stack):
		reason = "The can is empty. Fill it at the river."
	elif debris != null and debris.tool != tool_item.tool_type:
		reason = "%s: use the %s." % [debris.display_name, _tool_name(debris.tool)]
	elif debris != null and not _has_room_for(debris):
		reason = "Your bag is full."
	if reason != "":
		EventBus.toast_requested.emit(reason)
		Audio.play(&"error")


## Says so when a click did nothing for want of stamina.
func _explain_if_tired(cell: Vector2i) -> void:
	if _player.busy:
		return
	var cost := stamina_cost_of(action_at(cell))
	if GameState.can_exert(cost):
		return
	if GameState.is_worn_out_for(cost):
		EventBus.toast_requested.emit("You're worn out. Get some sleep.")
	else:
		EventBus.toast_requested.emit("Out of breath. Give it a moment.")
	EventBus.stamina_lacking.emit()
	Audio.play(&"error")


## "pickaxe", "watering can": the enum name in plain words.
func _tool_name(type: ToolData.ToolType) -> String:
	var key: String = ToolData.ToolType.keys()[type]
	return key.to_lower().replace("_", " ")


func _holding_tool(type: ToolData.ToolType) -> bool:
	var stack := GameState.selected_stack()
	return stack != null and stack.item is ToolData and (stack.item as ToolData).tool_type == type


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
