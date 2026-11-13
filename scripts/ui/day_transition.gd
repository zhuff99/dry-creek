extends ColorRect
## Fade to black, roll the day over, show a short summary, fade back in.
## Pauses the game for the duration so nothing moves during the night.

const FADE_SECONDS := 0.6
const HOLD_SECONDS := 1.4

var _busy: bool = false
var _last_payout: int = 0

@onready var _label: Label = $Label


func _ready() -> void:
	modulate.a = 0.0
	EventBus.sleep_requested.connect(_run)
	EventBus.shipment_paid.connect(_on_shipment_paid)


func _on_shipment_paid(total: int) -> void:
	_last_payout = total


func _run() -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = true
	_label.text = ""
	await _fade_to(1.0)

	GameClock.advance_day()
	_label.text = "Day %d" % GameClock.day
	if _last_payout > 0:
		_label.text += "\nShipped goods sold for $%d" % _last_payout
	await get_tree().create_timer(HOLD_SECONDS).timeout

	await _fade_to(0.0)
	get_tree().paused = false
	_busy = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", alpha, FADE_SECONDS)
	await tween.finished
