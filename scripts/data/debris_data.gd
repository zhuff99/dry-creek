class_name DebrisData
extends Resource
## Something that clutters the ranch and can be cleared with the right tool:
## a rock, a tree, a weed, a tuft of grass.
##
## Tiles on the map's Objects layer name one of these through the TileSet's
## "debris" custom data, so painting a tile is all it takes to place one.

@export var id: StringName
@export var display_name: String
## The only tool that clears it.
@export var tool: ToolData.ToolType = ToolData.ToolType.AXE
## Tool hits needed to remove it.
@export_range(1, 20) var hits: int = 1
## What it leaves behind. May be empty.
@export var drop_item: ItemData
@export_range(0, 20) var drop_min: int = 1
@export_range(0, 20) var drop_max: int = 1
## Colour of the chips that fly when it is hit.
@export var chip_color := Color(0.42, 0.28, 0.17)
## Sound cue ids (see SoundCue): each hit that leaves it standing, and the
## hit that removes it. Either may be left empty.
@export var hit_sound: StringName
@export var break_sound: StringName
