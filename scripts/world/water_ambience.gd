extends AudioStreamPlayer
## The sound of running water, louder the closer the listener is to it.
##
## Not a positional sound: the river runs the width of the map, so there is no
## one point for it to come from. Instead this looks for the nearest water
## tile a few times a second and sets the volume from the distance.

const SILENT_DB := -60.0

@export var farm_grid: FarmGrid
## Whose ears these are (the player).
@export var listener: Node2D
## Distance in tiles at which the water can no longer be heard.
@export_range(1, 30) var hearing_range: int = 12
@export_range(-40.0, 6.0, 0.5) var loudest_db: float = 0.0
## Seconds between distance checks.
@export_range(0.05, 1.0, 0.05) var check_interval: float = 0.2

var _target_db: float = SILENT_DB
var _until_check: float = 0.0


func _ready() -> void:
	# Keeps running under the inventory rather than cutting out.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_looping()
	volume_db = SILENT_DB
	play()


func _process(delta: float) -> void:
	_until_check -= delta
	if _until_check <= 0.0:
		_until_check = check_interval
		_target_db = _volume_for(_tiles_to_water())
	# Ease toward the target so walking does not make the volume step.
	volume_db = lerpf(volume_db, _target_db, minf(1.0, delta * 4.0))


## Distance to the nearest water tile, or `hearing_range` if there is none in
## range. Searches outward in square rings, so it stops at the first hit.
func _tiles_to_water() -> int:
	if farm_grid == null or listener == null:
		return hearing_range
	var center := farm_grid.cell_at(listener.global_position)
	for ring: int in hearing_range:
		for step: int in range(-ring, ring + 1):
			if farm_grid.is_water(center + Vector2i(step, -ring)) \
					or farm_grid.is_water(center + Vector2i(step, ring)) \
					or farm_grid.is_water(center + Vector2i(-ring, step)) \
					or farm_grid.is_water(center + Vector2i(ring, step)):
				return ring
	return hearing_range


func _volume_for(tiles: int) -> float:
	var closeness := 1.0 - float(tiles) / hearing_range
	if closeness <= 0.0:
		return SILENT_DB
	# Squared so it swells near the bank instead of rising evenly.
	return loudest_db + linear_to_db(closeness * closeness)


## WAV files import as play-once. The river recording is cut to repeat
## cleanly (see tools/build_derived_audio.gd), so loop the whole of it.
func _make_looping() -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)
