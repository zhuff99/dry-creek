extends RefCounted
## Draws the inside of the homestead cabin: one room seen from above and a
## little in front, in the Ninja Adventure pack's colours. The pack's indoor
## walls are smooth and brightly painted, which is the wrong century, so the
## room's shell is made here. Furniture is separate sprites placed in the scene.
## Used by tools/build_derived_art.gd.
##
## Layout: the far wall is a face of stacked logs with a window and a stone
## fireplace; the side and near walls are seen from above as dark strips; the
## doorway is a gap in the near wall.

const Outside := preload("res://tools/cabin_painter.gd")

const SIDE := 8
const BACK := 40
const FRONT := 10
const FLOOR := Rect2i(SIDE, BACK, 144, 96)
const SIZE := Vector2i(SIDE * 2 + 144, BACK + 96 + FRONT)
const BOARD := 8
const LOG_HEIGHT := 8
const DOORWAY := Rect2i(72, BACK + 96, 16, FRONT)
const WINDOW := Rect2i(58, 13, 14, 12)
const FIREPLACE := Rect2i(104, 2, 36, BACK - 2)
const FIREBOX := Rect2i(113, 20, 18, 20)
const HEARTH := Rect2i(102, BACK, 40, 7)
const RUG := Rect2i(50, 86, 46, 26)

const FLOOR_WOOD := Outside.WOOD
const FLOOR_SEAM := Outside.WOOD_SHADE
const WALL_WOOD := Outside.WOOD_SHADE
const WALL_UNDER := Outside.WOOD_DARK
const WALL_GAP := Outside.WOOD_DEEP
const WALL_TOP := Outside.WOOD_DARK
const FLAME_LOW := Color("e46d3a")
const FLAME_MID := Color("ffad5d")
const FLAME_TIP := Color("eecf9b")
const RUG_RED := Color("e0394c")
const RUG_DARK := Color("8f3e56")
const STRAW := Color("f1c471")


static func paint() -> Image:
	var img := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1885
	_floor(img, rng)
	_rug(img)
	_back_wall(img, rng)
	Outside._window(img, WINDOW)
	_fireplace(img)
	_side_and_front_walls(img)
	Outside._outline(img)
	return img


## Floorboards running across the room, with staggered butt joints.
static func _floor(img: Image, rng: RandomNumberGenerator) -> void:
	var boards := FLOOR.grow_individual(0, 0, 0, FRONT)
	img.fill_rect(boards, FLOOR_WOOD)
	var y := boards.position.y
	while y < boards.end.y:
		Outside._hline(img, boards.position.x, boards.end.x, y + BOARD - 1, FLOOR_SEAM)
		# Where one board ends and the next begins.
		var x := boards.position.x + 10 + rng.randi() % 30
		# (The last strip under the near wall is only part of a board.)
		while x < boards.end.x - 4 and y + BOARD <= boards.end.y:
			img.fill_rect(Rect2i(x, y, 1, BOARD - 1), FLOOR_SEAM)
			# A nail either side of the joint.
			img.set_pixel(x - 2, y + 3, Outside.WOOD_DARK)
			img.set_pixel(x + 2, y + 3, Outside.WOOD_DARK)
			x += 34 + rng.randi() % 30
		y += BOARD
	# The far wall's shadow on the boards.
	img.fill_rect(Rect2i(FLOOR.position.x, FLOOR.position.y, FLOOR.size.x, 2), FLOOR_SEAM)


## A striped wool blanket for a rug, with a fringe at each end.
static func _rug(img: Image) -> void:
	img.fill_rect(RUG, RUG_RED)
	for band: int in [3, RUG.size.y - 5]:
		img.fill_rect(Rect2i(RUG.position.x, RUG.position.y + band, RUG.size.x, 2), FLAME_TIP)
	img.fill_rect(Rect2i(RUG.position.x, RUG.position.y + RUG.size.y / 2 - 3, RUG.size.x, 6), RUG_DARK)
	# A row of diamonds down the middle band.
	var x := RUG.position.x + 3
	var mid := RUG.position.y + RUG.size.y / 2
	while x < RUG.end.x - 3:
		img.fill_rect(Rect2i(x, mid - 1, 4, 2), FLAME_TIP)
		img.fill_rect(Rect2i(x + 1, mid - 2, 2, 4), FLAME_TIP)
		x += 8
	Outside._hline(img, RUG.position.x, RUG.end.x, RUG.position.y, RUG_DARK)
	Outside._hline(img, RUG.position.x, RUG.end.x, RUG.end.y - 1, RUG_DARK)
	for fy: int in range(RUG.position.y + 1, RUG.end.y - 1, 2):
		img.set_pixel(RUG.position.x - 1, fy, FLAME_TIP)
		img.set_pixel(RUG.end.x, fy, FLAME_TIP)


## The far wall: the same stacked logs as outside, but in the room's shade.
static func _back_wall(img: Image, rng: RandomNumberGenerator) -> void:
	var wall := Rect2i(SIDE, 0, FLOOR.size.x, BACK)
	img.fill_rect(wall, WALL_WOOD)
	var y := wall.end.y - LOG_HEIGHT
	while y >= 0:
		Outside._hline(img, wall.position.x, wall.end.x, y + LOG_HEIGHT - 2, WALL_UNDER)
		Outside._hline(img, wall.position.x, wall.end.x, y + LOG_HEIGHT - 1, WALL_GAP)
		Outside._hline(img, wall.position.x, wall.end.x, y, Outside.WOOD)
		for i: int in 8:
			var gx := wall.position.x + 4 + rng.randi() % (wall.size.x - 12)
			var gy := y + 2 + rng.randi() % (LOG_HEIGHT - 5)
			Outside._hline(img, gx, gx + 2 + rng.randi() % 4, gy, WALL_UNDER)
		y -= LOG_HEIGHT


