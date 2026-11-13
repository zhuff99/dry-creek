extends SceneTree
## Dev tool: builds the placeholder TileSet and the starting farm map.
##
## Run from the project folder, after the placeholder PNGs are imported:
##   godot --headless --path . -s res://tools/gen_farm_map.gd
##
## It refuses to overwrite existing files, because once you start painting the
## map in the editor this script would destroy that work. Pass `-- --force` to
## regenerate from scratch anyway.

const ATLAS_PATH := "res://assets/placeholder/tiles/farm_tiles.png"
const TILESET_PATH := "res://resources/tilesets/farm_tileset.tres"
const MAP_PATH := "res://scenes/world/farm_map.tscn"

const TILE := Vector2i(16, 16)
const MAP_SIZE := Vector2i(48, 32)
const SOURCE_ID := 0

# Atlas coordinates, matching the layout drawn by gen_placeholder_art.gd.
const GROUND: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const BANK := Vector2i(3, 0)
const CLIFF := Vector2i(4, 0)
const WOOD_FLOOR := Vector2i(5, 0)
const CABIN_WALL := Vector2i(6, 0)
const TILLED := Vector2i(0, 1)
const WATERED := Vector2i(1, 1)
const WATER := Vector2i(0, 2)
const WATER_FRAMES := 4
const WATER_FRAME_SECONDS := 0.35
const ROCKS: Array[Vector2i] = [Vector2i(0, 3), Vector2i(1, 3)]
const TREES: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 3)]
const GRASS: Array[Vector2i] = [Vector2i(4, 3), Vector2i(1, 4)]
const WEEDS: Array[Vector2i] = [Vector2i(5, 3), Vector2i(0, 4)]

# Map regions, in cells.
const RIVER_WIDTH := 3
const CABIN := Rect2i(5, 9, 7, 6)
const CABIN_DOOR := Vector2i(8, 14)
## Areas kept free of rocks, trees and brush so the start of the game is not
## blocked: around the cabin, the yard with the shipping crate, the first
## field, and a trail north to the river.
const CLEARINGS: Array[Rect2i] = [
	Rect2i(3, 7, 11, 10),
	Rect2i(12, 14, 4, 4),
	Rect2i(16, 15, 13, 10),
	Rect2i(12, 4, 3, 11),
]


func _init() -> void:
	var force := OS.get_cmdline_user_args().has("--force")
	if not force and (FileAccess.file_exists(TILESET_PATH) or FileAccess.file_exists(MAP_PATH)):
		push_error("Tileset or map already exists. Re-run with `-- --force` to overwrite.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TILESET_PATH.get_base_dir()))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAP_PATH.get_base_dir()))

	var tile_set := _build_tileset()
	if tile_set == null:
		quit(1)
		return
	var err := ResourceSaver.save(tile_set, TILESET_PATH)
	if err != OK:
		push_error("Could not save tileset (error %d)" % err)
		quit(1)
		return
	# Point the in-memory resource at its file so the scene references it
	# instead of embedding a copy.
	tile_set.take_over_path(TILESET_PATH)

	err = _build_map(tile_set)
	if err != OK:
		push_error("Could not save map (error %d)" % err)
		quit(1)
		return
	print("Wrote ", TILESET_PATH, " and ", MAP_PATH)
	quit()


# --- tile set ----------------------------------------------------------------

func _build_tileset() -> TileSet:
	var texture := load(ATLAS_PATH) as Texture2D
	if texture == null:
		push_error("Missing %s. Run gen_placeholder_art.gd and import first." % ATLAS_PATH)
		return null

	var tile_set := TileSet.new()
	tile_set.tile_size = TILE
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)  # "world"
	tile_set.set_physics_layer_collision_mask(0, 0)
	# Custom data read by FarmGrid.
	_add_data_layer(tile_set, 0, "tillable", TYPE_BOOL)
	_add_data_layer(tile_set, 1, "water", TYPE_BOOL)
	# Id of the DebrisData resource (res://resources/debris) an object tile is.
	_add_data_layer(tile_set, 2, "debris", TYPE_STRING)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE
	# The source must belong to the tile set before tiles can use its layers.
	tile_set.add_source(source, SOURCE_ID)

	var half := Vector2(TILE) / 2.0
	var full_tile := _box(-half.x, -half.y, half.x, half.y)

	# Open ground: walkable and tillable.
	for coords: Vector2i in GROUND:
		source.create_tile(coords)
		source.get_tile_data(coords, 0).set_custom_data("tillable", true)
	# Walkable, not tillable.
	for coords: Vector2i in [BANK, WOOD_FLOOR, TILLED, WATERED]:
		source.create_tile(coords)
	# Solid.
	for coords: Vector2i in [CLIFF, CABIN_WALL]:
		source.create_tile(coords)
		_add_collision(source.get_tile_data(coords, 0), full_tile)

	# River: solid, animated, and flagged so the watering can can fill from it.
	source.create_tile(WATER)
	source.set_tile_animation_frames_count(WATER, WATER_FRAMES)
	for frame: int in WATER_FRAMES:
		source.set_tile_animation_frame_duration(WATER, frame, WATER_FRAME_SECONDS)
	var water := source.get_tile_data(WATER, 0)
	water.set_custom_data("water", true)
	_add_collision(water, full_tile)

	# Objects sit on their own y-sorted layer. y_sort_origin is where the
	# object touches the ground, measured down from the cell centre.
	for coords: Vector2i in ROCKS:
		source.create_tile(coords)
		var rock := source.get_tile_data(coords, 0)
		rock.set_custom_data("debris", "rock")
		rock.y_sort_origin = 5
		_add_collision(rock, _box(-6, -2, 6, 7))
	for coords: Vector2i in TREES:
		source.create_tile(coords, Vector2i(1, 2))
		var tree := source.get_tile_data(coords, 0)
		# Lift the 16x32 art so the trunk stands in the cell and the canopy
		# overhangs the cell above.
		tree.texture_origin = Vector2i(0, 8)
		tree.set_custom_data("debris", "tree")
		tree.y_sort_origin = 6
		_add_collision(tree, _box(-3, 1, 3, 8))
	# Grass and weeds can be walked through.
	for coords: Vector2i in GRASS + WEEDS:
		source.create_tile(coords)
		var brush := source.get_tile_data(coords, 0)
		brush.set_custom_data("debris", "grass" if GRASS.has(coords) else "weed")
		brush.y_sort_origin = 6
	return tile_set


