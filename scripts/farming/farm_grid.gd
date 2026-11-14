class_name FarmGrid
extends Node2D
## Bridge between the tile map and FarmData: answers "what can I do on this
## tile" and keeps the soil tiles and crop sprites in sync with the data.

const CROP_SCENE := preload("res://scenes/farming/crop.tscn")
## TileSet custom data layers: ground the hoe can till, and open water.
const TILLABLE_LAYER := "tillable"
const WATER_LAYER := "water"
## Custom data on Objects-layer tiles: the id of a DebrisData resource.
const DEBRIS_LAYER := "debris"

@export var ground_layer: TileMapLayer
## Overlay layer that shows tilled soil on top of the ground.
@export var soil_layer: TileMapLayer
## Overlay on top of that: the darker soil of plots watered today.
@export var wet_layer: TileMapLayer
## Rocks, trees and brush. A cell with anything on this layer cannot be tilled.
@export var objects_layer: TileMapLayer
## Crops are added here so they y-sort with the player.
@export var crop_parent: Node2D

var _farm: FarmData
var _crop_nodes: Dictionary[Vector2i, Crop] = {}
var _built_nodes: Dictionary[Vector2i, BuiltPiece] = {}

## The four sides a built piece can join, and the bit BuiltPiece uses for each.
const SIDES := {
	Vector2i.UP: BuiltPiece.NORTH, Vector2i.RIGHT: BuiltPiece.EAST,
	Vector2i.DOWN: BuiltPiece.SOUTH, Vector2i.LEFT: BuiltPiece.WEST,
}


func _ready() -> void:
	add_to_group(&"farm_grid")
	_farm = GameState.farm
	_farm.plot_changed.connect(_refresh_cell)
	_farm.debris_cleared.connect(_remove_debris_tile)
	# The saved map always has every rock and tree; take out the cleared ones.
	for cell: Vector2i in _farm.cleared_debris:
		_remove_debris_tile(cell)
	# Redraw whatever already exists (returning to the farm, or a loaded save).
	for cell: Vector2i in _farm.plots:
		_refresh_cell(cell)
	_farm.built_changed.connect(_refresh_built)
	for cell: Vector2i in _farm.built:
		_show_built(cell)


func cell_at(world_position: Vector2) -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(world_position))


func cell_center(cell: Vector2i) -> Vector2:
	return ground_layer.to_global(ground_layer.map_to_local(cell))


func is_tillable(cell: Vector2i) -> bool:
	var tile := ground_layer.get_cell_tile_data(cell)
	return tile != null and tile.get_custom_data(TILLABLE_LAYER) == true


## True for river and pond tiles, where the watering can fills up.
func is_water(cell: Vector2i) -> bool:
	var tile := ground_layer.get_cell_tile_data(cell)
	return tile != null and tile.get_custom_data(WATER_LAYER) == true


## True if a rock, tree, weed or grass tuft occupies the cell.
func is_blocked(cell: Vector2i) -> bool:
	return objects_layer != null and objects_layer.get_cell_source_id(cell) != -1


## The clearable thing at `cell`, or null. Decorative objects that name no
## debris type still block tilling but cannot be cleared.
func debris_at(cell: Vector2i) -> DebrisData:
	if objects_layer == null:
		return null
	var tile := objects_layer.get_cell_tile_data(cell)
	if tile == null:
		return null
	var id: String = tile.get_custom_data(DEBRIS_LAYER)
	return ItemDB.get_debris(id) if id != "" else null


## Lands one tool hit on the debris at `cell`. Returns true if it was removed.
func hit_debris(cell: Vector2i) -> bool:
	var debris := debris_at(cell)
	return debris != null and _farm.hit_debris(cell, debris.hits)


func can_till(cell: Vector2i) -> bool:
	return can_build(cell)


## Bare, open ground with nothing on it: not soil, not road, not built on.
func can_build(cell: Vector2i) -> bool:
	return is_tillable(cell) and not is_blocked(cell) and not _farm.is_tilled(cell) and not _farm.is_built(cell)


