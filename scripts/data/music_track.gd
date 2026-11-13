class_name MusicTrack
extends Resource
## One piece of music inside a MusicPlaylist.

@export var stream: AudioStream
## Loudness trim, so quiet and loud recordings sit at the same level.
@export_range(-40.0, 12.0, 0.5) var volume_db: float = 0.0
