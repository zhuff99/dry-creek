extends Node2D
## Root of the farm area. Fits the camera to the map and starts its music.

@onready var _ground: TileMapLayer = $Map/Ground
@onready var _player: Player = $Entities/Player


func _ready() -> void:
	var cells := _ground.get_used_rect()
	var tile_size := _ground.tile_set.tile_size
	_player.set_camera_limits(Rect2i(cells.position * tile_size, cells.size * tile_size))
	Audio.play_music(&"farm")
