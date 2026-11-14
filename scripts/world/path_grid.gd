class_name PathGrid
extends Node
## Finds ways across the farm for animals: around trees, rocks, water, rails,
## buildings and whatever the player has built. It reads the map as the
## physics sees it, one tile at a time, so anything solid is avoided without
## being listed here.
##
## It also knows the way an animal would take if the player's fences were not
## there, which is how a coyote picks the piece of fence to break through.
##
## The map is read on first use and again after the player clears or builds
## something.

## What stops an animal: the "world", "low" and "gate" physics layers.
const SOLID_MASK := 1 | 16 | 64
## The probe is a little smaller than a tile so neighbours do not count.
const PROBE := Vector2(10, 10)
const NOWHERE := Vector2i(-1, -1)

@export var farm_grid: FarmGrid

var _astar: AStarGrid2D
## The same map with everything the player built taken away.
var _unfenced: AStarGrid2D
var _stale: bool = true


func _ready() -> void:
	GameState.farm.debris_cleared.connect(func(_cell: Vector2i) -> void: _stale = true)
	GameState.farm.built_changed.connect(func(_cell: Vector2i) -> void: _stale = true)


## Points to walk through from one place to another, or nothing if there is
## no way. An end that is inside something solid is moved to the nearest
## open tile.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	_refresh()
	var start := nearest_open(farm_grid.cell_at(from))
	var goal := nearest_open(farm_grid.cell_at(to))
	var points := PackedVector2Array()
	if start == NOWHERE or goal == NOWHERE:
		return points
	for cell: Vector2i in _astar.get_id_path(start, goal):
		points.append(farm_grid.cell_center(cell))
	return points


func can_reach(from: Vector2, to: Vector2) -> bool:
	return not path(from, to).is_empty()


## Where to break through to get from `from` to the tile at `to` when the
## player's building is in the way: {"piece": the built tile to attack,
## "stand": where to stand to do it}. Empty if nothing built is in the way,
## or there is no way even without it.
func breach(from: Vector2, to: Vector2) -> Dictionary:
	_refresh()
	var start := nearest_open(farm_grid.cell_at(from))
	var goal := farm_grid.cell_at(to)
	if start == NOWHERE or not _unfenced.is_in_boundsv(goal) or _unfenced.is_point_solid(goal):
		return {}
	var previous := start
	for cell: Vector2i in _unfenced.get_id_path(start, goal):
		if _astar.is_point_solid(cell):
			return {"piece": cell, "stand": farm_grid.cell_center(previous)}
		previous = cell
	return {}


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
## NOWHERE.
func nearest_open(cell: Vector2i) -> Vector2i:
	_refresh()
	for reach: int in 5:
		var best := NOWHERE
		var best_distance := INF
		for y: int in range(-reach, reach + 1):
			for x: int in range(-reach, reach + 1):
				if maxi(absi(x), absi(y)) != reach:
					continue
				var candidate := cell + Vector2i(x, y)
				if is_open(candidate) and Vector2(x, y).length() < best_distance:
					best = candidate
					best_distance = Vector2(x, y).length()
		if best != NOWHERE:
			return best
	return NOWHERE


func _refresh() -> void:
	if not _stale and _astar != null:
		return
	_stale = false
	_astar = _new_grid()
	_unfenced = _new_grid()
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
			var built := GameState.farm.is_built(cell)
			# A piece put up this very moment may not be in the physics yet.
			var solid := built or not space.intersect_shape(query, 1).is_empty()
			_astar.set_point_solid(cell, solid)
			_unfenced.set_point_solid(cell, solid and not built)


func _new_grid() -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = farm_grid.ground_layer.get_used_rect()
	grid.cell_size = Vector2(farm_grid.ground_layer.tile_set.tile_size)
	# No cutting a corner between two solid tiles.
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	return grid
