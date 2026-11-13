extends RefCounted
## Draws the homestead's log cabin, pixel by pixel, in the Ninja Adventure
## pack's own colours so it sits with the rest of the art. The pack has no
## frontier buildings, only Japanese houses, so this one is made here.
## Used by tools/build_derived_art.gd.
##
## The picture is the front of a one-room cabin: a shake roof with a stone
## chimney, a wall of stacked logs with their ends showing at the corners, a
## plank door and two small windows.

## One spare row at the bottom so the outline can run under the wall.
const SIZE := Vector2i(96, 81)

# The pack's palette.
const OUTLINE := Color("141b1b")
const WOOD := Color("a3754e")
const WOOD_SHADE := Color("91522c")
const WOOD_DARK := Color("61372e")
const WOOD_DEEP := Color("5c2d25")
const WOOD_LIGHT := Color("d78b4a")
const PLANK := Color("965340")
## The one colour not taken from the pack: weathered shakes, between two of
## its browns, so the roof reads darker than the wall without going red.
const SHAKE := Color("79463a")
const CREAM := Color("eecf9b")
const GLASS := Color("3b3643")
const GLINT := Color("abc2bc")
const STONE := Color("8d977f")
const STONE_SHADE := Color("5f7160")
const STONE_DARK := Color("4e484a")

# Layout, in pixels.
const WALL := Rect2i(8, 46, 80, 34)
const LOG_HEIGHT := 8
const ROOF_TOP := 12
const ROOF_BOTTOM := 49
const SHAKE_HEIGHT := 6
const DOOR := Rect2i(42, 57, 12, 23)
const WINDOWS: Array[Rect2i] = [Rect2i(19, 58, 12, 11), Rect2i(65, 58, 12, 11)]
const CHIMNEY := Rect2i(68, 2, 11, 24)


static func paint() -> Image:
	var img := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1885
	_wall(img, rng)
	_log_ends(img)
	_door(img)
	for window: Rect2i in WINDOWS:
		_window(img, window)
	_chimney(img)
	_roof(img, rng)
	_outline(img)
	return img


## Stacked logs: each is a band with a darker underside and a deep line
## where it rests on the one below.
static func _wall(img: Image, rng: RandomNumberGenerator) -> void:
	img.fill_rect(WALL, WOOD)
	var y := WALL.end.y - LOG_HEIGHT
	while y > WALL.position.y - LOG_HEIGHT:
		_hline(img, WALL.position.x, WALL.end.x, y + LOG_HEIGHT - 2, WOOD_SHADE)
		_hline(img, WALL.position.x, WALL.end.x, y + LOG_HEIGHT - 1, WOOD_DEEP)
		# A few short marks of grain, never lined up with the log above.
		for i: int in 5:
			var gx := WALL.position.x + 4 + rng.randi() % (WALL.size.x - 12)
			var gy := y + 1 + rng.randi() % (LOG_HEIGHT - 4)
			_hline(img, gx, gx + 2 + rng.randi() % 4, gy, WOOD_SHADE)
		y -= LOG_HEIGHT
	# Shade thrown by the roof's overhang.
	img.fill_rect(Rect2i(WALL.position.x, ROOF_BOTTOM + 1, WALL.size.x, 2), WOOD_DARK)


## The side walls' logs poke out past each corner, showing their cut ends.
static func _log_ends(img: Image) -> void:
	for side: int in 2:
		var x := WALL.position.x - 3 if side == 0 else WALL.end.x - 3
		var y := WALL.end.y - LOG_HEIGHT
		while y >= ROOF_BOTTOM:
			img.fill_rect(Rect2i(x, y, 6, LOG_HEIGHT - 1), WOOD_DEEP)
			img.fill_rect(Rect2i(x + 1, y, 4, LOG_HEIGHT - 1), WOOD_LIGHT)
			img.fill_rect(Rect2i(x, y + 1, 6, LOG_HEIGHT - 3), WOOD_LIGHT)
			# Growth ring.
			img.fill_rect(Rect2i(x + 2, y + 2, 2, 3), WOOD)
			_hline(img, x + 1, x + 5, y + LOG_HEIGHT - 2, WOOD_SHADE)
			y -= LOG_HEIGHT


static func _door(img: Image) -> void:
	# Frame, then planks.
	img.fill_rect(DOOR.grow_individual(2, 2, 2, 0), WOOD_DEEP)
	img.fill_rect(DOOR.grow_individual(1, 1, 1, 0), WOOD_LIGHT)
	img.fill_rect(DOOR, PLANK)
	for x: int in [DOOR.position.x + 3, DOOR.position.x + 7]:
		img.fill_rect(Rect2i(x, DOOR.position.y, 1, DOOR.size.y), WOOD_DARK)
	# Two cross braces and a latch.
	_hline(img, DOOR.position.x, DOOR.end.x, DOOR.position.y + 3, WOOD_DARK)
	_hline(img, DOOR.position.x, DOOR.end.x, DOOR.end.y - 5, WOOD_DARK)
	img.fill_rect(Rect2i(DOOR.end.x - 3, DOOR.position.y + 11, 2, 2), CREAM)
	# Doorstep.
	_hline(img, DOOR.position.x - 2, DOOR.end.x + 2, DOOR.end.y - 1, WOOD_DEEP)


