class_name StaminaBar
extends Control
## The stamina bar. Gold is what is left right now. The hatched stretch at the
## right end is what the day's work has worn away: stamina will not refill
## past where it starts until the player sleeps.

const BACK := Color(0.08, 0.05, 0.03)
const FILL := Color("f1c471")
## The part that can still come back with a rest.
const RESTABLE := Color("6b5a3a")
const WORN := Color("4a3a30")

var _stamina: float = 1.0
var _ceiling: float = 1.0
var _max: float = 1.0


func show_levels(stamina: float, ceiling: float, max_stamina: float) -> void:
	_stamina = stamina
	_ceiling = ceiling
	_max = maxf(max_stamina, 1.0)
	queue_redraw()


func _draw() -> void:
	var width := int(size.x)
	var height := int(size.y)
	var filled := roundi(width * _stamina / _max)
	var reach := roundi(width * _ceiling / _max)
	draw_rect(Rect2(0, 0, width, height), BACK)
	draw_rect(Rect2(0, 0, reach, height), RESTABLE)
	draw_rect(Rect2(0, 0, filled, height), FILL)
	# Diagonal hatching over the worn-away end.
	for x: int in range(reach, width):
		for y: int in height:
			if (x + y) % 3 == 0:
				draw_rect(Rect2(x, y, 1, 1), WORN)
