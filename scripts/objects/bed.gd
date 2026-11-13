extends StaticBody2D
## Sleeping ends the day. The day transition UI handles the actual rollover.

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Player) -> void:
	EventBus.sleep_requested.emit()
