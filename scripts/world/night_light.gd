class_name NightLight
extends PointLight2D
## A lamp, a lit window or a fire: a soft round glow that comes up as the day
## darkens and goes out in daylight. Set its colour and `texture_scale` (its
## reach) on the node.

## Brightness in the dead of night.
@export_range(0.0, 2.0, 0.05) var strength: float = 0.8
## The share of that it keeps even in daylight. A fire indoors always glows.
@export_range(0.0, 1.0, 0.05) var always: float = 0.0
## How much the flame wavers.
@export_range(0.0, 0.3, 0.01) var flicker: float = 0.05

## One glow image shared by every light.
static var _glow: GradientTexture2D

var _time: float = 0.0


func _ready() -> void:
	if _glow == null:
		var fade := Gradient.new()
		fade.set_color(0, Color.WHITE)
		fade.set_color(1, Color(1, 1, 1, 0))
		_glow = GradientTexture2D.new()
		_glow.gradient = fade
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	texture = _glow
	# Each light wavers on its own beat.
	_time = randf() * 10.0
	_process(0.0)


func _process(delta: float) -> void:
	_time += delta
	var level := maxf(always, DayNight.darkness_at(GameClock.minutes))
	enabled = level > 0.01
	energy = strength * level * (1.0 + flicker * sin(_time * 9.0) * sin(_time * 2.3))
