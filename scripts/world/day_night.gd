class_name DayNight
extends CanvasModulate
## Tints the world by the time of day: a cool dawn, plain daylight, a gold
## evening, a red sunset, then blue night. It sits beside the area inside the
## World node, so it colours whichever area is showing and never the UI.
##
## Indoors the tint is mostly replaced by warm firelight.

## [minutes from midnight, colour]. Times between two entries blend.
const KEYS: Array[Array] = [
	[6 * 60, Color(0.78, 0.74, 0.86)],
	[7 * 60 + 30, Color(1, 1, 1)],
	[17 * 60, Color(1, 1, 1)],
	[18 * 60 + 30, Color(1.0, 0.87, 0.68)],
	[19 * 60 + 45, Color(0.94, 0.70, 0.60)],
	[21 * 60, Color(0.52, 0.52, 0.78)],
	[22 * 60 + 30, Color(0.38, 0.42, 0.68)],
]
const INDOOR_LIGHT := Color(1.0, 0.93, 0.82)
## How much of the indoor light replaces the sky's tint inside.
const INDOOR_SHARE := 0.6

@onready var _world: Node = get_parent()


func _process(_delta: float) -> void:
	var tint := tint_at(GameClock.minutes)
	var area: WorldArea = _world.area
	if area != null and area.indoors:
		tint = tint.lerp(INDOOR_LIGHT, INDOOR_SHARE)
	color = tint


## The outdoor tint at a time of day.
static func tint_at(minutes: float) -> Color:
	if minutes <= KEYS[0][0]:
		return KEYS[0][1]
	for i: int in range(1, KEYS.size()):
		if minutes <= KEYS[i][0]:
			var share := inverse_lerp(KEYS[i - 1][0], KEYS[i][0], minutes)
			return (KEYS[i - 1][1] as Color).lerp(KEYS[i][1], share)
	return KEYS[-1][1]


## 0 in full daylight, 1 in the dead of night. Lamps use it to know how
## brightly to burn.
static func darkness_at(minutes: float) -> float:
	var night: float = (KEYS[-1][1] as Color).get_luminance()
	return clampf(inverse_lerp(1.0, night, tint_at(minutes).get_luminance()), 0.0, 1.0)
