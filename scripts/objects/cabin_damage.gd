extends Node2D
## What the coyotes have done to the cabin's front wall: claw marks for each
## point of damage. It is mended with the hammer, one piece of wood and one
## swing per point (see PlayerItemUser), which is why it is in the
## "repairable" group and answers its three questions.
##
## A torn-up cabin is draughty, so the player sleeps worse in it (see
## GameState.DRAUGHT_STAMINA).

const MARK := Color("3b2a22")
## Where marks may go on the wall, left and right of the door and below the
## windows, in the cabin's own coordinates.
const WALL_SPANS: Array[Rect2] = [Rect2(-38, -9, 24, 6), Rect2(14, -9, 24, 6)]
## The cabin's footprint, in its own coordinates: a click on any tile whose
## centre is inside counts as a click on the cabin.
const FOOTPRINT := Rect2(-44, -30, 88, 34)


func _ready() -> void:
	add_to_group(&"repairable")
	EventBus.cabin_damage_changed.connect(func(_damage: int) -> void: queue_redraw())


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


## True if the tile `cell` of `grid` is part of the cabin.
func covers_cell(grid: FarmGrid, cell: Vector2i) -> bool:
	return FOOTPRINT.has_point(to_local(grid.cell_center(cell)))


## Points of damage waiting to be mended.
func repair_needed() -> int:
	return GameState.cabin_damage


func repair(amount: int) -> void:
	GameState.mend_cabin(amount)
