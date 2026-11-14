class_name CoyotePack
extends Node
## Brings the coyotes onto the farm at night and tells each one what to do.
##
## They only come while the player is out on the farm after dark. Going to
## bed means the night passes without them; stepping indoors only puts them
## off until the player comes back out. The ones killed stay dead until
## tomorrow night (GameState.coyotes_killed_tonight).

## When the howling starts, as a warning, and when they arrive.
const WARN_MINUTES := 21 * 60 + 30
const RAID_MINUTES := 22 * 60
## Seconds after the farm appears (or the hour strikes) before they show.
const ENTRY_SECONDS := 3.0
## They come in from the outermost tiles, this far from the player at least.
const EDGE_TILES := 4
const MIN_TILES_FROM_PLAYER := 12

@export var coyote_scene: PackedScene
@export var farm_grid: FarmGrid
@export var paths: PathGrid
## The y-sorted node the coyotes are added to.
@export var entities: Node2D
@export var cabin: Node2D
@export_range(0, 12) var pack_size: int = 3

var coyotes: Array[Coyote] = []

var _released: bool = false
var _entry_wait: float = ENTRY_SECONDS
var _warned: bool = false


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	# Already past the warning when the farm appears: no need to repeat it.
	_warned = GameClock.minutes >= WARN_MINUTES


func _process(delta: float) -> void:
	if not _warned and GameClock.minutes >= WARN_MINUTES:
		_warned = true
		Audio.play(&"coyote_howl")
		EventBus.toast_requested.emit("Coyotes are howling out past the brush.")
	if _released or GameClock.minutes < RAID_MINUTES:
		return
	_entry_wait -= delta
	if _entry_wait <= 0.0:
		release()


## Puts tonight's remaining coyotes on the map. Returns how many.
func release() -> int:
	_released = true
	var wanted := pack_size - GameState.coyotes_killed_tonight
	if wanted <= 0 or coyote_scene == null:
		return 0
	var spots := _entry_cells()
	if spots.is_empty():
		return 0
	spots.shuffle()
	for index: int in mini(wanted, spots.size()):
		spawn_at(farm_grid.cell_center(spots[index]))
	Audio.play(&"coyote_howl")
	EventBus.toast_requested.emit("Coyotes on the ranch!")
	return coyotes.size()


func spawn_at(where: Vector2) -> Coyote:
	var coyote := coyote_scene.instantiate() as Coyote
	entities.add_child(coyote)
	coyote.global_position = where
	coyotes.append(coyote)
	coyote.died.connect(func() -> void: coyotes.erase(coyote))
	coyote.join(self, paths)
	return coyote


func clear() -> void:
	for coyote: Coyote in coyotes:
		if is_instance_valid(coyote):
			coyote.queue_free()
	coyotes.clear()


## What `coyote` should do now. The first of the pack goes for the cabin,
## the rest for the crops; whoever has nothing left to spoil hunts the player.
func job_for(coyote: Coyote) -> Coyote.Job:
	var wall_stands := GameState.cabin_damage < GameState.CABIN_MAX_DAMAGE and cabin != null
	var crop := crop_for(coyote)
	var leader := not coyotes.is_empty() and coyotes[0] == coyote
	if leader and wall_stands:
		return Coyote.Job.CABIN
	if crop != Vector2i(-1, -1):
		return Coyote.Job.CROP
	if wall_stands:
		return Coyote.Job.CABIN
	return Coyote.Job.HUNT


## The nearest crop no other coyote is already after, or (-1, -1).
func crop_for(coyote: Coyote) -> Vector2i:
	var taken: Array[Vector2i] = []
	for other: Coyote in coyotes:
		if other != coyote and is_instance_valid(other) and other.job == Coyote.Job.CROP:
			taken.append(other.job_cell)
	var here := farm_grid.cell_at(coyote.global_position)
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for cell: Vector2i in GameState.farm.crop_cells():
		if taken.has(cell):
			continue
		var distance := Vector2(cell - here).length()
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best


## A place to stand in front of the cabin's wall.
func cabin_spot() -> Vector2:
	return cabin.global_position + Vector2(randf_range(-34.0, 34.0), 10.0)


## Open tiles near the edge of the map and well away from the player.
func _entry_cells() -> Array[Vector2i]:
	var region := farm_grid.ground_layer.get_used_rect()
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var player_cell := farm_grid.cell_at(player.global_position) if player != null else Vector2i(-999, -999)
	var cells: Array[Vector2i] = []
	for cell: Vector2i in paths.open_cells():
		var inset := mini(
			mini(cell.x - region.position.x, region.end.x - 1 - cell.x),
			mini(cell.y - region.position.y, region.end.y - 1 - cell.y))
		if inset > EDGE_TILES or farm_grid.is_water(cell):
			continue
		var apart := (cell - player_cell).abs()
		if maxi(apart.x, apart.y) >= MIN_TILES_FROM_PLAYER:
			cells.append(cell)
	return cells


func _on_day_started(_day: int) -> void:
	clear()
	_released = false
	_warned = false
	_entry_wait = ENTRY_SECONDS
