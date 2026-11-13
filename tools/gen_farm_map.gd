extends SceneTree
## Dev tool: builds the farm TileSet and the starting farm map from the Ninja
## Adventure pack (plus the two recoloured images in assets/derived).
##
## Run from the project folder, after the images are imported:
##   godot --headless --path . -s res://tools/gen_farm_map.gd
##
## It refuses to overwrite existing files, because once you start painting the
## map in the editor this script would destroy that work. Pass `-- --force` to
## regenerate from scratch anyway.

const Tiles := preload("res://scripts/world/farm_tiles.gd")
const Blob := preload("res://scripts/world/blob_tiles.gd")

const PACK := "res://assets/ninja_adventure/tilesets/"
const TILESET_PATH := "res://resources/tilesets/farm_tileset.tres"
const MAP_PATH := "res://scenes/world/farm_map.tscn"

const TILE := Vector2i(16, 16)
const MAP_SIZE := Vector2i(48, 32)
const NONE := Vector2i(-1, -1)
## Alternative tile id used for the copies that behave differently: solid
## ground under the border, and border trees that cannot be chopped.
const ALT := 1

# --- atlas coordinates -------------------------------------------------------
const PLANK_FLOOR := Vector2i(1, 13)
# Cabin walls: a 5x5 ring, corners and one edge piece per side.
const WALL_TL := Vector2i(0, 0)
const WALL_T := Vector2i(1, 0)
const WALL_TR := Vector2i(4, 0)
const WALL_L := Vector2i(0, 1)
const WALL_R := Vector2i(4, 1)
const WALL_BL := Vector2i(0, 4)
const WALL_B := Vector2i(1, 4)
const WALL_BR := Vector2i(4, 4)
# TilesetNature.png. Trees are bigger than one cell.
const TREES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(6, 0), Vector2i(16, 0)]
const DEAD_TREE := Vector2i(4, 0)
const TREE_CELLS := Vector2i(2, 2)
const BIG_TREES: Array[Vector2i] = [Vector2i(3, 18), Vector2i(9, 18)]
const BIG_TREE_CELLS := Vector2i(3, 3)
const ROCKS: Array[Vector2i] = [
	Vector2i(17, 13), Vector2i(18, 13), Vector2i(19, 13),
	Vector2i(17, 17), Vector2i(18, 17), Vector2i(19, 17),
]
const GRASS: Array[Vector2i] = [Vector2i(3, 10), Vector2i(4, 10), Vector2i(5, 10), Vector2i(7, 10)]
const FLOWERS: Array[Vector2i] = [Vector2i(0, 11), Vector2i(1, 11), Vector2i(3, 11), Vector2i(6, 11)]
const WEEDS: Array[Vector2i] = [
	Vector2i(8, 10), Vector2i(9, 10), Vector2i(4, 11), Vector2i(5, 11), Vector2i(0, 10), Vector2i(2, 10),
]
const DRY_BRUSH: Array[Vector2i] = [Vector2i(12, 11), Vector2i(13, 11), Vector2i(12, 12), Vector2i(13, 12)]
# TilesetFloorDetail.png: things lying on the ground that block nothing.
const DETAILS: Array[Vector2i] = [
	Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
	Vector2i(1, 0), Vector2i(3, 2), Vector2i(0, 2), Vector2i(15, 0),
]
const BONES: Array[Vector2i] = [Vector2i(13, 0), Vector2i(14, 0)]
const RIPPLE := Vector2i(0, 0)
const RIPPLE_FRAMES := 4

