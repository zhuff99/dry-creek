class_name FarmGrid
extends Node2D
## Bridge between the tile map and FarmData: answers "what can I do on this
## tile" and keeps the soil tiles and crop sprites in sync with the data.

const CROP_SCENE := preload("res://scenes/farming/crop.tscn")
const TILE_SOURCE_ID := 0
## Name of the TileSet custom data layer that marks ground the hoe can till.
const TILLABLE_LAYER := "tillable"

@export var ground_layer: TileMapLayer
## Overlay layer that shows tilled and watered soil on top of the ground.
@export var soil_layer: TileMapLayer
## Crops are added here so they y-sort with the player.
@export var crop_parent: Node2D
## Atlas coordinates of the soil tiles. Re-point these when swapping art.
@export var tilled_tile := Vector2i(0, 1)
@export var watered_tile := Vector2i(1, 1)

var _farm: FarmData
var _crop_nodes: Dictionary[Vector2i, Crop] = {}


func _ready() -> void:
	add_to_group(&"farm_grid")
	_farm = GameState.farm
	_farm.plot_changed.connect(_refresh_cell)
	# Redraw whatever already exists (returning to the farm, or a loaded save).
	for cell: Vector2i in _farm.plots:
		_refresh_cell(cell)


func cell_at(world_position: Vector2) -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(world_position))


func cell_center(cell: Vector2i) -> Vector2:
	return ground_layer.to_global(ground_layer.map_to_local(cell))


func is_tillable(cell: Vector2i) -> bool:
	var tile := ground_layer.get_cell_tile_data(cell)
	return tile != null and tile.get_custom_data(TILLABLE_LAYER) == true


func can_till(cell: Vector2i) -> bool:
	return is_tillable(cell) and not _farm.is_tilled(cell)


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
		_remove_crop_node(cell)
		return
	soil_layer.set_cell(cell, TILE_SOURCE_ID, watered_tile if plot.watered else tilled_tile)
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


func _remove_crop_node(cell: Vector2i) -> void:
	var crop_node: Crop = _crop_nodes.get(cell)
	if crop_node != null:
		crop_node.queue_free()
		_crop_nodes.erase(cell)
