class_name Interactable
extends Area2D
## Drop this Area2D (on the "interactable" physics layer) under any object the
## player should be able to use with the interact key, and connect `interacted`.

signal interacted(player: Player)

## Shown on the HUD as "[E] <prompt>" while the player is in reach.
@export var prompt: String = "Interact"


func interact(player: Player) -> void:
	interacted.emit(player)