## The node standing for what is built at `cell`, or null.
func built_node(cell: Vector2i) -> BuiltPiece:
	return _built_nodes.get(cell)


func till(cell: Vector2i) -> bool:
	return can_till(cell) and _farm.till(cell)


func can_water(cell: Vector2i) -> bool:
	var plot := _farm.get_plot(cell)
	return plot != null and not plot.watered


func water(cell: Vector2i) -> bool:
	return _farm.water(cell)


func can_plant(cell: Vector2i) -> bool:
	return _farm.can_plant(cell)


func plant(cell: Vector2i, crop: CropData) -> bool:
	return _farm.plant(cell, crop)


func can_harvest(cell: Vector2i) -> bool:
	return _farm.can_harvest(cell)


func crop_at(cell: Vector2i) -> CropData:
	return _farm.get_crop(cell)


func harvest(cell: Vector2i) -> ItemStack:
	return _farm.harvest(cell)


func _refresh_cell(cell: Vector2i) -> void:
	var plot := _farm.get_plot(cell)
	if plot == null:
		soil_layer.erase_cell(cell)
		wet_layer.erase_cell(cell)
		_remove_crop_node(cell)
	# A plot's edges depend on its neighbours, so redraw the 3x3 around it.
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			_draw_soil(cell + Vector2i(offset_x, offset_y))
	if plot == null:
		return
	if not plot.has_crop():
		_remove_crop_node(cell)
		return
	var crop_node: Crop = _crop_nodes.get(cell)
	if crop_node == null:
		crop_node = CROP_SCENE.instantiate()
		crop_parent.add_child(crop_node)
		var tile_height := ground_layer.tile_set.tile_size.y
		crop_node.global_position = cell_center(cell) + Vector2(0, tile_height / 2.0)
		crop_node.setup(ItemDB.get_crop(plot.crop_id), plot.days_grown)
		_crop_nodes[cell] = crop_node
	else:
		crop_node.set_growth(plot.days_grown)


## Draws the soil piece that fits `cell`'s tilled neighbours, and the wet
## version over it if the plot has been watered.
func _draw_soil(cell: Vector2i) -> void:
	var plot := _farm.get_plot(cell)
	if plot == null:
		return
	var piece := BlobTiles.coords(BlobTiles.mask_at(cell, _farm.is_tilled))
	soil_layer.set_cell(cell, FarmTiles.SRC_SOIL, piece)
	if plot.watered:
		wet_layer.set_cell(cell, FarmTiles.SRC_WET_SOIL, piece)
	else:
		wet_layer.erase_cell(cell)


## A built tile changed: redraw it and the pieces beside it, whose joins
## depend on it.
func _refresh_built(cell: Vector2i) -> void:
	_show_built(cell)
	for side: Vector2i in SIDES:
		_show_built(cell + side)


func _show_built(cell: Vector2i) -> void:
	var piece := _farm.get_built(cell)
	var node: BuiltPiece = _built_nodes.get(cell)
	if piece == null:
		if node != null:
			node.queue_free()
			_built_nodes.erase(cell)
		return
	if node == null:
		node = piece.scene.instantiate() as BuiltPiece
		crop_parent.add_child(node)
		var tile_height := ground_layer.tile_set.tile_size.y
		node.global_position = cell_center(cell) + Vector2(0, tile_height / 2.0)
		_built_nodes[cell] = node
	var joined := 0
	if piece.connects:
		for side: Vector2i in SIDES:
			var other := _farm.get_built(cell + side)
			if other != null and other.connects:
				joined |= SIDES[side]
	node.refresh(joined, _farm.built_damage.get(cell, 0))


func _remove_debris_tile(cell: Vector2i) -> void:
	if objects_layer != null:
		objects_layer.erase_cell(cell)


func _remove_crop_node(cell: Vector2i) -> void:
	var crop_node: Crop = _crop_nodes.get(cell)
	if crop_node != null:
		crop_node.queue_free()
		_crop_nodes.erase(cell)
