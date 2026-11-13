class_name WorldArea
extends Node2D
## Root of one place the player can be: the farm, the inside of the cabin,
## later the town. The World node shows one at a time and frees it when the
## player leaves, so nothing an area needs to remember may live in its nodes
## (that is what GameState is for).
##
## Every area scene has the player at `Entities/Player`, and may have
## SpawnPoint markers under a `Spawns` node for doors to arrive at.

## Music playlist for this place (see MusicPlaylist).
@export var music: StringName
## The tile layer whose extent is the edge of the area. The camera stays
## inside it.
@export var ground: TileMapLayer
## For a painted room with no tile layer: the area's extent in pixels.
@export var extent: Rect2i

@onready var player: Player = $Entities/Player


func _ready() -> void:
	player.set_camera_limits(_bounds())
	Audio.play_music(music)


## Stands the player on the named spawn point. With no such point the player
## stays where the scene has them.
func place_player(spawn: StringName) -> void:
	var point := get_node_or_null("Spawns/%s" % spawn) as SpawnPoint
	if point == null:
		if spawn != &"":
			push_warning("%s has no spawn point '%s'" % [name, spawn])
		return
	player.global_position = point.global_position
	player.face(point.facing)


func _bounds() -> Rect2i:
	if ground == null:
		return extent
	var cells := ground.get_used_rect()
	var tile_size := ground.tile_set.tile_size
	return Rect2i(cells.position * tile_size, cells.size * tile_size)
