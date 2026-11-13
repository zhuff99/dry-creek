class_name WildlifeSpawner
extends Node
## Puts a few wild animals on the map each day.
##
## Where they turn up is worked out from the day number, so leaving the area
## and coming back the same day finds them in the same places, and the ones
## already killed stay dead (GameState.wildlife_killed) until tomorrow.
##
## They only start on bare ground beside brush or rocks, and never close to
## home, so clearing land around the ranch pushes them back.

const TRIES_PER_ANIMAL := 60
## Animals do not start within this many tiles of each other.
const SPACING := 4

@export var creature_scene: PackedScene
@export var farm_grid: FarmGrid
## The y-sorted node the animals are added to.
@export var entities: Node2D
@export_range(0, 20) var count: int = 3
## No animal starts within this many tiles of `home`.
@export var home: Node2D
@export_range(0, 40) var safe_tiles: int = 12
## The part of the map to use, in cells.
@export var region := Rect2i(1, 6, 46, 25)

var _animals: Array[Node2D] = []


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	# Wait for the map and the grid to be ready.
	_spawn_all.call_deferred()


## Removes every animal this spawner made.
func clear() -> void:
	for animal: Node2D in _animals:
		if is_instance_valid(animal):
			animal.queue_free()
	_animals.clear()


## Adds one animal at a spot of the caller's choosing. It is not remembered
## as one of the day's animals.
func spawn_at(where: Vector2) -> Node2D:
	var animal := creature_scene.instantiate() as Node2D
	entities.add_child(animal)
	animal.global_position = where
	_animals.append(animal)
	return animal


func _on_day_started(_day: int) -> void:
	_spawn_all()


func _spawn_all() -> void:
	clear()
	if creature_scene == null or farm_grid == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([owner.name, name, GameClock.day])
	var taken: Array[Vector2i] = []
	for index: int in count:
		# Pick the spot before checking whether this one is dead, so the
		# others land in the same places either way.
		var cell := _pick_cell(rng, taken)
		if cell == Vector2i(-1, -1):
			continue
		taken.append(cell)
		var key := "%s/%s/%d" % [owner.name, name, index]
		if GameState.wildlife_killed.has(key):
			continue
		var animal := spawn_at(farm_grid.cell_center(cell))
		if animal.has_signal(&"died"):
			animal.connect(&"died", func() -> void: GameState.wildlife_killed[key] = true)


func _pick_cell(rng: RandomNumberGenerator, taken: Array[Vector2i]) -> Vector2i:
	var home_cell := farm_grid.cell_at(home.global_position) if home != null else Vector2i(-999, -999)
	for attempt: int in TRIES_PER_ANIMAL:
		var cell := Vector2i(
			rng.randi_range(region.position.x, region.end.x - 1),
			rng.randi_range(region.position.y, region.end.y - 1),
		)
		if _is_good_spot(cell, home_cell, taken):
			return cell
	return Vector2i(-1, -1)


func _is_good_spot(cell: Vector2i, home_cell: Vector2i, taken: Array[Vector2i]) -> bool:
	# Bare, untilled, unblocked dirt.
	if not farm_grid.can_till(cell):
		return false
	var from_home := (cell - home_cell).abs()
	if maxi(from_home.x, from_home.y) < safe_tiles:
		return false
	for other: Vector2i in taken:
		var apart := (cell - other).abs()
		if maxi(apart.x, apart.y) < SPACING:
			return false
	# Something to hide beside: a plant, a rock or a tree next door.
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if farm_grid.is_blocked(cell + offset):
			return true
	return false
