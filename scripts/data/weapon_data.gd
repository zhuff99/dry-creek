class_name WeaponData
extends ItemData
## A firearm. Every number that decides how a gun handles lives here, so a
## rifle or a shotgun is a new resource file, not new code.
##
## How a shot works: the gun points along the middle of an aim cone. The
## cone starts wide when you raise the gun, narrows while you hold still,
## and each shot lands somewhere inside it, more often near the middle.

## The small picture of the gun in the hand, drawn pointing right.
@export var held_sprite: Texture2D
## What it fires. Rounds are carried in the inventory.
@export var ammo_item: ItemData
## Rounds it holds when full.
@export_range(1, 20) var chambers: int = 6
@export_range(1, 20) var damage: int = 2
## How far a bullet goes, in pixels (16 to a tile).
@export_range(16.0, 640.0, 8.0) var reach: float = 176.0

@export_group("Aim cone, in degrees")
## Width at the moment the gun comes up, and the widest it ever gets.
@export_range(0.0, 60.0, 0.5) var snap_spread: float = 16.0
## Width after holding aim, standing still.
@export_range(0.0, 60.0, 0.5) var steady_spread: float = 1.5
## Width it settles at while walking.
@export_range(0.0, 60.0, 0.5) var moving_spread: float = 9.0
## Seconds of holding still to go from snap to steady.
@export_range(0.05, 3.0, 0.05) var steady_seconds: float = 0.6
## Added by each shot.
@export_range(0.0, 60.0, 0.5) var recoil_spread: float = 7.0

@export_group("Handling")
## Walking speed while aiming or reloading, as a share of normal.
@export_range(0.0, 1.0, 0.05) var aim_walk_speed: float = 0.45

@export_group("Timing, in seconds")
## Shortest time between shots (cocking the hammer).
@export_range(0.05, 3.0, 0.05) var fire_interval: float = 0.45
## Time to load one round.
@export_range(0.05, 3.0, 0.05) var seconds_per_round: float = 0.4

@export_group("World")
## How far the report carries, in pixels. Nothing listens yet; NPC hearing
## (milestone 5) will use it.
@export_range(0.0, 4000.0, 16.0) var noise_radius: float = 640.0

@export_group("Sound cues")
@export var fire_sound: StringName
@export var empty_sound: StringName
@export var load_sound: StringName
@export var draw_sound: StringName
@export var holster_sound: StringName
