extends SceneTree
## Dev tool: plays the Milestone 1 loop by script, checks the results, and saves
## screenshots. Needs a window, so do not pass --headless.
##
##   godot --path . -s res://tools/smoke_test.gd -- <screenshot_folder>
##
## Exit code is the number of failed checks.

const CORN_CELLS: Array[Vector2i] = [Vector2i(17, 17), Vector2i(18, 17), Vector2i(19, 17)]
const BEAN_CELLS: Array[Vector2i] = [Vector2i(17, 19), Vector2i(18, 19), Vector2i(19, 19)]
const HOE_SLOT := 0
const CAN_SLOT := 1
const CORN_SEED_SLOT := 2
const BEAN_SEED_SLOT := 3
const CAN_CAPACITY := 20
## Where the trail from the cabin meets the river.
const BANK_CELL := Vector2i(13, 4)
const RIVER_CELL := Vector2i(13, 3)
## Real seconds before the run gives up.
const WATCHDOG_SECONDS := 90.0

var _out_dir := "user://smoke"
var _failures := 0

# This script compiles before the autoloads exist, so it fetches them by path
# and avoids naming project classes (which would compile them too early).
var _state: Node
var _clock: Node
var _bus: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# A script error would otherwise leave the window open forever.
	create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	_run()


func _on_watchdog() -> void:
	print("
SMOKE TEST: TIMEOUT (a step never finished)")
	quit(99)


func _run() -> void:
	_state = root.get_node("GameState")
	_clock = root.get_node("GameClock")
	_bus = root.get_node("EventBus")
	Engine.time_scale = 3.0

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	var player: Node2D = main.get_node("World/Farm/Entities/Player")
	var item_user: Node = player.get_node("ItemUser")
	var grid: Node = main.get_node("World/Farm/FarmGrid")
	var crate: Node2D = main.get_node("World/Farm/Entities/ShippingCrate")
	var panel: Control = main.get_node("UI/InventoryPanel")
	var objects: TileMapLayer = main.get_node("World/Farm/Map/Objects")
	await _shot("01_start")

	# --- Movement and collision: walk left from spawn into the cabin wall.
	var start_x := player.global_position.x
	Input.action_press(&"move_left")
	await _physics_frames(120)
	Input.action_release(&"move_left")
	_check(player.global_position.x < start_x, "player moves left")
	_check(player.global_position.x > 100.0, "cabin wall stops the player (x=%.1f)" % player.global_position.x)

	# --- Tilling rules.
	_check(grid.can_till(CORN_CELLS[0]), "open dirt can be tilled")
	_check(not grid.can_till(Vector2i(8, 12)), "cabin floor cannot be tilled")
	_check(not grid.can_till(RIVER_CELL), "water cannot be tilled")
	_check(not grid.can_till(BANK_CELL), "the river bank cannot be tilled")
	var debris := objects.get_used_cells()
	_check(debris.size() > 60, "rocks, trees and brush are scattered around (%d)" % debris.size())
	_check(not grid.can_till(debris[0]), "a tile with something on it cannot be tilled")

	# --- Till, plant, water.
	player.global_position = grid.cell_center(Vector2i(18, 18)) + Vector2(0, 4)
	await _physics_frames(3)
	var all_cells: Array[Vector2i] = []
	all_cells.append_array(CORN_CELLS)
	all_cells.append_array(BEAN_CELLS)
	_state.select_slot(HOE_SLOT)
	for cell: Vector2i in all_cells:
		await item_user.use_item_at(cell)
	_check(_state.farm.plots.size() == 6, "six plots tilled")
	_state.select_slot(CORN_SEED_SLOT)
	for cell: Vector2i in CORN_CELLS:
		await item_user.use_item_at(cell)
	_state.select_slot(BEAN_SEED_SLOT)
	for cell: Vector2i in BEAN_CELLS:
		await item_user.use_item_at(cell)
	_check(_state.inventory.get_slot(CORN_SEED_SLOT).count == 9, "three corn seeds used")
	_check(_state.inventory.get_slot(BEAN_SEED_SLOT).count == 9, "three bean seeds used")
	await item_user.use_item_at(CORN_CELLS[0])
	_check(_state.inventory.get_slot(BEAN_SEED_SLOT).count == 9, "cannot plant on an occupied plot")
	await _water(item_user, all_cells)
	_check(_state.farm.get_plot(CORN_CELLS[0]).watered, "plots are watered")
	await _shot("02_planted_and_watered")

	# --- A watered night grows crops; a dry night does not.
	await _sleep()
	_check(_clock.day == 2, "sleeping advances to day 2")
	_check(_state.farm.get_plot(CORN_CELLS[0]).days_grown == 1, "watered crop grew one day")
	_check(not _state.farm.get_plot(CORN_CELLS[0]).watered, "soil dries overnight")
	await _sleep()
	_check(_state.farm.get_plot(CORN_CELLS[0]).days_grown == 1, "unwatered crop did not grow")
	await _shot("03_day3_dry")

	# --- Water daily. Beans (3 days) ripen a day before corn (4 days).
	for i: int in 2:
		await _water(item_user, all_cells)
		await _sleep()
	_check(grid.can_harvest(BEAN_CELLS[0]), "beans are ripe after 3 watered days")
	_check(not grid.can_harvest(CORN_CELLS[0]), "corn is not ripe yet")
	# Only the corn: clicking a ripe crop picks it, whatever is in hand.
	await _water(item_user, CORN_CELLS)
	await _sleep()
	_check(grid.can_harvest(CORN_CELLS[0]), "corn is ripe after 4 watered days")
	await _shot("04_ripe")

	# --- Harvest.
	for cell: Vector2i in all_cells:
		await item_user.use_item_at(cell)
	var corn: Resource = root.get_node("ItemDB").get_item(&"corn")
	var corn_slot := _find_slot(corn)
	_check(corn_slot != -1, "corn is in the inventory")
	_check(_find_slot(root.get_node("ItemDB").get_item(&"beans")) != -1, "beans are in the inventory")
	_check(not _state.farm.get_plot(CORN_CELLS[0]).has_crop(), "corn plant is removed after harvest")
	_check(_state.farm.get_plot(BEAN_CELLS[0]).has_crop(), "bean plant stays to regrow")
	_check(not grid.can_harvest(BEAN_CELLS[0]), "beans are not instantly ripe again")
	await _shot("05_harvested")

	# --- Ship through the real interact input.
	player.global_position = crate.global_position + Vector2(0, 16)
	await _physics_frames(5)
	_state.select_slot(corn_slot)
	var corn_count: int = _state.inventory.get_slot(corn_slot).count
	_press(&"interact")
	await _frames(3)
	_check(_state.shipping_bin.get(&"corn", 0) == corn_count, "corn went into the shipping bin")
	_check(_state.inventory.get_slot(corn_slot) == null, "corn left the inventory")
	await _shot("06_shipped")
	_bus.sleep_requested.emit()
	await create_timer(1.0).timeout
	await _shot("07_night_summary")
	while paused:
		await process_frame
	_check(_state.money == corn_count * corn.sell_price, "shipment paid $%d overnight" % _state.money)

	# --- Hotbar keys and the backpack panel through real input.
	_press(&"hotbar_2")
	await _frames(2)
	_check(_state.selected_slot == 1, "number key selects a hotbar slot")
	_press(&"hotbar_next")
	await _frames(2)
	_check(_state.selected_slot == 2, "mouse wheel cycles the hotbar")
	_press(&"toggle_inventory")
	await _frames(3)
	_check(panel.visible and paused, "backpack opens and pauses")
	await _shot("08_backpack")
	_state.inventory.move_slot(CORN_SEED_SLOT, 20)
	_check(_state.inventory.get_slot(20) != null, "stacks can be moved between slots")
	_state.inventory.move_slot(20, CORN_SEED_SLOT)
	_press(&"toggle_inventory")
	await _frames(3)
	_check(not panel.visible and not paused, "backpack closes and unpauses")

	# --- Clicking uses the selected item on the targeted tile.
	player.global_position = grid.cell_center(Vector2i(24, 21)) + Vector2(0, 4)
	_state.select_slot(HOE_SLOT)
	await _frames(3)
	var target: Vector2i = item_user.target_cell
	var reach: Vector2i = (target - grid.cell_at(player.global_position)).abs()
	_check(maxi(reach.x, reach.y) <= 1, "target tile is within reach of the player")
	_press(&"primary_action")
	await _frames(2)
	await _until_idle(player)
	_release(&"primary_action")
	# Let the release register, or the held button keeps working the next tile.
	await _frames(3)
	_check(_state.farm.is_tilled(target), "left click tills the targeted tile")

	# --- Tool animations, at real speed so the screenshots catch them mid-move.
	Engine.time_scale = 1.0
	var stand := Vector2i(26, 18)
	player.global_position = grid.cell_center(stand) + Vector2(0, 4)
	await _physics_frames(2)
	var locked_at := player.global_position
	item_user.use_item_at(stand + Vector2i.RIGHT)
	_check(player.busy, "using a tool locks the player")
	_check(not _state.farm.is_tilled(stand + Vector2i.RIGHT), "tile is not tilled before the swing lands")
	Input.action_press(&"move_down")
	await create_timer(0.17).timeout
	await _shot("09_hoe_swing_right")
	Input.action_release(&"move_down")
	await _until_idle(player)
	_check(player.global_position == locked_at, "player cannot walk during a swing")
	_check(_state.farm.is_tilled(stand + Vector2i.RIGHT), "tile is tilled once the swing lands")
	_check(player.facing == Vector2.RIGHT, "player faces the tile being worked")

	item_user.use_item_at(stand + Vector2i.UP)
	await create_timer(0.1).timeout
	await _shot("10_hoe_windup_up")
	await _until_idle(player)
	_check(player.facing == Vector2.UP, "player turns to face a tile above")
	item_user.use_item_at(stand + Vector2i.LEFT)
	await create_timer(0.2).timeout
	await _shot("11_hoe_strike_left")
	await _until_idle(player)

	_state.select_slot(CAN_SLOT)
	_state.inventory.set_charge(CAN_SLOT, CAN_CAPACITY)
	item_user.use_item_at(stand + Vector2i.RIGHT)
	await create_timer(0.3).timeout
	await _shot("12_watering_right")
	await _until_idle(player)
	_check(_state.farm.get_plot(stand + Vector2i.RIGHT).watered, "tile is watered after the pour")
	item_user.use_item_at(stand + Vector2i.LEFT)
	await create_timer(0.3).timeout
	await _shot("13_watering_left")
	await _until_idle(player)
	item_user.use_item_at(stand + Vector2i.UP)
	await create_timer(0.3).timeout
	await _shot("14_watering_up")
	await _until_idle(player)
	_check(not player.busy and not player.get_node("ToolAnimator/HeldTool").visible, "tool is put away afterwards")

	# --- The watering can runs dry and is filled at the river.
	_check(_state.inventory.get_slot(CAN_SLOT).charge == CAN_CAPACITY - 3, "each watering uses one unit of water")
	_state.select_slot(HOE_SLOT)
	await item_user.use_item_at(stand + Vector2i.DOWN)
	_state.select_slot(CAN_SLOT)
	_state.inventory.set_charge(CAN_SLOT, 0)
	await item_user.use_item_at(stand + Vector2i.DOWN)
	_check(not _state.farm.get_plot(stand + Vector2i.DOWN).watered, "an empty can does not water")
	await _shot("15_field_and_brush")

	player.global_position = grid.cell_center(BANK_CELL) + Vector2(0, 4)
	await _physics_frames(3)
	_check(grid.is_water(RIVER_CELL), "the river is water")
	Input.action_press(&"move_up")
	await _physics_frames(60)
	Input.action_release(&"move_up")
	_check(grid.cell_at(player.global_position) == BANK_CELL, "the river cannot be walked into")
	item_user.use_item_at(RIVER_CELL)
	await create_timer(0.25).timeout
	await _shot("16_filling_can")
	await _until_idle(player)
	_check(_state.inventory.get_slot(CAN_SLOT).charge == CAN_CAPACITY, "the can fills at the river")
	await item_user.use_item_at(RIVER_CELL)
	_check(not player.busy, "a full can does not refill again")
	Engine.time_scale = 3.0

	print("\nSMOKE TEST: %s (%d failed)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(_failures)


func _water(item_user: Node, cells: Array[Vector2i]) -> void:
	_state.select_slot(CAN_SLOT)
	# Shortcut: top the can up here so the growing checks do not need a river trip.
	_state.inventory.set_charge(CAN_SLOT, CAN_CAPACITY)
	for cell: Vector2i in cells:
		await item_user.use_item_at(cell)


func _sleep() -> void:
	_bus.sleep_requested.emit()
	await process_frame
	while paused:
		await process_frame


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _release(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)


## Waits for a tool animation to finish.
func _until_idle(player: Node2D) -> void:
	while player.busy:
		await process_frame


func _find_slot(item: Resource) -> int:
	for i: int in _state.inventory.size():
		var stack: Variant = _state.inventory.get_slot(i)
		if stack != null and stack.item == item:
			return i
	return -1


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _physics_frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out_dir.path_join(name + ".png"))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
