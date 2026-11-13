class_name WorldEvent
extends RefCounted
## A thing that happened at a place, caused by someone.
##
## This is the unit NPC perception will work on: an NPC that can see or hear
## `position` gets to react to the event (flee, report it, change faction
## reputation). Events nobody perceives have no consequences.

var type: StringName
var actor: Node
var position: Vector2
var data: Dictionary
var day: int


func _init(p_type: StringName, p_actor: Node, p_position: Vector2, p_data: Dictionary = {}) -> void:
	type = p_type
	actor = p_actor
	position = p_position
	data = p_data
	day = GameClock.day
