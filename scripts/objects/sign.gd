extends Interactable
## Something with writing on it. Using it shows the words.

@export_multiline var text: String


func interact(player: Player) -> void:
	super(player)
	EventBus.toast_requested.emit(text)
