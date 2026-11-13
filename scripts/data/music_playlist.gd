class_name MusicPlaylist
extends Resource
## The music for one place or mood: `Audio.play_music(&"farm")`.
##
## Tracks play in random order with a stretch of quiet between them, so the
## ranch is not wall-to-wall music.

@export var id: StringName
@export var tracks: Array[MusicTrack] = []
## The pack's tracks are about a minute long, so each one plays this many
## times in a row before the quiet.
@export_range(1, 10) var plays_per_track: int = 2
## Seconds of quiet between tracks.
@export_range(0.0, 300.0, 1.0) var gap_seconds: float = 15.0
