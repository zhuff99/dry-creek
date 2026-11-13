extends StaticBody2D
## The homestead cabin. It has no inside yet, so using the door turns in for
## the night. The day transition UI handles the actual rollover.

@onready var _door: Interactable = $Door


func _ready() -> void:
	_door.interacted.connect(_on_door_used)


func _on_door_used(_player: Player) -> void:
	EventBus.sleep_requested.emit()
