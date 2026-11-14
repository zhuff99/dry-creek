extends Node2D
## What the coyotes have done to the cabin's front wall: claw marks for each
## point of damage, and a spot at the wall where the player mends it with
## wood, one piece per point.
##
## A torn-up cabin is draughty, so the player sleeps worse in it (see
## GameState.DRAUGHT_STAMINA).

const WOOD := &"wood"
const MARK := Color("3b2a22")
## Where marks may go on the wall, left and right of the door and below the
## windows, in the cabin's own coordinates.
const WALL_SPANS: Array[Rect2] = [Rect2(-38, -9, 24, 6), Rect2(14, -9, 24, 6)]

@onready var _mend: Interactable = $Mend


func _ready() -> void:
	EventBus.cabin_damage_changed.connect(_on_damage_changed)
	_mend.interacted.connect(_on_mend)
	_on_damage_changed(GameState.cabin_damage)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	for index: int in GameState.cabin_damage:
		# Each point of damage is always in the same place.
		rng.seed = hash(["claws", index])
		var span := WALL_SPANS[index % WALL_SPANS.size()]
		var at := Vector2(
			roundf(rng.randf_range(span.position.x, span.end.x - 6.0)),
			roundf(rng.randf_range(span.position.y, span.end.y - 4.0)))
		for claw: int in 3:
			var top := at + Vector2(claw * 2.0, 0.0)
			draw_line(top + Vector2(0.5, 0.5), top + Vector2(2.5, 4.5), MARK, 1.0)


func _on_damage_changed(damage: int) -> void:
	queue_redraw()
	# Off the "interactable" layer when there is nothing to mend.
	_mend.collision_layer = 4 if damage > 0 else 0
	_mend.prompt = "Mend the cabin (%d wood)" % damage


func _on_mend(_player: Player) -> void:
	var wood := ItemDB.get_item(WOOD)
	var have := GameState.inventory.count_of(wood)
	if have <= 0:
		EventBus.toast_requested.emit("You need wood to mend the cabin.")
		Audio.play(&"error")
		return
	var used := mini(have, GameState.cabin_damage)
	GameState.inventory.remove_item(wood, used)
	GameState.mend_cabin(used)
	Audio.play(&"chop")
	if GameState.cabin_damage > 0:
		EventBus.toast_requested.emit("Patched what you could. %d more wood would finish it." % GameState.cabin_damage)
	else:
		EventBus.toast_requested.emit("The cabin is mended.")
