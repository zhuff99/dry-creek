class_name BuildableData
extends Resource
## Something the player can put up on the farm with the saw: a length of
## fence, a gate, a lantern post. Add a new one by making a scene for it
## (rooted in a BuiltPiece) and a resource of this kind in
## res://resources/buildables.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Shown as the see-through preview on the tile about to be built on.
@export var icon: Texture2D
## The build menu's tab it is under.
@export var category: String = "Other"
## The piece itself. Its origin sits on the bottom edge of its tile.
@export var scene: PackedScene
## What it is made of, and how many it takes.
@export var material: ItemData
@export_range(0, 99) var material_count: int = 2
## Stamina it takes to put up.
@export_range(0.0, 20.0, 0.5) var stamina_cost: float = 2.0
## Blows it stands before it comes down.
@export_range(1, 20) var max_health: int = 3
## Joins up with the pieces beside it, the way a run of fence does.
@export var connects: bool = false
## Where it comes in the list the saw cycles through. Lowest first.
@export var sort_order: int = 0
