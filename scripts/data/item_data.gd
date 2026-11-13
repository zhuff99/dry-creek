class_name ItemData
extends Resource
## Base definition for anything that can sit in an inventory slot.
## Tools and seeds extend this; plain goods (corn, beans) use it directly.

## Unique key used by ItemDB and save files. Never change it once shipped.
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export_range(1, 999) var max_stack: int = 99
## What the shipping crate pays per unit. 0 means it cannot be sold.
@export var sell_price: int = 0
