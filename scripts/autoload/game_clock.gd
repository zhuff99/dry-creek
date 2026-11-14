extends Node
## Calendar and time of day (autoload "GameClock").
##
## The day runs from 6 in the morning to 2 the next morning. `minutes` counts
## from midnight and keeps counting past 24:00 for the small hours, so it only
## ever goes up during a day. Time stops whenever the game is paused. Seasons
## are added here later.

## 6:00 AM, when the player wakes.
const DAY_START := 6 * 60
## Midnight, as `minutes` counts it. Past this it is late.
const MIDNIGHT := 24 * 60
## 2:00 AM: nobody stays up past this. The player drops where they stand.
const DAY_END := 26 * 60
## Game minutes that pass each real second. At this rate ten minutes take
## seven seconds, and a whole day is fourteen minutes.
const MINUTES_PER_SECOND := 10.0 / 7.0
## The clock is read in steps of this many minutes.
const STEP := 10

var day: int = 1
var minutes: float = DAY_START:
	set(value):
		minutes = value
		var step := int(minutes) / STEP
		if step != _shown_step:
			_shown_step = step
			EventBus.time_changed.emit(shown_minutes())

var _shown_step: int = DAY_START / STEP
## True once the day has run out, until the next one starts.
var _spent: bool = false


func _process(delta: float) -> void:
	if _spent:
		return
	minutes += delta * MINUTES_PER_SECOND
	if minutes >= DAY_END:
		_spent = true
		GameState.pass_out(&"late")


## Rolls the calendar over. Listeners to day_ended run their overnight
## simulation (crop growth, shipping payout) before the counter changes.
func advance_day() -> void:
	EventBus.day_ended.emit(day)
	day += 1
	_spent = false
	minutes = DAY_START
	EventBus.day_started.emit(day)


## The time as the clock shows it: minutes from midnight, in whole steps.
func shown_minutes() -> int:
	return int(minutes) / STEP * STEP


func is_late() -> bool:
	return minutes >= MIDNIGHT


## "6:00 AM", "12:30 PM", "1:50 AM".
func time_text() -> String:
	var shown := shown_minutes()
	var hour := shown / 60 % 24
	var twelve := hour % 12
	if twelve == 0:
		twelve = 12
	return "%d:%02d %s" % [twelve, shown % 60, "AM" if hour < 12 else "PM"]
