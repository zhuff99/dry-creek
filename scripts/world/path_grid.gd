class_name PathGrid
extends Node
## Finds ways across the farm for animals: around trees, rocks, water, rails
## and buildings. It reads the map as the physics sees it, one tile at a time,
## so anything solid is avoided without being listed here.
##
## The map is read on first use and again after the player clears something.

## What stops an animal: the "world" and "low" physics layers.
const SOLID_MASK := 17
## The probe is a little smaller than a tile so neighbours do not count.
const PROBE := Vector2(10, 10)

@export var farm_grid: FarmGrid

var _astar: AStarGrid2D
var _stale: bool = true


func _ready() -> void:
	GameState.farm.debris_cleared.connect(func(_cell: Vector2i) -> void: _stale = true)


## Points to walk through from one place to another, or nothing if there is
## no way. An end that is inside something solid is moved to the nearest
## open tile.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	_refresh()
	var start := nearest_open(farm_grid.cell_at(from))
	var goal := nearest_open(farm_grid.cell_at(to))
	var points := PackedVector2Array()
	if start == Vector2i(-1, -1) or goal == Vector2i(-1, -1):
		return points
	for cell: Vector2i in _astar.get_id_path(start, goal):
		points.append(farm_grid.cell_center(cell))
	return points


func is_open(cell: Vector2i) -> bool:
	_refresh()
	return _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell)


## Every tile an animal can stand on.
func open_cells() -> Array[Vector2i]:
	_refresh()
	var cells: Array[Vector2i] = []
	var region := _astar.region
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if not _astar.is_point_solid(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	return cells


## `cell` if it is open, else the closest open tile within a few steps, else
## (-1, -1).
func nearest_open(cell: Vector2i) -> Vector2i:
	_refresh()
	for reach: int in 5:
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for y: int in range(-reach, reach + 1):
			for x: int in range(-reach, reach + 1):
				if maxi(absi(x), absi(y)) != reach:
					continue
				var candidate := cell + Vector2i(x, y)
				if is_open(candidate) and Vector2(x, y).length() < best_distance:
					best = candidate
					best_distance = Vector2(x, y).length()
		if best != Vector2i(-1, -1):
			return best
	return Vector2i(-1, -1)


func _refresh() -> void:
	if not _stale and _astar != null:
		return
	_stale = false
	_astar = AStarGrid2D.new()
	_astar.region = farm_grid.ground_layer.get_used_rect()
	_astar.cell_size = Vector2(farm_grid.ground_layer.tile_set.tile_size)
	# No cutting a corner between two solid tiles.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	var space := farm_grid.get_world_2d().direct_space_state
	var probe := RectangleShape2D.new()
	probe.size = PROBE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collision_mask = SOLID_MASK
	var region := _astar.region
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)
			query.transform = Transform2D(0.0, farm_grid.cell_center(cell))
			if not space.intersect_shape(query, 1).is_empty():
				_astar.set_point_solid(cell, true)
