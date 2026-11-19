class_name SidePanel
extends PanelContainer
## A menu that opens at the top of the screen on whichever side the player
## is not, so it never covers them: the backpack, the build menu.
##
## The game keeps running while one is open. The player can walk, but clicks
## in the world do nothing (GameState.menu_open). Only one is open at a time:
## opening one closes the others. Escape closes it.

const EDGE := 4.0
const TOP := 22.0
## The player has to be this far past the middle of the screen before the
## panel moves to the other side, so it does not flick back and forth.
const SIDE_SWAP_MARGIN := 40.0


func _ready() -> void:
	hide()
	add_to_group(&"side_panels")


func _process(_delta: float) -> void:
	if visible:
		_keep_clear_of_player()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	# Not while the night screen or a door has the game paused.
	if visible or get_tree().paused:
		return
	for other: Node in get_tree().get_nodes_in_group(&"side_panels"):
		if other != self:
			other.close()
	show()
	reset_size()
	_keep_clear_of_player(true)
	_update_menu_flag()
	Audio.play(&"ui_open")
	_on_opened()


func close() -> void:
	if not visible:
		return
	hide()
	_update_menu_flag()
	Audio.play(&"ui_close")
	_on_closed()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## For subclasses: called after the panel appears, and after it goes.
func _on_opened() -> void:
	pass


func _on_closed() -> void:
	pass


func _update_menu_flag() -> void:
	var any_open := false
	for panel: Node in get_tree().get_nodes_in_group(&"side_panels"):
		if panel is Control and (panel as Control).visible:
			any_open = true
	GameState.menu_open = any_open


## Sits on the left of the screen while the player is on the right, and the
## other way about.
func _keep_clear_of_player(choose_now: bool = false) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var screen := get_viewport_rect().size
	var on_left := position.x < screen.x / 2.0
	if player != null:
		var player_x := player.get_global_transform_with_canvas().origin.x
		var middle := screen.x / 2.0
		var margin := 0.0 if choose_now else SIDE_SWAP_MARGIN
		if player_x < middle - margin:
			on_left = false
		elif player_x > middle + margin:
			on_left = true
	position = Vector2(EDGE if on_left else screen.x - size.x - EDGE, TOP)
