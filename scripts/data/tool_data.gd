class_name ToolData
extends ItemData
## A tool the player uses on a tile. Axe and pickaxe join in M2.

enum ToolType { HOE, WATERING_CAN }
## Which motion the player makes. DIP is the watering can filling up.
enum UseAnimation { SWING, POUR, DIP }

@export var tool_type: ToolType = ToolType.HOE
@export var use_animation: UseAnimation = UseAnimation.SWING
## Uses the tool holds before it must be refilled. 0 = never runs out.
@export_range(0, 200) var capacity: int = 0
