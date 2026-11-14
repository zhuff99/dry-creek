extends SceneTree
## Dev tool: plays the game by script, checks the results, and saves
## screenshots.
##
##   godot --path . -s res://tools/smoke_test.gd -- <screenshot_folder>
##
## Add --headless to run the checks with no window and no screenshots. That
## is also the steadier way to run it while the computer is in use: a window
## that loses focus drops held keys, and a hidden one runs slowly.
##
## Exit code is the number of failed checks. The run is silent: it mutes the
## master bus, and checks sounds by counting which cues were played.

const CORN_CELLS: Array[Vector2i] = [Vector2i(17, 17), Vector2i(18, 17), Vector2i(19, 17)]
const BEAN_CELLS: Array[Vector2i] = [Vector2i(17, 19), Vector2i(18, 19), Vector2i(19, 19)]
const HOE_SLOT := 0
const CAN_SLOT := 1
const AXE_SLOT := 2
const PICKAXE_SLOT := 3
const SCYTHE_SLOT := 4
const CORN_SEED_SLOT := 5
const BEAN_SEED_SLOT := 6
const CAN_CAPACITY := 20
## Where the trail from the cabin meets the river.
const BANK_CELL := Vector2i(13, 4)
const RIVER_CELL := Vector2i(13, 3)
## Real seconds before the run gives up.
const WATCHDOG_SECONDS := 90.0
## The tile in front of the cabin door, where a new game begins.
const CABIN_DOOR_CELL := Vector2i(8, 14)
## Every sound cue the playthrough should set off at least once.
const EXPECTED_SOUNDS: Array[StringName] = [
	&"swing", &"till", &"pour", &"refill", &"plant", &"harvest",
	&"chop", &"tree_fall", &"rock_hit", &"rock_break", &"swing_blade", &"cut",
	&"ship", &"payout", &"sleep", &"morning",
	&"select", &"ui_open", &"ui_close", &"ui_pick", &"ui_place", &"error", &"door",
	&"gun_draw", &"gun_holster", &"gunshot", &"gun_empty", &"gun_load", &"bottle_break", &"hurt",
	&"snake_rattle", &"snake_strike", &"snake_die",
]
## Where the test stands to shoot: in the field, four tiles north of the
## bottles on the practice rail.
const FIRING_SPOT := Vector2(360, 310)
## A spot in the yard with the cabin's wall just to the north.
const BY_THE_BARREL := Vector2(168, 250)
## Cells on the three stretches of road, and one where it leaves the map.
const ROAD_CELLS: Array[Vector2i] = [Vector2i(9, 14), Vector2i(13, 8), Vector2i(30, 13), Vector2i(13, 4)]
const ROAD_EXIT := Vector2i(47, 13)
const ROAD_SOURCE := 9

var _out_dir := "user://smoke"
var _failures := 0

