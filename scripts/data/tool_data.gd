class_name ToolData
extends ItemData
## A tool the player uses on a tile. Axe and pickaxe join in M2.

enum ToolType { HOE, WATERING_CAN }
## Which motion the player makes when using the tool.
enum UseAnimation { SWING, POUR }

@export var tool_type: ToolType = ToolType.HOE
@export var use_animation: UseAnimation = UseAnimation.SWING