func _add_data_layer(tile_set: TileSet, index: int, layer_name: String, type: Variant.Type) -> void:
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(index, layer_name)
	tile_set.set_custom_data_layer_type(index, type)


func _box(left: float, top: float, right: float, bottom: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom),
	])


func _add_collision(data: TileData, polygon: PackedVector2Array) -> void:
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, polygon)


# --- map ---------------------------------------------------------------------

func _build_map(tile_set: TileSet) -> Error:
	# The root and the Objects layer are y-sorted so trees and rocks draw in
	# front of or behind the player correctly. Ground and Soil sit underneath.
	var root := Node2D.new()
	root.name = "FarmMap"
	root.y_sort_enabled = true

	var ground := _add_layer(root, "Ground", tile_set)
	ground.z_index = -1
	# Empty overlay that FarmGrid paints tilled and watered soil onto.
	var soil := _add_layer(root, "Soil", tile_set)
	soil.z_index = -1
	var objects := _add_layer(root, "Objects", tile_set)
	objects.y_sort_enabled = true

	var rng := RandomNumberGenerator.new()
	rng.seed = 1885
	for y: int in MAP_SIZE.y:
		for x: int in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var tile := _ground_tile(cell, rng)
			ground.set_cell(cell, SOURCE_ID, tile)
			if GROUND.has(tile) and not _in_clearing(cell):
				var object_tile := _object_tile(cell, rng)
				if object_tile != Vector2i(-1, -1):
					objects.set_cell(cell, SOURCE_ID, object_tile)

	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, MAP_PATH)
	root.free()
	return err


func _add_layer(root: Node2D, layer_name: String, tile_set: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	root.add_child(layer)
	layer.owner = root
	return layer


## Top water row of the river at column `x`. It wanders a row either way.
func _river_top(x: int) -> int:
	return 2 + roundi(sin(x * 0.35))


func _ground_tile(cell: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	# The river crosses the whole map, including the side rims, so it reads as
	# flowing in from the east and out to the west.
	var river_top := _river_top(cell.x)
	if cell.y >= river_top and cell.y < river_top + RIVER_WIDTH:
		return WATER
	# Cliff rim so the player cannot walk off the map.
	if cell.x == 0 or cell.y == 0 or cell.x == MAP_SIZE.x - 1 or cell.y == MAP_SIZE.y - 1:
		return CLIFF
	if cell.y == river_top - 1 or cell.y == river_top + RIVER_WIDTH:
		return BANK
	if CABIN.has_point(cell):
		var interior := CABIN.grow(-1)
		if interior.has_point(cell) or cell == CABIN_DOOR:
			return WOOD_FLOOR
		return CABIN_WALL
	# Mostly plain dirt with the occasional busier variant.
	var roll := rng.randf()
	if roll < 0.6:
		return GROUND[0]
	return GROUND[1] if roll < 0.85 else GROUND[2]


func _in_clearing(cell: Vector2i) -> bool:
	for area: Rect2i in CLEARINGS:
		if area.has_point(cell):
			return true
	return false


## What grows or sits on an open ground cell, or (-1, -1) for nothing.
func _object_tile(cell: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	# Greener close to the water: more trees and grass, cottonwood style.
	var near_river := cell.y <= _river_top(cell.x) + RIVER_WIDTH + 4
	var tree_chance := 0.11 if near_river else 0.04
	var grass_chance := 0.22 if near_river else 0.11
	var roll := rng.randf()
	if roll < tree_chance:
		return TREES[rng.randi() % TREES.size()]
	roll -= tree_chance
	if roll < 0.04:
		return ROCKS[rng.randi() % ROCKS.size()]
	roll -= 0.04
	if roll < 0.07:
		return WEEDS[rng.randi() % WEEDS.size()]
	roll -= 0.07
	if roll < grass_chance:
		return GRASS[rng.randi() % GRASS.size()]
	return Vector2i(-1, -1)
