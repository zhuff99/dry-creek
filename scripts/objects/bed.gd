extends StaticBody2D
## Sleeping ends the day, but only at night: the bed cannot be used before
## GameClock.BEDTIME. The day transition UI handles the actual rollover.

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Player) -> void:
	if not GameClock.can_sleep():
		EventBus.toast_requested.emit("It's too early to sleep. You can turn in from 8 PM.")
		Audio.play(&"error")
		return
	EventBus.sleep_requested.emit()
