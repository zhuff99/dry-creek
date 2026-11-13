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
const MAP_SIZE := Vector2i(48, 30)
const SOURCE_ID := 0

# Atlas coordinates, matching the layout drawn by gen_placeholder_art.gd.
const SAND: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const DIRT := Vector2i(3, 0)
const ROCK := Vector2i(4, 0)
const WOOD_FLOOR := Vector2i(5, 0)
const CABIN_WALL := Vector2i(6, 0)
const TILLED := Vector2i(0, 1)
const WATERED := Vector2i(1, 1)

# Map regions, in cells.
const CABIN := Rect2i(5, 2, 7, 6)
const CABIN_DOOR := Vector2i(8, 7)
const FIELD := Rect2i(16, 9, 14, 10)
const OUTCROPS: Array[Vector2i] = [
	Vector2i(35, 6), Vector2i(36, 6), Vector2i(36, 7),
	Vector2i(40, 20), Vector2i(41, 20),
	Vector2i(22, 24), Vector2i(23, 24), Vector2i(23, 25),
	Vector2i(9, 21), Vector2i(4, 14),
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
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "tillable")
	tile_set.set_custom_data_layer_type(0, TYPE_BOOL)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE
	# The source must belong to the tile set before tiles can use its layers.
	tile_set.add_source(source, SOURCE_ID)

	var walkable: Array[Vector2i] = [DIRT, WOOD_FLOOR, TILLED, WATERED]
	walkable.append_array(SAND)
	for coords: Vector2i in walkable:
		source.create_tile(coords)
	source.get_tile_data(DIRT, 0).set_custom_data("tillable", true)

	var half := Vector2(TILE) / 2.0
	var full_tile := PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	for coords: Vector2i in [ROCK, CABIN_WALL]:
		source.create_tile(coords)
		var data := source.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, full_tile)
	return tile_set


func _build_map(tile_set: TileSet) -> Error:
	var root := Node2D.new()
	root.name = "FarmMap"

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tile_set
	root.add_child(ground)
	ground.owner = root

	# Empty overlay that FarmGrid paints tilled and watered soil onto.
	var soil := TileMapLayer.new()
	soil.name = "Soil"
	soil.tile_set = tile_set
	root.add_child(soil)
	soil.owner = root

	var rng := RandomNumberGenerator.new()
	rng.seed = 1885
	for y: int in MAP_SIZE.y:
		for x: int in MAP_SIZE.x:
			ground.set_cell(Vector2i(x, y), SOURCE_ID, _tile_for(Vector2i(x, y), rng))

	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, MAP_PATH)
	root.free()
	return err


func _tile_for(cell: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	# Rock rim so the player cannot walk off the map.
	if cell.x == 0 or cell.y == 0 or cell.x == MAP_SIZE.x - 1 or cell.y == MAP_SIZE.y - 1:
		return ROCK
	if CABIN.has_point(cell):
		var interior := CABIN.grow(-1)
		if interior.has_point(cell) or cell == CABIN_DOOR:
			return WOOD_FLOOR
		return CABIN_WALL
	if FIELD.has_point(cell):
		return DIRT
	if OUTCROPS.has(cell):
		return ROCK
	# Mostly plain sand with the occasional busier variant.
	var roll := rng.randf()
	if roll < 0.7:
		return SAND[0]
	return SAND[1] if roll < 0.9 else SAND[2]
