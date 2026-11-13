extends Node
## Calendar (autoload "GameClock"). M1 only counts days; the time of day and
## seasons are added here in M2.

var day: int = 1


## Rolls the calendar over. Listeners to day_ended run their overnight
## simulation (crop growth, shipping payout) before the counter changes.
func advance_day() -> void:
	EventBus.day_ended.emit(day)
	day += 1
	EventBus.day_started.emit(day)