static func _window(img: Image, rect: Rect2i) -> void:
	img.fill_rect(rect.grow(1), WOOD_DEEP)
	img.fill_rect(rect, WOOD_LIGHT)
	var glass := rect.grow(-1)
	img.fill_rect(glass, GLASS)
	# Four panes.
	img.fill_rect(Rect2i(glass.position.x + glass.size.x / 2 - 1, glass.position.y, 2, glass.size.y), WOOD_LIGHT)
	_hline(img, glass.position.x, glass.end.x, glass.position.y + glass.size.y / 2, WOOD_LIGHT)
	# A glint in the top-left pane.
	img.set_pixel(glass.position.x + 1, glass.position.y + 1, GLINT)
	img.set_pixel(glass.position.x + 2, glass.position.y + 1, GLINT)
	img.set_pixel(glass.position.x + 1, glass.position.y + 2, GLINT)
	# Sill.
	img.fill_rect(Rect2i(rect.position.x - 2, rect.end.y, rect.size.x + 4, 2), WOOD_LIGHT)
	_hline(img, rect.position.x - 2, rect.end.x + 2, rect.end.y + 2, WOOD_DEEP)


## Fieldstone chimney standing behind the ridge.
static func _chimney(img: Image) -> void:
	img.fill_rect(CHIMNEY, STONE)
	# Shaded right side.
	img.fill_rect(Rect2i(CHIMNEY.end.x - 3, CHIMNEY.position.y, 3, CHIMNEY.size.y), STONE_SHADE)
	# Mortar lines, staggered like laid stone.
	var row := 0
	var y := CHIMNEY.position.y + 3
	while y < CHIMNEY.end.y:
		_hline(img, CHIMNEY.position.x, CHIMNEY.end.x, y, STONE_DARK)
		var x := CHIMNEY.position.x + (2 if row % 2 == 0 else 5)
		while x < CHIMNEY.end.x:
			img.fill_rect(Rect2i(x, y + 1, 1, 3), STONE_DARK)
			x += 6
		y += 4
		row += 1
	# Cap.
	img.fill_rect(Rect2i(CHIMNEY.position.x - 1, CHIMNEY.position.y, CHIMNEY.size.x + 2, 3), STONE)
	_hline(img, CHIMNEY.position.x - 1, CHIMNEY.end.x + 1, CHIMNEY.position.y + 2, STONE_DARK)


## Split-wood shakes in overlapping rows. The roof leans back, so it is a
## little narrower at the ridge than at the eave.
static func _roof(img: Image, rng: RandomNumberGenerator) -> void:
	var rows := ROOF_BOTTOM - ROOF_TOP + 1
	for i: int in rows:
		var y := ROOF_TOP + i
		var inset := roundi(6.0 * (1.0 - float(i) / (rows - 1)))
		var left := 1 + inset
		var right := SIZE.x - 1 - inset
		_hline(img, left, right, y, SHAKE)
		var in_row := (i - 3) % SHAKE_HEIGHT if i >= 3 else -1
		if i < 3:
			# Ridge board.
			_hline(img, left, right, y, WOOD if i < 2 else WOOD_DARK)
		elif in_row == 0:
			# Lit top edge of a row of shakes.
			_hline(img, left, right, y, PLANK)
		elif in_row == SHAKE_HEIGHT - 1:
			_hline(img, left, right, y, WOOD_DEEP)
	# Gaps between shakes, offset from row to row.
	var row := 0
	var y0 := ROOF_TOP + 3
	while y0 + SHAKE_HEIGHT - 1 <= ROOF_BOTTOM:
		# Shakes are narrow and uneven, which is what keeps them from
		# looking like bricks.
		var x := 3 + (row % 2) * 2 + rng.randi() % 2
		while x < SIZE.x - 3:
			for dy: int in range(0, SHAKE_HEIGHT - 1):
				var here := img.get_pixel(x, y0 + dy)
				if here.is_equal_approx(SHAKE) or here.is_equal_approx(PLANK):
					img.set_pixel(x, y0 + dy, WOOD_DEEP)
			x += 4 + rng.randi() % 3
		y0 += SHAKE_HEIGHT
		row += 1
	# Eave: a dark lip along the bottom edge.
	_hline(img, 1, SIZE.x - 1, ROOF_BOTTOM, WOOD_DEEP)


## A one-pixel dark line around everything drawn, like the pack's own sprites.
static func _outline(img: Image) -> void:
	var solid := img.duplicate() as Image
	var size := img.get_size()
	for y: int in size.y:
		for x: int in size.x:
			if solid.get_pixel(x, y).a > 0.0:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var at := Vector2i(x, y) + step
				if at.x >= 0 and at.y >= 0 and at.x < size.x and at.y < size.y and solid.get_pixelv(at).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break


## Horizontal line from `left` up to but not including `right`.
static func _hline(img: Image, left: int, right: int, y: int, color: Color) -> void:
	img.fill_rect(Rect2i(left, y, right - left, 1), color)
