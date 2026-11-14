extends Node2D
## Holds the area the player is in and swaps it for another when a door asks
## (EventBus.area_change_requested). The screen fades to black over the swap.

## Where the player wakes after passing out.
const HOME_SCENE := "res://scenes/world/cabin_interior.tscn"
const HOME_SPAWN := &"bed"

@export var fade: ScreenFade

## The area on screen now.
var area: WorldArea

var _changing: bool = false
## Set when the player passes out; acted on once the screen is black.
var _carry_home: bool = false


func _ready() -> void:
	for child: Node in get_children():
		if child is WorldArea:
			area = child
			break
	EventBus.area_change_requested.connect(change_area)
	EventBus.player_passed_out.connect(_on_player_passed_out)
	EventBus.day_started.connect(_on_day_started)


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
	_swap(scene, spawn)
	await fade.reveal()
	get_tree().paused = false
	_changing = false


## Replaces the area on screen. No fade: call it while the screen is hidden.
func _swap(scene: PackedScene, spawn: StringName) -> void:
	if area != null:
		# Out of the tree at once, so the two areas never coexist.
		remove_child(area)
		area.queue_free()
	area = scene.instantiate() as WorldArea
	add_child(area)
	area.place_player(spawn)


func _on_player_passed_out(_money_lost: int, _cause: StringName) -> void:
	_carry_home = true


## The day turns over while the night screen is black, which is the moment
## to move a player who passed out into their own bed.
func _on_day_started(_day: int) -> void:
	if _carry_home:
		_carry_home = false
		_swap(load(HOME_SCENE) as PackedScene, HOME_SPAWN)
