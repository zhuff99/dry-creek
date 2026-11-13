class_name CreatureData
extends Resource
## The numbers for one kind of wild animal. The behaviour is in the
## creature's script; how tough, fast and touchy it is lives here.

@export var id: StringName
@export var display_name: String
## Walk sheet laid out like the player's: one column per direction (down,
## up, left, right), one row per frame.
@export var sprite_sheet: Texture2D
@export_range(1, 100) var max_health: int = 2
## Pixels per second when ambling about.
@export_range(0.0, 200.0, 1.0) var move_speed: float = 14.0
## How far from where it started it will wander, in pixels.
@export_range(0.0, 400.0, 4.0) var wander_radius: float = 40.0

@export_group("Senses, in pixels")
## Closer than this and it starts to warn.
@export_range(0.0, 400.0, 2.0) var notice_radius: float = 48.0
## Closer than this (once it has warned) and it strikes.
@export_range(0.0, 400.0, 2.0) var strike_radius: float = 26.0
## Back off past this and it settles down again.
@export_range(0.0, 400.0, 2.0) var calm_radius: float = 64.0

@export_group("Attack")
@export_range(0, 20) var damage: int = 2
## Seconds of warning it always gives before its first strike.
@export_range(0.0, 5.0, 0.05) var warn_seconds: float = 0.8
## How far a strike carries it, and how long the strike takes.
@export_range(0.0, 100.0, 1.0) var strike_reach: float = 24.0
@export_range(0.02, 1.0, 0.01) var strike_seconds: float = 0.12
## Seconds it lies still after striking, before it can strike again.
@export_range(0.0, 5.0, 0.05) var recover_seconds: float = 1.2

@export_group("Drops")
## What it leaves when killed. May be empty.
@export var drop_item: ItemData
@export_range(0, 20) var drop_min: int = 1
@export_range(0, 20) var drop_max: int = 1

@export_group("Sound cues")
@export var warn_sound: StringName
@export var attack_sound: StringName
@export var death_sound: StringName
