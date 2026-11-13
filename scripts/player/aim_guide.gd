class_name AimGuide
extends Node2D
## Draws the aim cone: a centre line to whatever the shot would strike, and
## the two edges a shot could stray to. Drawn in world coordinates.

const EDGE := Color(1, 1, 1, 0.22)
const LINE := Color(1, 1, 1, 0.55)
const ON_TARGET := Color(1, 0.35, 0.3, 0.9)
const DASH := 4.0

var _from: Vector2
var _centre: Vector2
var _left: Vector2
var _right: Vector2
var _on_target: bool = false


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 1
	hide()


## Points are where each ray ends: the centre of the cone and its two edges.
func show_cone(from: Vector2, centre: Vector2, left: Vector2, right: Vector2, on_target: bool) -> void:
	_from = from
	_centre = centre
	_left = left
	_right = right
	_on_target = on_target
	show()
	queue_redraw()


func _draw() -> void:
	draw_line(_from, _left, EDGE, 1.0)
	draw_line(_from, _right, EDGE, 1.0)
	var colour := ON_TARGET if _on_target else LINE
	draw_dashed_line(_from, _centre, colour, 1.0, DASH)
	# A small cross where the shot would land.
	draw_line(_centre + Vector2(-2, 0), _centre + Vector2(3, 0), colour, 1.0)
	draw_line(_centre + Vector2(0, -2), _centre + Vector2(0, 3), colour, 1.0)
