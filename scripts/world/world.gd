extends Node2D
## Holds the area the player is in and swaps it for another when a door asks
## (EventBus.area_change_requested). The screen fades to black over the swap.

@export var fade: ScreenFade

## The area on screen now.
var area: WorldArea

var _changing: bool = false


func _ready() -> void:
	for child: Node in get_children():
		if child is WorldArea:
			area = child
			break
	EventBus.area_change_requested.connect(change_area)


func change_area(scene_path: String, spawn: StringName) -> void:
	if _changing:
		return
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("World: cannot load area '%s'" % scene_path)
		return
	_changing = true
	# Paused so nothing moves under the fade. The fade itself lives in the UI
	# layer, which keeps running.
	get_tree().paused = true
	await fade.cover()
	if area != null:
		# Out of the tree at once, so the two areas never coexist.
		remove_child(area)
		area.queue_free()
	area = scene.instantiate() as WorldArea
	add_child(area)
	area.place_player(spawn)
	await fade.reveal()
	get_tree().paused = false
	_changing = false
