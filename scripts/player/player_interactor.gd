extends Area2D
## Finds the nearest Interactable in reach and triggers it on the interact key.

var _nearby: Array[Interactable] = []
var _current: Interactable


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _process(_delta: float) -> void:
	var nearest := _find_nearest()
	if nearest != _current:
		_current = nearest
		EventBus.interaction_prompt_changed.emit(nearest.prompt if nearest != null else "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and _current != null:
		_current.interact(owner as Player)
		get_viewport().set_input_as_handled()


func _find_nearest() -> Interactable:
	var nearest: Interactable = null
	var best := INF
	for candidate: Interactable in _nearby:
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best:
			best = distance
			nearest = candidate
	return nearest


func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		_nearby.append(area)


func _on_area_exited(area: Area2D) -> void:
	_nearby.erase(area)
