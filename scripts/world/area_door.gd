class_name AreaDoor
extends Interactable
## A door to another area. Using it asks the World to swap areas.

## The area scene on the other side. A path rather than a scene reference,
## because two areas that lead to each other cannot both preload the other.
@export_file("*.tscn") var target_scene: String
## Name of the SpawnPoint to arrive at over there.
@export var target_spawn: StringName
@export var sound: StringName = &"door"


func interact(player: Player) -> void:
	super(player)
	Audio.play(sound)
	EventBus.area_change_requested.emit(target_scene, target_spawn)