# --- map regions, in cells ---------------------------------------------------
const RIVER_WIDTH := 3
const CABIN := Rect2i(5, 9, 7, 6)
const CABIN_DOOR := Vector2i(8, 14)
## Areas kept free of rocks, trees and brush so the start of the game is not
## blocked: around the cabin, the yard with the shipping crate, the first
## field, and a trail north to the river.
const CLEARINGS: Array[Rect2i] = [
	Rect2i(3, 6, 11, 11),
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

	var floor_source := _add_source(tile_set, Tiles.SRC_FLOOR, PACK + "TilesetFloor.png")
	var water := _add_source(tile_set, Tiles.SRC_WATER, "res://assets/derived/water_on_dirt.png")
	var soil := _add_source(tile_set, Tiles.SRC_SOIL, "res://assets/derived/soil_dry.png")
	var wet := _add_source(tile_set, Tiles.SRC_WET_SOIL, "res://assets/derived/soil_wet.png")
	var nature := _add_source(tile_set, Tiles.SRC_NATURE, PACK + "TilesetNature.png")
	var wall := _add_source(tile_set, Tiles.SRC_WALL, "res://assets/derived/cabin_walls.png")
	var plank := _add_source(tile_set, Tiles.SRC_PLANK, PACK + "TilesetWater.png")
	var detail := _add_source(tile_set, Tiles.SRC_DETAIL, PACK + "TilesetFloorDetail.png")
	var ripple := _add_source(tile_set, Tiles.SRC_RIPPLE, PACK + "WaterRipples.png")
	for source: TileSetAtlasSource in [floor_source, water, soil, wet, nature, wall, plank, detail, ripple]:
		if source == null:
			return null

	var full_tile := _box(-8, -8, 8, 8)

	# Bare dirt: walkable and tillable. The first one also gets a solid twin
	# that goes under the border trees.
	for coords: Vector2i in Tiles.GROUND:
		floor_source.create_tile(coords)
		floor_source.get_tile_data(coords, 0).set_custom_data("tillable", true)
	floor_source.create_alternative_tile(Tiles.GROUND[0], ALT)
	_add_collision(floor_source.get_tile_data(Tiles.GROUND[0], ALT), full_tile)

	# Tilled soil, watered soil and the river: one tile per blob piece.
	for row: int in Blob.LAYOUT.size():
		for col: int in Blob.LAYOUT[row].size():
			var mask: int = Blob.LAYOUT[row][col]
			if mask < 0:
				continue
			var piece := Vector2i(col, row)
			soil.create_tile(piece)
			wet.create_tile(piece)
			water.create_tile(piece)
			var water_data := water.get_tile_data(piece, 0)
			water_data.set_custom_data("water", true)
			_add_collision(water_data, _water_shape(mask))

	# Cabin.
	plank.create_tile(PLANK_FLOOR)
	for coords: Vector2i in [WALL_TL, WALL_T, WALL_TR, WALL_L, WALL_R, WALL_BL, WALL_B, WALL_BR]:
		wall.create_tile(coords)
		_add_collision(wall.get_tile_data(coords, 0), full_tile)

	# Ground litter and the animated ripple: decoration only.
	for coords: Vector2i in DETAILS + BONES:
		detail.create_tile(coords)
	ripple.create_tile(RIPPLE)
	ripple.set_tile_animation_frames_count(RIPPLE, RIPPLE_FRAMES)
	for frame: int in RIPPLE_FRAMES:
		ripple.set_tile_animation_frame_duration(RIPPLE, frame, 0.3)

	# Objects sit on their own y-sorted layer. y_sort_origin is where the
	# object touches the ground, measured down from the cell centre.
	for coords: Vector2i in ROCKS:
		_add_object(nature, coords, Vector2i.ONE, "rock", _box(-6, -3, 6, 6))
	for coords: Vector2i in GRASS + FLOWERS:
		_add_object(nature, coords, Vector2i.ONE, "grass")
	for coords: Vector2i in WEEDS + DRY_BRUSH:
		_add_object(nature, coords, Vector2i.ONE, "weed")
	for coords: Vector2i in TREES + [DEAD_TREE]:
		_add_object(nature, coords, TREE_CELLS, "tree", _box(-4, 0, 4, 7))
		# Border copy: same art, cannot be chopped, and the ground under it
		# is what blocks the way.
		nature.create_alternative_tile(coords, ALT)
		_place_tall(nature.get_tile_data(coords, ALT), TREE_CELLS)
	for coords: Vector2i in BIG_TREES:
		_add_object(nature, coords, BIG_TREE_CELLS, "tree", _box(-5, 0, 5, 7))
	return tile_set


func _add_source(tile_set: TileSet, id: int, texture_path: String) -> TileSetAtlasSource:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_error("Missing %s. Import the project (and run build_derived_art.gd) first." % texture_path)
		return null
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE
	# The source must belong to the tile set before tiles can use its layers.
	tile_set.add_source(source, id)
	return source


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


## A water tile blocks the player, but its bank is dry land: pull the edge of
## the collision in on every side that borders ground.
func _water_shape(mask: int) -> PackedVector2Array:
	const BANK := 5.0
	return _box(
		-8.0 + (0.0 if mask & Blob.W else BANK),
		-8.0 + (0.0 if mask & Blob.N else BANK),
		8.0 - (0.0 if mask & Blob.E else BANK),
		8.0 - (0.0 if mask & Blob.S else BANK),
	)


func _add_object(
	source: TileSetAtlasSource,
	coords: Vector2i,
	cells: Vector2i,
	debris: String,
	collision: PackedVector2Array = PackedVector2Array(),
) -> void:
	source.create_tile(coords, cells)
	var data := source.get_tile_data(coords, 0)
	data.set_custom_data("debris", debris)
	_place_tall(data, cells)
	if not collision.is_empty():
		_add_collision(data, collision)


## Stands art taller than one cell on its cell: the bottom of the picture sits
## on the bottom of the cell and the rest rises above it.
func _place_tall(data: TileData, cells: Vector2i) -> void:
	data.texture_origin = Vector2i(0, (cells.y - 1) * TILE.y / 2)
	data.y_sort_origin = 6


# --- map ---------------------------------------------------------------------

func _build_map(tile_set: TileSet) -> Error:
	# Flat layers sit under everything (z -1), in tree order. Objects and the
	# root are y-sorted so trees and rocks draw in front of or behind the
	# player correctly.
	var root := Node2D.new()
	root.name = "FarmMap"
	root.y_sort_enabled = true
	var ground := _add_layer(root, "Ground", tile_set)
	var decor := _add_layer(root, "Decor", tile_set)
	# Empty overlays that FarmGrid paints tilled and watered soil onto.
	_add_layer(root, "Soil", tile_set)
	_add_layer(root, "Wet", tile_set)
	var walls := _add_layer(root, "Walls", tile_set)
	var objects := _add_layer(root, "Objects", tile_set)
	objects.z_index = 0
	objects.y_sort_enabled = true

	var rng := RandomNumberGenerator.new()
	rng.seed = 1885
	for y: int in MAP_SIZE.y:
		for x: int in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if _is_water(cell):
				var mask := Blob.mask_at(cell, _is_water_or_outside)
				ground.set_cell(cell, Tiles.SRC_WATER, Blob.coords(mask))
				if mask == 255 and rng.randf() < 0.3:
					decor.set_cell(cell, Tiles.SRC_RIPPLE, RIPPLE)
			elif _is_border(cell):
				ground.set_cell(cell, Tiles.SRC_FLOOR, Tiles.GROUND[0], ALT)
				if (x + y) % 2 == 0:
					objects.set_cell(cell, Tiles.SRC_NATURE, TREES[rng.randi() % TREES.size()], ALT)
			elif CABIN.has_point(cell):
				# Wall pieces carry their own strip of floor, so they stand on
				# dirt; only the room itself is planked.
				var wall_tile := _wall_tile(cell)
				if wall_tile == NONE:
					ground.set_cell(cell, Tiles.SRC_PLANK, PLANK_FLOOR)
				else:
					ground.set_cell(cell, Tiles.SRC_FLOOR, Tiles.GROUND[0])
					walls.set_cell(cell, Tiles.SRC_WALL, wall_tile)
			else:
				ground.set_cell(cell, Tiles.SRC_FLOOR, _ground_tile(rng))
				_scatter(cell, rng, decor, objects)

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
	layer.z_index = -1
	root.add_child(layer)
	layer.owner = root
	return layer


## Top water row of the river at column `x`. It wanders a row either way.
func _river_top(x: int) -> int:
	return 2 + roundi(sin(x * 0.35))


func _is_water(cell: Vector2i) -> bool:
	var top := _river_top(cell.x)
	return cell.y >= top and cell.y < top + RIVER_WIDTH


## The river runs off both sides of the map, so off-map counts as water and
## the edge tiles do not grow a bank there.
func _is_water_or_outside(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= MAP_SIZE.x:
		return _is_water(Vector2i(clampi(cell.x, 0, MAP_SIZE.x - 1), cell.y))
	return _is_water(cell)


func _is_border(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == MAP_SIZE.x - 1 or cell.y == MAP_SIZE.y - 1


func _in_clearing(cell: Vector2i) -> bool:
	for area: Rect2i in CLEARINGS:
		if area.has_point(cell):
			return true
	return false


## Mostly plain dirt, sometimes one of the marked variants.
func _ground_tile(rng: RandomNumberGenerator) -> Vector2i:
	if rng.randf() < 0.8:
		return Tiles.GROUND[0]
	return Tiles.GROUND[1 + rng.randi() % (Tiles.GROUND.size() - 1)]


## Which wall piece a cabin cell gets, or NONE for the floor and the doorway.
func _wall_tile(cell: Vector2i) -> Vector2i:
	if cell == CABIN_DOOR:
		return NONE
	var left := cell.x == CABIN.position.x
	var right := cell.x == CABIN.end.x - 1
	var top := cell.y == CABIN.position.y
	var bottom := cell.y == CABIN.end.y - 1
	if top:
		return WALL_TL if left else (WALL_TR if right else WALL_T)
	if bottom:
		return WALL_BL if left else (WALL_BR if right else WALL_B)
	if left:
		return WALL_L
	if right:
		return WALL_R
	return NONE


## Decides what, if anything, lies or grows on an open ground cell.
func _scatter(cell: Vector2i, rng: RandomNumberGenerator, decor: TileMapLayer, objects: TileMapLayer) -> void:
	# The far bank of the river is out of reach, so let it grow thick.
	var far_bank := cell.y < _river_top(cell.x)
	# Greener close to the water, cottonwood style.
	var near_river := cell.y <= _river_top(cell.x) + RIVER_WIDTH + 4
	if _in_clearing(cell) and not far_bank:
		# Cleared ground still gets the odd pebble or twig.
		if rng.randf() < 0.04:
			decor.set_cell(cell, Tiles.SRC_DETAIL, DETAILS[rng.randi() % DETAILS.size()])
		return
	# Keep the cells beside water open so the bank stays visible and reachable.
	if _is_water(cell + Vector2i.UP) or _is_water(cell + Vector2i.DOWN):
		return

	var roll := rng.randf()
	var tree_chance := 0.07 if near_river else 0.035
	if far_bank:
		tree_chance = 0.3
	if roll < tree_chance:
		var pick := rng.randf()
		if pick < 0.12 and near_river:
			objects.set_cell(cell, Tiles.SRC_NATURE, BIG_TREES[rng.randi() % BIG_TREES.size()])
		elif pick < 0.22 and not near_river:
			objects.set_cell(cell, Tiles.SRC_NATURE, DEAD_TREE)
		else:
			objects.set_cell(cell, Tiles.SRC_NATURE, TREES[rng.randi() % TREES.size()])
		return
	roll -= tree_chance
	if roll < 0.035:
		objects.set_cell(cell, Tiles.SRC_NATURE, ROCKS[rng.randi() % ROCKS.size()])
		return
	roll -= 0.035
	if roll < 0.06:
		var weeds := WEEDS if near_river or rng.randf() < 0.5 else DRY_BRUSH
		objects.set_cell(cell, Tiles.SRC_NATURE, weeds[rng.randi() % weeds.size()])
		return
	roll -= 0.06
	var grass_chance := 0.2 if near_river else 0.1
	if roll < grass_chance:
		var plants := FLOWERS if rng.randf() < 0.25 else GRASS
		objects.set_cell(cell, Tiles.SRC_NATURE, plants[rng.randi() % plants.size()])
		return
	roll -= grass_chance
	if roll < 0.05:
		decor.set_cell(cell, Tiles.SRC_DETAIL, DETAILS[rng.randi() % DETAILS.size()])
	elif roll < 0.058 and not near_river:
		decor.set_cell(cell, Tiles.SRC_DETAIL, BONES[rng.randi() % BONES.size()])
