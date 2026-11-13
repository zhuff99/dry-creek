class_name ScreenFade
extends ColorRect
## A black sheet over the whole screen that fades in and out. Await cover()
## to know the screen is hidden, then reveal() to bring the picture back.

const SECONDS := 0.2


func _ready() -> void:
	modulate.a = 0.0


func cover() -> void:
	await _fade_to(1.0)


func reveal() -> void:
	await _fade_to(0.0)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", alpha, SECONDS)
	await tween.finished