## Fieldstone fireplace with a timber mantel, a fire, and a stone hearth.
static func _fireplace(img: Image) -> void:
	_stones(img, FIREPLACE)
	_stones(img, HEARTH)
	Outside._hline(img, HEARTH.position.x, HEARTH.end.x, HEARTH.end.y - 1, Outside.STONE_DARK)
	# Mantel beam.
	var mantel := Rect2i(FIREPLACE.position.x - 2, 13, FIREPLACE.size.x + 4, 4)
	img.fill_rect(mantel, Outside.WOOD_LIGHT)
	Outside._hline(img, mantel.position.x, mantel.end.x, mantel.end.y - 1, Outside.WOOD)
	Outside._hline(img, mantel.position.x, mantel.end.x, mantel.end.y, Outside.OUTLINE)
	# Firebox, with an arched top.
	img.fill_rect(FIREBOX, Outside.OUTLINE)
	img.set_pixel(FIREBOX.position.x, FIREBOX.position.y, Outside.STONE_SHADE)
	img.set_pixel(FIREBOX.end.x - 1, FIREBOX.position.y, Outside.STONE_SHADE)
	# Two logs and the fire on them.
	var base_y := FIREBOX.end.y - 4
	img.fill_rect(Rect2i(FIREBOX.position.x + 2, base_y, FIREBOX.size.x - 4, 3), Outside.WOOD_DEEP)
	Outside._hline(img, FIREBOX.position.x + 3, FIREBOX.end.x - 3, base_y, Outside.PLANK)
	var cx := FIREBOX.position.x + FIREBOX.size.x / 2
	# Each row: [rows above the logs, half width, colour].
	for flame: Array in [
		[1, 5, FLAME_LOW], [2, 5, FLAME_LOW], [3, 4, FLAME_LOW], [4, 3, FLAME_LOW], [5, 2, FLAME_LOW],
		[6, 1, FLAME_LOW], [1, 3, FLAME_MID], [2, 3, FLAME_MID], [3, 2, FLAME_MID], [4, 1, FLAME_MID],
		[1, 1, FLAME_TIP], [2, 1, FLAME_TIP],
	]:
		Outside._hline(img, cx - flame[1], cx + flame[1], base_y - flame[0], flame[2])
	# A lick of flame off to each side so it is not a neat triangle.
	img.fill_rect(Rect2i(cx - 6, base_y - 4, 1, 2), FLAME_LOW)
	img.fill_rect(Rect2i(cx + 4, base_y - 6, 1, 2), FLAME_LOW)
	img.set_pixel(cx - 1, base_y - 8, FLAME_MID)


## Fills `rect` with laid stone: courses four pixels high, joints staggered.
static func _stones(img: Image, rect: Rect2i) -> void:
	img.fill_rect(rect, Outside.STONE)
	img.fill_rect(Rect2i(rect.end.x - 3, rect.position.y, 3, rect.size.y), Outside.STONE_SHADE)
	var course := 0
	var y := rect.position.y + 3
	while y < rect.end.y:
		Outside._hline(img, rect.position.x, rect.end.x, y, Outside.STONE_DARK)
		var x := rect.position.x + (3 if course % 2 == 0 else 7)
		while x < rect.end.x:
			img.fill_rect(Rect2i(x, y + 1, 1, mini(3, rect.end.y - y - 1)), Outside.STONE_DARK)
			x += 8
		y += 4
		course += 1


## The other three walls are only their tops: dark strips with a line for
## each log, and a gap in the near one for the door with a straw mat in it.
static func _side_and_front_walls(img: Image) -> void:
	var strips: Array[Rect2i] = [
		Rect2i(0, 0, SIDE, SIZE.y),
		Rect2i(SIZE.x - SIDE, 0, SIDE, SIZE.y),
		Rect2i(0, FLOOR.end.y, DOORWAY.position.x, FRONT),
		Rect2i(DOORWAY.end.x, FLOOR.end.y, SIZE.x - DOORWAY.end.x, FRONT),
	]
	for strip: Rect2i in strips:
		img.fill_rect(strip, WALL_TOP)
	# Side walls: a line across for each log end.
	for y: int in range(LOG_HEIGHT - 1, SIZE.y, LOG_HEIGHT):
		Outside._hline(img, 0, SIDE, y, WALL_GAP)
		Outside._hline(img, SIZE.x - SIDE, SIZE.x, y, WALL_GAP)
	# The edge where each wall meets the room.
	img.fill_rect(Rect2i(SIDE - 1, 0, 1, FLOOR.end.y), Outside.OUTLINE)
	img.fill_rect(Rect2i(SIZE.x - SIDE, 0, 1, FLOOR.end.y), Outside.OUTLINE)
	Outside._hline(img, SIDE - 1, DOORWAY.position.x + 1, FLOOR.end.y, Outside.OUTLINE)
	Outside._hline(img, DOORWAY.end.x - 1, SIZE.x - SIDE + 1, FLOOR.end.y, Outside.OUTLINE)
	img.fill_rect(Rect2i(DOORWAY.position.x, FLOOR.end.y, 1, FRONT), Outside.OUTLINE)
	img.fill_rect(Rect2i(DOORWAY.end.x - 1, FLOOR.end.y, 1, FRONT), Outside.OUTLINE)
	# Doormat.
	var mat := Rect2i(DOORWAY.position.x + 2, FLOOR.end.y + 2, DOORWAY.size.x - 4, FRONT - 4)
	img.fill_rect(mat, STRAW)
	for y: int in range(mat.position.y + 1, mat.end.y, 2):
		Outside._hline(img, mat.position.x, mat.end.x, y, Outside.WOOD_LIGHT)
