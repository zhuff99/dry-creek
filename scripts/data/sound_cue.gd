class_name SoundCue
extends Resource
## One named sound effect: `Audio.play(&"chop")` plays the cue with id "chop".
##
## Game code only ever names a cue, so swapping a sound means editing its
## resource in res://resources/sounds/, never touching a script.

@export var id: StringName
## One is picked at random each time, so a repeated action does not sound
## like a machine. A single entry is fine.
@export var streams: Array[AudioStream] = []
## Loudness trim. The pack's sounds differ a lot, this evens them out.
@export_range(-40.0, 24.0, 0.5) var volume_db: float = 0.0
## Each play picks a pitch between these. 1.0 is the recording as it is.
@export_range(0.5, 2.0, 0.01) var pitch_min: float = 0.95
@export_range(0.5, 2.0, 0.01) var pitch_max: float = 1.05
