extends SceneTree
## Dev tool: plays the Milestone 1 loop by script, checks the results, and saves
## screenshots. Needs a window, so do not pass --headless.
##
##   godot --path . -s res://tools/smoke_test.gd -- <screenshot_folder>
##
## Exit code is the number of failed checks.

const CORN_CELLS: Array[Vector2i] = [Vector2i(17, 10), Vector2i(18, 10), Vector2i(19, 10)]
const BEAN_CELLS: Array[Vector2i] = [Vector2i(17, 12), Vector2i(18, 12), Vector2i(19, 12)]
const HOE_SLOT := 0
const CAN_SLOT := 1
const CORN_SEED_SLOT := 2
const BEAN_SEED_SLOT := 3

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
	_run()


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
	await _shot("01_start")

	# --- Movement and collision: walk left from spawn into the cabin wall.
	var start_x := player.global_position.x
	Input.action_press(&"move_left")
	await _physics_frames(120)
	Input.action_release(&"move_left")
	_check(player.global_position.x < start_x, "player moves left")
	_check(player.global_position.x > 100.0, "cabin wall stops the player (x=%.1f)" % player.global_position.x)

	# --- Tilling rules.
	_check(not grid.can_till(Vector2i(14, 9)), "sand cannot be tilled")
	_check(grid.can_till(CORN_CELLS[0]), "field dirt can be tilled")

	# --- Till, plant, water.
	player.global_position = grid.cell_center(Vector2i(18, 11)) + Vector2(0, 4)
	await _physics_frames(3)
	var all_cells: Array[Vector2i] = []
	all_cells.append_array(CORN_CELLS)
	all_cells.append_array(BEAN_CELLS)
	_state.select_slot(HOE_SLOT)
	for cell: Vector2i in all_cells:
		item_user.use_item_at(cell)
	_check(_state.farm.plots.size() == 6, "six plots tilled")
	_state.select_slot(CORN_SEED_SLOT)
	for cell: Vector2i in CORN_CELLS:
		item_user.use_item_at(cell)
	_state.select_slot(BEAN_SEED_SLOT)
	for cell: Vector2i in BEAN_CELLS:
		item_user.use_item_at(cell)
	_check(_state.inventory.get_slot(CORN_SEED_SLOT).count == 9, "three corn seeds used")
	_check(_state.inventory.get_slot(BEAN_SEED_SLOT).count == 9, "three bean seeds used")
	item_user.use_item_at(CORN_CELLS[0])
	_check(_state.inventory.get_slot(BEAN_SEED_SLOT).count == 9, "cannot plant on an occupied plot")
	_water(item_user, all_cells)
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
		_water(item_user, all_cells)
		await _sleep()
	_check(grid.can_harvest(BEAN_CELLS[0]), "beans are ripe after 3 watered days")
	_check(not grid.can_harvest(CORN_CELLS[0]), "corn is not ripe yet")
	# Only the corn: clicking a ripe crop picks it, whatever is in hand.
	_water(item_user, CORN_CELLS)
	await _sleep()
	_check(grid.can_harvest(CORN_CELLS[0]), "corn is ripe after 4 watered days")
	await _shot("04_ripe")

	# --- Harvest.
	for cell: Vector2i in all_cells:
		item_user.use_item_at(cell)
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
	player.global_position = grid.cell_center(Vector2i(24, 14)) + Vector2(0, 4)
	_state.select_slot(HOE_SLOT)
	await _frames(3)
	var target: Vector2i = item_user.target_cell
	var reach: Vector2i = (target - grid.cell_at(player.global_position)).abs()
	_check(maxi(reach.x, reach.y) <= 1, "target tile is within reach of the player")
	_press(&"primary_action")
	await _frames(2)
	_check(_state.farm.is_tilled(target), "left click tills the targeted tile")
	await _shot("09_end")

	print("\nSMOKE TEST: %s (%d failed)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(_failures)


func _water(item_user: Node, cells: Array[Vector2i]) -> void:
	_state.select_slot(CAN_SLOT)
	for cell: Vector2i in cells:
		item_user.use_item_at(cell)


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
