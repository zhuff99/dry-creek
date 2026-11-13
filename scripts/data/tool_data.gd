class_name ToolData
extends ItemData
## A tool the player uses on a tile. Axe and pickaxe join in M2.

enum ToolType { HOE, WATERING_CAN }

@export var tool_type: ToolType = ToolType.HOE