# This script compiles before the autoloads exist, so it fetches them by path
# and avoids naming project classes (which would compile them too early).
var _state: Node
var _clock: Node
var _bus: Node
## Types of every world event reported during the run.
var _world_events: Array[StringName] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	AudioServer.set_bus_mute(0, true)
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
	_bus.world_event.connect(func(event: RefCounted) -> void: _world_events.append(event.type))
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
	var audio: Node = root.get_node("Audio")
	var river_sound: AudioStreamPlayer = main.get_node("World/Farm/RiverSound")
	await _shot("01_start")

	# --- Wildlife: the day's snakes start out in the brush, well away from
	# home. They are then removed so they cannot bite during the other checks.
	var wildlife: Node = main.get_node("World/Farm/Wildlife")
	var snakes: Array[Node] = get_nodes_in_group(&"wildlife")
	var nearest_to_home := 999
	var hidden := 0
	for animal: Node2D in snakes:
		var cell: Vector2i = grid.cell_at(animal.global_position)
		var from_home: Vector2i = (cell - CABIN_DOOR_CELL).abs()
		nearest_to_home = mini(nearest_to_home, maxi(from_home.x, from_home.y))
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if grid.is_blocked(cell + side):
				hidden += 1
				break
	_check(snakes.size() == 3, "three rattlesnakes are about on the first morning (%d)" % snakes.size())
	_check(nearest_to_home >= 12, "none within twelve tiles of the cabin door (nearest %d)" % nearest_to_home)
	_check(hidden == snakes.size(), "each one beside brush, a rock or a tree")
	wildlife.clear()
	await _frames(2)

	# --- Text: everything is written in the game's own pixel font, at its
	# drawn size, and it has every character a message might use.
	var day_label: Label = main.get_node("UI/HUD/TopBar/DayLabel")
	var font: Font = day_label.get_theme_font(&"font")
	_check(font.resource_path.ends_with("dry_creek.fnt"), "labels use the game's pixel font (%s)" % font.resource_path)
	_check(day_label.get_theme_font_size(&"font_size") == 11, "at the size it was drawn for")
	var undrawn := ""
	for code: int in range(33, 127):
		if not font.has_char(code) or font.get_char_size(code, 11).x <= 0.0:
			undrawn += char(code)
	_check(undrawn == "", "the font has every letter, number and mark (missing: '%s')" % undrawn)

	# --- The clock: the day starts at six, time passes unless the game is
	# paused, and the world darkens toward night while the lamps come up.
	var time_label: Label = main.get_node("UI/HUD/TopBar/TimeLabel")
	var day_night: CanvasModulate = main.get_node("World/DayNight")
	var lantern: PointLight2D = main.get_node("World/Farm/LanternLight")
	_check(time_label.text == "6:00 AM" and _clock.minutes < 6 * 60 + 10, "the day starts at 6:00 AM (%s)" % time_label.text)
	var minutes_before: float = _clock.minutes
	await create_timer(1.0).timeout
	_check(_clock.minutes > minutes_before + 1.0 and _clock.minutes < minutes_before + 3.0,
			"time passes: about a minute and a half each second (%.1f)" % (_clock.minutes - minutes_before))
	paused = true
	minutes_before = _clock.minutes
	await _frames(10)
	_check(_clock.minutes == minutes_before, "but not while the game is paused")
	paused = false
	_clock.minutes = 13 * 60 + 34.0
	await _frames(2)
	_check(time_label.text == "1:30 PM", "the clock reads in ten-minute steps (%s)" % time_label.text)
	_check(day_night.color.is_equal_approx(Color.WHITE) and not lantern.enabled, "midday is plain daylight, lamps out")
	_clock.minutes = 23 * 60.0
	await _frames(2)
	_check(day_night.color.get_luminance() < 0.5 and day_night.color.b > day_night.color.r,
			"night is dark and blue (%s)" % day_night.color)
	_check(lantern.enabled and lantern.energy > 0.5, "and the lantern by the cabin is lit (%.2f)" % lantern.energy)
	_check(player.get_node("Lantern").enabled, "the player carries a light of their own")
	_clock.minutes = 24 * 60.0
	await _frames(2)
	_check(time_label.text == "12:00 AM" and time_label.modulate != Color.WHITE, "after midnight the clock turns red")
	_check(String(main.get_node("UI/HUD/ToastRow/ToastLabel").text).contains("midnight"), "and the game says it is time for bed")
	_clock.minutes = 6 * 60 + 10.0
	await _frames(2)

	# --- Sound: the farm starts its music, and the river is faint from the cabin.
	_check(audio.current_playlist() == &"farm" and audio.is_music_playing(), "the farm's music is playing")
	_check(river_sound.playing, "the river sound is running")
	await create_timer(1.5).timeout
	var river_db_at_cabin := river_sound.volume_db

	# --- Movement and collision: walk left, then up into the cabin's wall.
	var cabin: Node2D = main.get_node("World/Farm/Entities/Cabin")
	var door_spot := player.global_position
	_check(grid.cell_at(door_spot) == CABIN_DOOR_CELL, "the game starts at the cabin door")
	Input.action_press(&"move_left")
	await _physics_frames(20)
	Input.action_release(&"move_left")
	_check(player.global_position.x < door_spot.x, "player moves left")
	Input.action_press(&"move_up")
	await _physics_frames(120)
	Input.action_release(&"move_up")
	_check(player.global_position.y > cabin.global_position.y,
			"the cabin stops the player (y=%.1f)" % player.global_position.y)
	player.global_position = door_spot
	await _physics_frames(2)

	# --- Tilling rules.
	_check(grid.can_till(CORN_CELLS[0]), "open dirt can be tilled")
	_check(not grid.can_till(Vector2i(8, 12)), "the ground under the cabin cannot be tilled")
	_check(not grid.can_till(CABIN_DOOR_CELL), "nor can the doorstep")
	_check(not grid.can_till(RIVER_CELL), "water cannot be tilled")

	# --- The road: door to river and east off the map, never plantable.
	var ground: TileMapLayer = main.get_node("World/Farm/Map/Ground")
	var on_road := 0
	var tillable_road := 0
	for cell: Vector2i in ROAD_CELLS:
		if ground.get_cell_source_id(cell) == ROAD_SOURCE:
			on_road += 1
		if grid.can_till(cell):
			tillable_road += 1
	_check(on_road == ROAD_CELLS.size(), "a road runs from the cabin door to the river and off to the east")
	_check(tillable_road == 0 and not grid.is_blocked(ROAD_CELLS[2]), "the road is clear and cannot be planted")
	_check(ground.get_cell_source_id(ROAD_EXIT) == ROAD_SOURCE, "it reaches the edge of the map")
	# Everything that is not road, water, the cabin's footing or the map's
	# edge is bare dirt that can be planted once it is cleared.
	var plantable := 0
	var land := 0
	for cell: Vector2i in ground.get_used_cells():
		if cell.x == 0 or cell.y == 0 or cell.x == 47 or cell.y == 31:
			continue
		if grid.is_water(cell) or ground.get_cell_source_id(cell) == ROAD_SOURCE:
			continue
		land += 1
		if grid.is_tillable(cell):
			plantable += 1
	_check(plantable > land - 40, "all but %d of the %d other tiles are plantable ground" % [land - plantable, land])
	var debris := objects.get_used_cells()
	_check(debris.size() > 60, "rocks, trees and brush are scattered around (%d)" % debris.size())
	_check(not grid.can_till(debris[0]), "a tile with something on it cannot be tilled")

	# --- Till, plant, water.
	player.global_position = grid.cell_center(Vector2i(18, 18)) + Vector2(0, 4)
	await _physics_frames(3)
	var all_cells: Array[Vector2i] = []
	all_cells.append_array(CORN_CELLS)
	all_cells.append_array(BEAN_CELLS)
	_check(_state.stamina == 100.0 and _state.stamina_ceiling == 100.0 and _state.max_stamina == 100.0,
			"the day starts with full stamina (100)")
	_state.select_slot(HOE_SLOT)
	var hoe_cost: float = _state.selected_stack().item.stamina_cost
	for cell: Vector2i in all_cells:
		await item_user.use_item_at(cell)
	_check(_state.farm.plots.size() == 6, "six plots tilled")
	_check(hoe_cost > 0.0 and is_equal_approx(_state.stamina_ceiling, 100.0 - 6 * hoe_cost * _state.FATIGUE_SHARE),
			"each swing of the hoe costs stamina and wears the day's limit down a little (limit %.1f)" % _state.stamina_ceiling)
	var limit_after_tilling: float = _state.stamina_ceiling
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
	_check(_state.stamina_ceiling == limit_after_tilling, "planting takes no stamina")
	await _water(item_user, all_cells)

	# --- Stamina: a rest brings it back, but only up to the day's limit.
	# Out of stamina, tools do nothing until some returns.
	var stamina_bar: Control = main.get_node("UI/HUD/TopBar/Vitals/Bars/Stamina")
	var toast: Label = main.get_node("UI/HUD/ToastRow/ToastLabel")
	var limit: float = _state.stamina_ceiling
	_check(limit < limit_after_tilling and _state.stamina < limit, "watering costs a little too (%.1f of %.1f)" % [_state.stamina, limit])
	await create_timer(_state.STAMINA_REST_DELAY + _state.max_stamina / _state.STAMINA_REGEN).timeout
	_check(is_equal_approx(_state.stamina, limit) and limit < _state.max_stamina,
			"a rest refills stamina to the day's limit, not to full (%.1f of %d)" % [_state.stamina, _state.max_stamina])
	var spare_cell := Vector2i(17, 18)
	_state.select_slot(HOE_SLOT)
	_check(grid.can_till(spare_cell), "(there is bare ground beside the player)")
	_state.stamina = hoe_cost - 1.0
	item_user._explain_if_tired(spare_cell)
	await item_user.use_item_at(spare_cell)
	_check(_state.farm.plots.size() == 6 and not player.busy, "too tired, the hoe does nothing")
	_check(toast.text.contains("breath"), "and the game says to catch your breath ('%s')" % toast.text)
	_state.stamina_ceiling = hoe_cost - 1.0
	item_user._explain_if_tired(spare_cell)
	_check(toast.text.contains("sleep"), "worn right down, it says to sleep ('%s')" % toast.text)
	_state.stamina_ceiling = 60.0
	_state.stamina = 25.0
	_state._report_stamina()
	await _frames(2)
	_check(stamina_bar._stamina == _state.stamina and stamina_bar._stamina < 60.0 and stamina_bar._ceiling == 60.0, "the stamina bar shows what is left and the day's limit")
	await _shot("02b_stamina_bar")
	_state.stamina_ceiling = limit
	_state.stamina = limit
	_state._report_stamina()
	_state.select_slot(CAN_SLOT)
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
	# Click a stack, then an empty slot, the way the panel's buttons report it.
	var slots: Node = panel.get_node("Margin/VBox/Grid")
	slots.get_child(CORN_SEED_SLOT).pressed.emit()
	slots.get_child(20).pressed.emit()
	_check(_state.inventory.get_slot(20) != null and _state.inventory.get_slot(CORN_SEED_SLOT) == null,
			"stacks can be moved between slots")
	slots.get_child(20).pressed.emit()
	slots.get_child(CORN_SEED_SLOT).pressed.emit()
	_check(_state.inventory.get_slot(CORN_SEED_SLOT) != null, "and moved back")
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
	await create_timer(1.5).timeout
	_check(river_sound.volume_db > river_db_at_cabin + 6.0,
			"the river is louder at the bank (%.0f dB) than at the cabin (%.0f dB)" % [river_sound.volume_db, river_db_at_cabin])
	item_user.use_item_at(RIVER_CELL)
	await create_timer(0.25).timeout
	await _shot("16_filling_can")
	await _until_idle(player)
	_check(_state.inventory.get_slot(CAN_SLOT).charge == CAN_CAPACITY, "the can fills at the river")
	await item_user.use_item_at(RIVER_CELL)
	_check(not player.busy, "a full can does not refill again")
	Engine.time_scale = 3.0

	# --- Clearing: each kind of debris needs its own tool and number of hits.
	var item_db: Node = root.get_node("ItemDB")
	var targets := {}
	for cell: Vector2i in objects.get_used_cells():
		# Border trees are scenery, not debris, and the rows near the top are
		# the far bank of the river, which is out of reach.
		var found: Variant = grid.debris_at(cell)
		if found != null and cell.y > 8 and not targets.has(found.id):
			targets[found.id] = cell
	_check(targets.size() == 4, "the map has trees, rocks, weeds and grass")
	var tree: Vector2i = targets[&"tree"]
	var rock: Vector2i = targets[&"rock"]
	var weed: Vector2i = targets[&"weed"]
	var grass: Vector2i = targets[&"grass"]

	player.global_position = grid.cell_center(tree + Vector2i.DOWN) + Vector2(0, 4)
	await _physics_frames(2)
	_state.select_slot(PICKAXE_SLOT)
	await item_user.use_item_at(tree)
	_check(grid.is_blocked(tree) and _state.farm.debris_damage.is_empty(), "a pickaxe does nothing to a tree")
	_state.select_slot(AXE_SLOT)
	await item_user.use_item_at(tree)
	await item_user.use_item_at(tree)
	_check(grid.is_blocked(tree), "a tree is still standing after two axe hits")
	Engine.time_scale = 1.0
	item_user.use_item_at(tree)
	await create_timer(0.2).timeout
	await _shot("17_axe_swing")
	await _until_idle(player)
	Engine.time_scale = 3.0
	_check(not grid.is_blocked(tree), "the third hit fells the tree")
	_check(_find_slot(item_db.get_item(&"wood")) != -1, "the tree drops wood")
	_check(grid.can_till(tree), "cleared ground can be tilled")
	_check(_state.farm.cleared_debris.has(tree), "the cleared tile is remembered")

	player.global_position = grid.cell_center(rock + Vector2i.DOWN) + Vector2(0, 4)
	await _physics_frames(2)
	_state.select_slot(AXE_SLOT)
	await item_user.use_item_at(rock)
	_check(grid.is_blocked(rock) and _state.farm.debris_damage.is_empty(), "an axe does nothing to a rock")
	_state.select_slot(PICKAXE_SLOT)
	await item_user.use_item_at(rock)
	_check(grid.is_blocked(rock), "a rock survives one pickaxe hit")
	await item_user.use_item_at(rock)
	_check(not grid.is_blocked(rock), "the second hit breaks the rock")
	_check(_find_slot(item_db.get_item(&"stone")) != -1, "the rock drops stone")

	_state.select_slot(SCYTHE_SLOT)
	player.global_position = grid.cell_center(weed + Vector2i.DOWN) + Vector2(0, 4)
	await _physics_frames(2)
	await item_user.use_item_at(weed)
	_check(not grid.is_blocked(weed), "the scythe cuts a weed in one hit")
	_check(_find_slot(item_db.get_item(&"fiber")) != -1, "the weed drops fiber")
	player.global_position = grid.cell_center(grass + Vector2i.DOWN) + Vector2(0, 4)
	await _physics_frames(2)
	await item_user.use_item_at(grass)
	_check(not grid.is_blocked(grass), "the scythe cuts grass in one hit")
	await _shot("18_after_clearing")

	# --- Sound: a click that does nothing says so, and every cue was heard.
	_state.select_slot(HOE_SLOT)
	for cell: Vector2i in objects.get_used_cells():
		if grid.debris_at(cell) != null:
			# What a click on it would run first: "use the axe" and a buzz.
			item_user.call(&"_explain_if_useless", cell)
			break
	# --- The revolver: draw, steady the aim, shoot a bottle, run dry, reload.
	var weapon: Node = player.get_node("Weapon")
	var gun: Resource = _state.weapon
	var rounds: Resource = item_db.get_item(&"revolver_rounds")
	var spare: int = _state.inventory.count_of(rounds)
	var limit_before_shooting: float = _state.stamina_ceiling
	_check(gun != null and _state.rounds_loaded == 6 and spare == 24, "the game starts with a loaded revolver and 24 spare rounds")
	var bottle: Node2D = main.get_node("World/Farm/Entities/Bottle2")
	player.global_position = FIRING_SPOT
	await _physics_frames(3)
	_state.select_slot(HOE_SLOT)
	_press(&"toggle_weapon")
	await _frames(2)
	_release(&"toggle_weapon")
	_check(weapon.drawn and player.armed, "the holster key draws the revolver")
	_check(_world_events.has(&"weapon_drawn"), "drawing it is reported as a world event")
	var plots_with_gun: int = _state.farm.plots.size()
	_press(&"primary_action")
	await _frames(3)
	_release(&"primary_action")
	await _frames(3)
	_check(_state.rounds_loaded == 6 and _state.farm.plots.size() == plots_with_gun and not player.busy,
			"a click with the gun lowered neither fires nor swings the hoe")

	weapon.aim_override = bottle.get_node("Hurtbox").global_position
	_press(&"aim")
	await _frames(2)
	var first_spread: float = weapon.spread
	_check(weapon.aiming and first_spread > gun.steady_spread * 4.0, "raising the gun starts with a wide cone (%.1f degrees)" % first_spread)
	Engine.time_scale = 1.0
	await create_timer(0.3).timeout
	await _shot("19_aiming")
	Engine.time_scale = 3.0
	await create_timer(0.8).timeout
	_check(is_equal_approx(weapon.spread, gun.steady_spread), "holding still steadies it (%.1f degrees)" % weapon.spread)
	var held: Sprite2D = weapon.get_node("Gun")
	_check(player.get_node("AimSprite").visible and not player.get_node("Sprite2D").visible,
			"aiming puts the body in its arm-out stance")
	_check(held.visible and held.global_position.distance_to(player.global_position + weapon.AIM_FISTS[Vector2.DOWN]) < 0.6,
			"with the gun in its fist")
	_check(player.facing == Vector2.DOWN, "the player faces where they aim")
	# Aim far off for this one, so a few steps sideways do not change the
	# direction to the target.
	var bottle_at: Vector2 = weapon.aim_override
	weapon.aim_override = FIRING_SPOT + Vector2(0, 400)
	Input.action_press(&"move_left")
	await _physics_frames(20)
	_check(weapon.spread > gun.steady_spread and player.facing == Vector2.DOWN,
			"walking widens the cone and does not turn the player (%.1f degrees, facing %s)" % [weapon.spread, player.facing])
	_check(absf(player.velocity.x) < 60.0, "and is slower than a normal walk (%.0f px/s)" % absf(player.velocity.x))
	Input.action_release(&"move_left")
	player.global_position = FIRING_SPOT
	weapon.aim_override = bottle_at
	await create_timer(0.8).timeout

	_press(&"primary_action")
	await _frames(2)
	_release(&"primary_action")
	await _frames(2)
	_check(bottle.broken, "a steady shot breaks the bottle")
	_check(_state.rounds_loaded == 5, "firing uses a round")
	_check(weapon.spread > gun.steady_spread, "recoil widens the cone again")
	_check(_world_events.has(&"gunshot"), "the shot is reported as a world event")

	# From the yard, the cabin is in the way of a shot north.
	player.global_position = BY_THE_BARREL
	await _physics_frames(3)
	weapon.aim_override = BY_THE_BARREL + Vector2(0, -60)
	await create_timer(0.8).timeout
	_press(&"primary_action")
	await _frames(2)
	_release(&"primary_action")
	_check(weapon.last_hit_point.y > BY_THE_BARREL.y - 30.0 and weapon.last_hit_point.y < BY_THE_BARREL.y,
			"something solid stops a bullet (%.0f px away)" % (BY_THE_BARREL.y - 7.0 - weapon.last_hit_point.y))
	for i: int in 4:
		await create_timer(0.6).timeout
		_press(&"primary_action")
		await _frames(2)
		_release(&"primary_action")
	_check(_state.rounds_loaded == 0, "six shots empty the cylinder")
	_check(_state.stamina_ceiling == limit_before_shooting, "shooting takes no stamina")
	await create_timer(0.6).timeout
	_press(&"primary_action")
	await _frames(2)
	_release(&"primary_action")
	_check(_state.rounds_loaded == 0 and audio.play_counts.get(&"gun_empty", 0) == 1, "an empty gun only clicks")
	_release(&"aim")
	await _frames(2)

	_press(&"reload")
	await create_timer(1.0).timeout
	_release(&"reload")
	await _frames(2)
	_check(_state.rounds_loaded == 2 and _state.inventory.count_of(rounds) == spare - 2,
			"holding reload loads one round at a time (%d in after a second)" % _state.rounds_loaded)
	_press(&"reload")
	await create_timer(2.5).timeout
	_release(&"reload")
	_check(_state.rounds_loaded == 6 and _state.inventory.count_of(rounds) == spare - 6, "and stops when the cylinder is full")
	# Pictures of the stance each way, and of the recoil, at real speed.
	Engine.time_scale = 1.0
	player.global_position = FIRING_SPOT
	await _physics_frames(3)
	for way: Array in [["left", Vector2.LEFT], ["right", Vector2.RIGHT], ["up", Vector2.UP], ["down", Vector2(0.4, 1.0)]]:
		weapon.aim_override = FIRING_SPOT + way[1] * 90.0
		_press(&"aim")
		await create_timer(0.75).timeout
		await _shot("20_aim_%s" % way[0])
		if way[0] == "right":
			_press(&"primary_action")
			await _frames(2)
			_release(&"primary_action")
			await _shot("20_recoil")
		_release(&"aim")
		await _frames(3)
	_check(not player.get_node("AimSprite").visible and held.visible, "lowering the gun returns to the normal stance, gun at the side")
	await _shot("20_lowered")
	# Walking with the gun out: it rides in the hand, which swings.
	var hand_spots := {}
	Input.action_press(&"move_right")
	for i: int in 40:
		await physics_frame
		hand_spots[(held.global_position - player.global_position).round()] = true
		if i == 12:
			await _shot("20_walking_armed")
	Input.action_release(&"move_right")
	_check(hand_spots.size() >= 2, "walking with the gun out, it follows the swinging hand (%d positions)" % hand_spots.size())
	player.global_position = FIRING_SPOT
	await _physics_frames(3)
	_press(&"reload")
	await create_timer(0.3).timeout
	await _shot("20_loading")
	await create_timer(0.3).timeout
	_release(&"reload")
	Engine.time_scale = 3.0

	# The tuning panel changes the gun's numbers while the game runs.
	var tuner: Control = main.get_node("UI/WeaponTuner")
	_press(&"toggle_tuning")
	await _frames(3)
	_release(&"toggle_tuning")
	_check(tuner.visible and not paused, "the tuning key opens the panel without pausing")
	var steady_before: float = gun.steady_spread
	tuner.slider_for(&"steady_spread").value = 5.0
	_check(is_equal_approx(gun.steady_spread, 5.0), "moving a slider changes the gun at once")
	weapon.aim_override = FIRING_SPOT + Vector2(0, 400)
	_press(&"aim")
	await create_timer(1.2).timeout
	_check(is_equal_approx(weapon.spread, 5.0), "and the cone settles at the new width (%.1f degrees)" % weapon.spread)
	await _shot("21_tuning_panel")
	_release(&"aim")
	tuner.call(&"_reset")
	_check(is_equal_approx(gun.steady_spread, steady_before), "Reset puts the numbers back")
	_press(&"toggle_tuning")
	await _frames(3)
	_release(&"toggle_tuning")
	_check(not tuner.visible, "the tuning key closes it again")

	weapon.aim_override = null
	_press(&"toggle_weapon")
	await _frames(2)
	_release(&"toggle_weapon")
	_check(not weapon.drawn and not player.armed, "the holster key puts it away")
	await create_timer(0.6).timeout
	_check(not held.visible, "and the gun is out of sight once it is holstered")

	# --- The way out: the road is closed at the map's edge, and a sign says why.
	player.global_position = grid.cell_center(ROAD_EXIT + Vector2i.LEFT) + Vector2(0, 4)
	await _physics_frames(3)
	Input.action_press(&"move_right")
	await _physics_frames(90)
	Input.action_release(&"move_right")
	_check(grid.cell_at(player.global_position) == ROAD_EXIT + Vector2i.LEFT, "the road is closed where it leaves the map")
	var sign_post: Node2D = main.get_node("World/Farm/TownSign")
	player.global_position = sign_post.global_position + Vector2(0, 16)
	await _physics_frames(4)
	await _frames(3)
	_press(&"interact")
	await _frames(3)
	_release(&"interact")
	_check(String(main.get_node("UI/HUD/ToastRow/ToastLabel").text).contains("town"), "the sign beside it points to town")
	Engine.time_scale = 1.0
	await _shot("20b_road_east_end")
	Engine.time_scale = 3.0

	# --- A rattlesnake: it warns, settles if you back off, strikes if you
	# come close, and one shot kills it.
	# The day's own snakes wander; one straying over would muddle the checks.
	wildlife.clear()
	await _frames(2)
	var snake: Node2D = wildlife.spawn_at(FIRING_SPOT + Vector2(120, 0))
	var snake_data: Resource = snake.data
	player.global_position = FIRING_SPOT
	await create_timer(0.5).timeout
	_check(snake.state == snake.State.IDLE, "a snake left alone minds its own business")
	player.global_position = snake.global_position + Vector2(-40, 0)
	await create_timer(0.4).timeout
	_check(snake.state == snake.State.WARN and snake.get_node("Alert").visible, "come near and it rattles")
	_check(snake.facing == Vector2.LEFT, "facing you")
	Engine.time_scale = 1.0
	await _shot("21_snake_warning")
	Engine.time_scale = 3.0
	await create_timer(2.0).timeout
	_check(snake.state == snake.State.WARN and _state.health == _state.max_health, "keep your distance and it only warns")
	player.global_position = snake.global_position + Vector2(-110, 0)
	await create_timer(0.4).timeout
	_check(snake.state == snake.State.IDLE, "back off and it settles")
	player.global_position = snake.global_position + Vector2(-16, 0)
	await create_timer(snake_data.warn_seconds + 0.6).timeout
	_check(_state.health == _state.max_health - snake_data.damage, "step in close and it bites (%d health left)" % _state.health)
	_check(snake.state == snake.State.RECOVER or snake.state == snake.State.WARN, "then has to gather itself")

	# Shoot it from outside its notice, following it with the gun as a
	# player's mouse would.
	player.global_position = snake.global_position + Vector2(-70, 0)
	await _physics_frames(3)
	_press(&"toggle_weapon")
	await _frames(2)
	_release(&"toggle_weapon")
	_press(&"aim")
	var aim_until := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < aim_until:
		weapon.aim_override = snake.get_node("Hurtbox").global_position
		await process_frame
	var meat: Resource = item_db.get_item(&"snake_meat")
	_press(&"primary_action")
	await _frames(2)
	_release(&"primary_action")
	_release(&"aim")
	await _frames(2)
	_check(snake.state == snake.State.DEAD, "one shot kills it")
	_check(_state.inventory.count_of(meat) == 1, "and it leaves snake meat")
	_check(_world_events.has(&"creature_killed"), "the kill is reported as a world event")
	weapon.aim_override = null
	_press(&"toggle_weapon")
	await _frames(2)
	_release(&"toggle_weapon")
	await create_timer(1.0).timeout
	_check(not is_instance_valid(snake), "the body fades away")
	# Mend the bite so the health checks below start from full.
	_state.heal(_state.max_health)

	# --- Health: a hit takes some, a second hit straight after does not.
	var health_bar: ProgressBar = main.get_node("UI/HUD/TopBar/Vitals/Bars/Health")
	_check(_state.health == 10 and _state.max_health == 10 and health_bar.value == 10.0, "the player starts at full health (10)")
	player.take_damage(3)
	player.take_damage(3)
	await _frames(2)
	_check(_state.health == 7, "a hit takes health, and a second hit in the same moment is shrugged off (%d left)" % _state.health)
	_check(health_bar.value == 7.0, "the health bar shows it")
	await _shot("21_hurt")

	# --- The cabin: in by the door, sleep in the bed, back out. The farm is
	# freed while inside and rebuilt from GameState on the way out.
	var world: Node = main.get_node("World")
	var plots_before: int = _state.farm.plots.size()
	var day_before: int = _clock.day
	player.global_position = door_spot
	await _physics_frames(3)
	await _use_door()
	_check(world.area.name == "CabinInterior", "the cabin door leads inside")
	player = world.area.get_node("Entities/Player")
	var inside_door: Node2D = world.area.get_node("Spawns/door")
	_check(player.global_position.distance_to(inside_door.global_position) < 1.0, "the player arrives just inside the door")
	await _frames(20)
	await _shot("22_cabin_inside")
	var bed: Node2D = world.area.get_node("Entities/Bed")
	player.global_position = bed.global_position + Vector2(24, -8)
	await _physics_frames(3)
	_press(&"interact")
	await _frames(3)
	_release(&"interact")
	while paused:
		await process_frame
	_check(_clock.day == day_before + 1, "sleeping in the bed starts the next day")
	_check(_state.health == _state.max_health, "a night's sleep restores health")
	_check(_clock.shown_minutes() == 6 * 60, "and the clock is back at six in the morning")
	_clock.minutes = 23 * 60.0
	await _frames(2)
	_check(day_night.color.get_luminance() > 0.7, "indoors the fire keeps the night bright (%.2f)" % day_night.color.get_luminance())
	_clock.minutes = 12 * 60.0
	await _frames(2)
	_check(world.area.get_node("FireLight").enabled, "the fire glows by day too")
	_clock.minutes = 6 * 60.0
	_check(_state.stamina == _state.max_stamina and _state.stamina_ceiling == _state.max_stamina, "and stamina, limit and all")
	_check(world.area.name == "CabinInterior", "and you wake up inside")
	await _shot("23_by_the_bed")
	Input.action_press(&"move_up")
	await _physics_frames(90)
	Input.action_release(&"move_up")
	_check(player.global_position.y > 42.0, "the far wall stops the player (y=%.1f)" % player.global_position.y)
	player.global_position = inside_door.global_position
	await _physics_frames(3)
	await _use_door()
	_check(world.area.name == "Farm", "the door leads back out to the farm")
	player = world.area.get_node("Entities/Player")
	_check(world.area.get_node("FarmGrid").cell_at(player.global_position) == CABIN_DOOR_CELL, "onto the cabin's doorstep")
	var soil: TileMapLayer = world.area.get_node("Map/Soil")
	_check(plots_before > 0 and soil.get_used_cells().size() == plots_before,
			"the tilled plots are drawn again (%d)" % soil.get_used_cells().size())
	var objects_again: TileMapLayer = world.area.get_node("Map/Objects")
	_check(objects_again.get_cell_source_id(tree) == -1, "the felled tree is still gone")
	_check(get_nodes_in_group(&"wildlife").size() == 3, "it is a new day, so three snakes are about again")
	var crops := 0
	var crops_shown := 0
	for child: Node in world.area.get_node("Entities").get_children():
		if child.has_method(&"set_growth"):
			crops += 1
			if child.get_node("Sprite2D").texture != null:
				crops_shown += 1
	_check(crops > 0 and crops_shown == crops, "the growing crops are drawn again (%d of %d)" % [crops_shown, crops])
	await _frames(20)
	await _shot("24_back_outside")

	# --- Passing out: health runs out on the farm, you wake at home, poorer.
	var day_at_collapse: int = _clock.day
	var money_at_collapse: int = _state.money
	player.take_damage(99)
	await _frames(3)
	while paused:
		await process_frame
	await _frames(3)
	_check(_clock.day == day_at_collapse + 1, "running out of health ends the day")
	_check(world.area.name == "CabinInterior", "you wake up inside the cabin")
	player = world.area.get_node("Entities/Player")
	_check(player.global_position.distance_to(world.area.get_node("Spawns/bed").global_position) < 1.0, "beside the bed")
	_check(_state.health == _state.max_health, "at full health")
	_check(money_at_collapse >= 10 and _state.money == money_at_collapse - int(money_at_collapse * 0.1),
			"and a tenth of your money is gone ($%d to $%d)" % [money_at_collapse, _state.money])
	await _shot("25_woke_at_home")

	# --- Staying up: at two in the morning the day ends whether you like it
	# or not.
	var day_before_late: int = _clock.day
	var money_before_late: int = _state.money
	_clock.minutes = 26 * 60 - 0.5
	for i: int in 120:
		if paused:
			break
		await process_frame
	_check(paused, "at 2:00 AM the day ends by itself")
	while paused:
		await process_frame
	await _frames(3)
	_check(String(main.get_node("UI/DayTransition/Label").text).contains("too late"),
			"the night screen says you stayed up too late")
	_check(_clock.day == day_before_late + 1 and _clock.shown_minutes() == 6 * 60, "you wake the next morning at six")
	_check(world.area.name == "CabinInterior", "at home")
	_check(_state.money == money_before_late - int(money_before_late * 0.1),
			"and it cost a tenth of your money ($%d to $%d)" % [money_before_late, _state.money])

	for cue: StringName in EXPECTED_SOUNDS:
		_check(audio.play_counts.get(cue, 0) > 0, "sound '%s' played (%d times)" % [cue, audio.play_counts.get(cue, 0)])
	for cue: StringName in audio.cue_ids():
		if not EXPECTED_SOUNDS.has(cue):
			_check(false, "sound '%s' exists but the playthrough never checks it" % cue)

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


## Presses interact at a door and waits for the other side to be shown.
func _use_door() -> void:
	_press(&"interact")
	await _frames(3)
	_release(&"interact")
	while paused:
		await process_frame
	await _frames(3)


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
	# Run with --headless there is nothing drawn to save; the checks still run.
	if DisplayServer.get_name() == "headless":
		await process_frame
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out_dir.path_join(name + ".png"))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
