extends SceneTree
## Dev tool: draws the placeholder art in res://assets/placeholder/.
##
## Run from the project folder:
##   godot --headless --path . -s res://tools/gen_placeholder_art.gd
## then let the editor (or `godot --headless --path . --import`) import the PNGs.
##
## Everything is on the 16x16 grid so real art can replace it file for file.

const T := 16
const OUT := "res://assets/placeholder/"

const CLEAR := Color(0, 0, 0, 0)
const OUTLINE := Color("2a1a10")
const DIRT := Color("9a7048")
const BANK := Color("745639")
const WATER := Color("3f7fae")
const STONE := Color("8d8478")
const TILLED := Color("74492c")
const WET := Color("4e311d")
const ROCK := Color("7a5a48")
const WOOD := Color("a8763f")
const WALL := Color("5e3c26")
const LEAF := Color("4f9a3c")
const LEAF_DARK := Color("356f2c")
const CORN := Color("f2cf3f")
const BEAN := Color("b5562f")
const METAL := Color("a9b3bd")

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1885
	for sub: String in ["tiles", "characters", "objects", "items", "crops", "ui"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + sub))
	_save(_tiles(), "tiles/farm_tiles.png")
	_save(_player(), "characters/player.png")
	_save(_bed(), "objects/bed.png")
	_save(_crate(), "objects/shipping_crate.png")
	_save(_tile_cursor(), "ui/tile_cursor.png")
	_save(_hoe(), "items/hoe.png")
	_save(_watering_can(), "items/watering_can.png")
	_save(_axe(), "items/axe.png")
	_save(_pickaxe(), "items/pickaxe.png")
	_save(_scythe(), "items/scythe.png")
	_save(_wood(), "items/wood.png")
	_save(_stone(), "items/stone.png")
	_save(_fiber(), "items/fiber.png")
	_save(_seed_packet(CORN), "items/corn_seeds.png")
	_save(_seed_packet(BEAN), "items/bean_seeds.png")
	_save(_corn_item(), "items/corn.png")
	_save(_beans_item(), "items/beans.png")
	_save(_crop_strip(CORN, false), "crops/corn_growth.png")
	_save(_crop_strip(BEAN, true), "crops/beans_growth.png")
	print("Placeholder art written to ", OUT)
	quit()


# --- helpers -----------------------------------------------------------------

func _new(w: int, h: int, fill: Color = CLEAR) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return img


func _save(img: Image, rel_path: String) -> void:
	var err := img.save_png(OUT + rel_path)
	if err != OK:
		push_error("Could not save %s (error %d)" % [rel_path, err])


func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), color)


## Scatters lighter and darker pixels over a tile so flat fills read as ground.
func _speckle(img: Image, ox: int, oy: int, base: Color, amount: int) -> void:
	for i: int in amount:
		var shade := base.lightened(0.12) if _rng.randf() < 0.5 else base.darkened(0.12)
		img.set_pixel(ox + _rng.randi_range(0, T - 1), oy + _rng.randi_range(0, T - 1), shade)


# --- tiles -------------------------------------------------------------------

## Atlas layout (column, row), in 16px cells:
##   row 0: dirt a, dirt b, dirt c, river bank, cliff rock, wood floor, cabin wall
##   row 1: tilled soil, watered soil
##   row 2: river water, 4 animation frames (flowing right to left)
##   row 3: rock a, rock b, tree a top, tree b top, grass a, weed a
##   row 4: weed b, grass b, tree a base, tree b base
## Trees are 16x32 and take two cells.
func _tiles() -> Image:
	var img := _new(T * 8, T * 5)
	# Three dirt variants so open ground does not look tiled.
	for i: int in 3:
		_rect(img, i * T, 0, T, T, DIRT)
		_speckle(img, i * T, 0, DIRT, 8 + i * 4)
	# Variant b: flecks of dry grass. Variant c: pebbles.
	for p: Vector2i in [Vector2i(4, 5), Vector2i(11, 9), Vector2i(7, 13)]:
		_rect(img, T + p.x, p.y, 1, 2, Color("8f9a45"))
	for p: Vector2i in [Vector2i(3, 10), Vector2i(12, 4), Vector2i(9, 12)]:
		_rect(img, 2 * T + p.x, p.y, 2, 1, STONE)
	# River bank: damp mud.
	_rect(img, 3 * T, 0, T, T, BANK)
	_speckle(img, 3 * T, 0, BANK, 12)
	# Cliff rock: lit top edge, shadowed bottom edge.
	_rect(img, 4 * T, 0, T, T, ROCK)
	_rect(img, 4 * T, 0, T, 3, ROCK.lightened(0.2))
	_rect(img, 4 * T, T - 3, T, 3, ROCK.darkened(0.3))
	_speckle(img, 4 * T, 0, ROCK, 10)
	# Wood floor: plank seams every 4px.
	_rect(img, 5 * T, 0, T, T, WOOD)
	for y: int in range(3, T, 4):
		_rect(img, 5 * T, y, T, 1, WOOD.darkened(0.25))
	# Cabin wall: stacked logs.
	_rect(img, 6 * T, 0, T, T, WALL)
	for y: int in range(0, T, 4):
		_rect(img, 6 * T, y, T, 1, WALL.lightened(0.15))
		_rect(img, 6 * T, y + 3, T, 1, WALL.darkened(0.3))
	# Tilled and watered soil: furrows.
	for i: int in 2:
		var soil: Color = TILLED if i == 0 else WET
		_rect(img, i * T, T, T, T, soil)
		for y: int in range(2, T, 4):
			_rect(img, i * T + 1, T + y, T - 2, 1, soil.darkened(0.3))
	# Water: ripple dashes move 4px left per frame, so the river flows west.
	for frame: int in 4:
		var ox := frame * T
		_rect(img, ox, 2 * T, T, T, WATER)
		_rect(img, ox, 2 * T + 8, T, 8, WATER.darkened(0.06))
		for ripple: Vector2i in [Vector2i(2, 3), Vector2i(10, 7), Vector2i(5, 12)]:
			for dx: int in 4:
				var x := posmod(ripple.x - frame * 4 + dx, T)
				img.set_pixel(ox + x, 2 * T + ripple.y, WATER.lightened(0.35))
	_rock(img, 0, 3 * T, false)
	_rock(img, T, 3 * T, true)
	_tree(img, 2 * T, 3 * T, LEAF)
	_tree(img, 3 * T, 3 * T, Color("6f8f3a"))
	_grass(img, 4 * T, 3 * T, Color("8f9a45"))
	_grass(img, T, 4 * T, Color("6f9440"))
	_weed(img, 5 * T, 3 * T, false)
	_weed(img, 0, 4 * T, true)
	return img


func _rock(img: Image, x: int, y: int, small: bool) -> void:
	if small:
		_rect(img, x + 2, y + 9, 7, 5, OUTLINE)
		_rect(img, x + 3, y + 9, 5, 4, STONE)
		_rect(img, x + 3, y + 9, 3, 1, STONE.lightened(0.25))
		_rect(img, x + 9, y + 11, 5, 4, OUTLINE)
		_rect(img, x + 10, y + 11, 3, 3, STONE.darkened(0.1))
		return
	_rect(img, x + 2, y + 6, 12, 9, OUTLINE)
	_rect(img, x + 4, y + 5, 8, 1, OUTLINE)
	_rect(img, x + 3, y + 6, 10, 8, STONE)
	_rect(img, x + 4, y + 6, 5, 2, STONE.lightened(0.25))
	_rect(img, x + 3, y + 11, 10, 3, STONE.darkened(0.2))
	_rect(img, x + 8, y + 8, 1, 3, STONE.darkened(0.35))


## 16x32: canopy in the top cell and a half, trunk reaching the bottom edge.
func _tree(img: Image, x: int, y: int, leaf: Color) -> void:
	_rect(img, x + 4, y + 30, 9, 2, Color(0, 0, 0, 0.25))  # ground shadow
	_rect(img, x + 6, y + 18, 4, 13, Color("5b3a22"))  # trunk
	_rect(img, x + 6, y + 18, 1, 13, Color("7a5230"))
	_rect(img, x + 3, y + 3, 10, 18, OUTLINE)
	_rect(img, x + 1, y + 6, 14, 12, OUTLINE)
	_rect(img, x + 4, y + 4, 8, 16, leaf)
	_rect(img, x + 2, y + 7, 12, 10, leaf)
	_rect(img, x + 4, y + 5, 5, 3, leaf.lightened(0.2))
	_rect(img, x + 3, y + 9, 3, 2, leaf.lightened(0.2))
	_rect(img, x + 8, y + 13, 5, 3, leaf.darkened(0.2))
	_rect(img, x + 5, y + 17, 6, 2, leaf.darkened(0.25))


func _grass(img: Image, x: int, y: int, blade: Color) -> void:
	# Blades as (column, height) pairs rising from the bottom of the cell.
	for b: Vector2i in [Vector2i(3, 4), Vector2i(5, 7), Vector2i(6, 5), Vector2i(8, 8), Vector2i(10, 6), Vector2i(11, 4), Vector2i(13, 5)]:
		_rect(img, x + b.x, y + T - 1 - b.y, 1, b.y, blade)
	_rect(img, x + 8, y + T - 9, 1, 3, blade.lightened(0.25))
	_rect(img, x + 5, y + T - 8, 1, 2, blade.lightened(0.25))


## A scrubby weed, or with `dry` a brown tumbleweed.
func _weed(img: Image, x: int, y: int, dry: bool) -> void:
	if dry:
		var twig := Color("8a6a42")
		_rect(img, x + 4, y + 7, 8, 8, twig.darkened(0.35))
		_rect(img, x + 5, y + 6, 6, 10, twig.darkened(0.35))
		_rect(img, x + 5, y + 8, 6, 6, twig)
		for p: Vector2i in [Vector2i(6, 9), Vector2i(9, 8), Vector2i(8, 11), Vector2i(6, 12), Vector2i(10, 12)]:
			_rect(img, x + p.x, y + p.y, 1, 1, twig.darkened(0.45))
		return
	var leaf := Color("5f8a4a")
	_rect(img, x + 7, y + 8, 2, 7, leaf.darkened(0.3))  # stem
	_rect(img, x + 3, y + 9, 4, 2, leaf)
	_rect(img, x + 9, y + 7, 4, 2, leaf)
	_rect(img, x + 4, y + 12, 3, 2, leaf)
	_rect(img, x + 9, y + 11, 3, 2, leaf)
	_rect(img, x + 6, y + 5, 4, 3, leaf.lightened(0.15))
	_rect(img, x + 7, y + 4, 2, 1, Color("d9c85a"))  # seed head


# --- characters and objects --------------------------------------------------

## Three 16x16 frames: facing down, facing right, facing up.
## Facing left reuses the right frame flipped.
func _player() -> Image:
	var img := _new(T * 3, T)
	var hat := Color("6d4628")
	var brim := Color("5b3a22")
	var skin := Color("e3b58c")
	var shirt := Color("b0392e")
	var legs := Color("3c5a87")
	for frame: int in 3:
		var ox := frame * T
		_rect(img, ox + 3, 3, 10, 1, brim)
		_rect(img, ox + 5, 1, 6, 2, hat)
		_rect(img, ox + 4, 8, 8, 5, shirt)
		_rect(img, ox + 5, 13, 2, 3, legs)
		_rect(img, ox + 9, 13, 2, 3, legs)
		match frame:
			0:  # down: full face
				_rect(img, ox + 5, 4, 6, 4, skin)
				_rect(img, ox + 6, 5, 1, 1, OUTLINE)
				_rect(img, ox + 9, 5, 1, 1, OUTLINE)
			1:  # right: profile, one eye, brim pushed forward
				_rect(img, ox + 6, 4, 5, 4, skin)
				_rect(img, ox + 5, 4, 1, 4, hat)
				_rect(img, ox + 9, 5, 1, 1, OUTLINE)
				_rect(img, ox + 13, 3, 1, 1, brim)
			2:  # up: back of the head, suspenders
				_rect(img, ox + 5, 4, 6, 4, hat.darkened(0.25))
				_rect(img, ox + 5, 8, 1, 5, shirt.darkened(0.3))
				_rect(img, ox + 10, 8, 1, 5, shirt.darkened(0.3))
	return img


func _bed() -> Image:
	var img := _new(T, T * 2)
	_rect(img, 1, 1, 14, 30, Color("6d4628"))  # frame
	_rect(img, 2, 2, 12, 28, Color("efe6d2"))  # sheet
	_rect(img, 3, 3, 10, 6, Color("ffffff"))  # pillow
	_rect(img, 2, 12, 12, 18, Color("a33b32"))  # blanket
	_rect(img, 2, 12, 12, 2, Color("c9574b"))
	return img


func _crate() -> Image:
	var img := _new(T, T)
	_rect(img, 1, 3, 14, 12, OUTLINE)
	_rect(img, 2, 4, 12, 10, WOOD)
	_rect(img, 2, 8, 12, 1, WOOD.darkened(0.3))
	_rect(img, 7, 4, 1, 10, WOOD.darkened(0.3))
	_rect(img, 1, 2, 14, 2, WOOD.lightened(0.2))  # lid
	return img


func _tile_cursor() -> Image:
	var img := _new(T, T)
	var c := Color.WHITE
	# Corner brackets only, so the tile underneath stays readable.
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(T - 4, 0), Vector2i(0, T - 4), Vector2i(T - 4, T - 4)]:
		var top := corner.y == 0
		var left := corner.x == 0
		_rect(img, corner.x, corner.y if top else T - 1, 4, 1, c)
		_rect(img, corner.x if left else T - 1, corner.y, 1, 4, c)
	return img


# --- items -------------------------------------------------------------------

func _hoe() -> Image:
	var img := _new(T, T)
	for i: int in 11:
		_rect(img, 3 + i, 13 - i, 2, 1, Color("8a5a33"))  # handle, bottom-left to top-right
	_rect(img, 9, 1, 6, 2, METAL)  # blade
	_rect(img, 9, 3, 2, 3, METAL.darkened(0.2))
	return img


## Swung tools share one shape so the swing animation fits them all: the
## handle runs from the grip at (3, 13) up to the head at the top right.
func _handle(img: Image) -> void:
	for i: int in 11:
		_rect(img, 3 + i, 13 - i, 2, 1, Color("8a5a33"))


func _axe() -> Image:
	var img := _new(T, T)
	_handle(img)
	_rect(img, 9, 1, 5, 6, METAL)  # head
	_rect(img, 8, 2, 1, 4, METAL.lightened(0.3))  # cutting edge
	_rect(img, 9, 6, 5, 1, METAL.darkened(0.25))
	return img


func _pickaxe() -> Image:
	var img := _new(T, T)
	_handle(img)
	# The head crosses the end of the handle at a right angle.
	for i: int in 7:
		_rect(img, 8 + i, i, 2, 2, METAL)
	_rect(img, 8, 0, 1, 1, METAL.lightened(0.3))
	_rect(img, 15, 7, 1, 1, METAL.lightened(0.3))
	return img


func _scythe() -> Image:
	var img := _new(T, T)
	_handle(img)
	_rect(img, 5, 1, 9, 2, METAL)  # long blade sweeping back from the tip
	_rect(img, 3, 2, 3, 2, METAL)
	_rect(img, 2, 4, 2, 1, METAL.lightened(0.3))
	_rect(img, 5, 3, 8, 1, METAL.darkened(0.25))
	return img


func _wood() -> Image:
	var img := _new(T, T)
	var bark := Color("6d4628")
	_rect(img, 2, 5, 12, 7, OUTLINE)
	_rect(img, 3, 6, 10, 5, bark)
	_rect(img, 3, 6, 10, 1, bark.lightened(0.2))
	_rect(img, 11, 6, 2, 5, Color("c79a5e"))  # cut end
	_rect(img, 12, 8, 1, 1, bark)
	return img


func _stone() -> Image:
	var img := _new(T, T)
	_rock(img, 0, -1, false)
	return img


func _fiber() -> Image:
	var img := _new(T, T)
	var strand := Color("8f9a45")
	for x: int in [4, 6, 8, 10]:
		_rect(img, x, 2, 1, 12, strand)
		_rect(img, x + 1, 3, 1, 10, strand.darkened(0.2))
	_rect(img, 3, 7, 10, 2, Color("b08a5c"))  # tie
	return img


func _watering_can() -> Image:
	var img := _new(T, T)
	_rect(img, 4, 6, 8, 8, Color("5f86a8"))  # body
	_rect(img, 4, 6, 8, 1, Color("86a9c7"))
	_rect(img, 12, 8, 2, 1, Color("5f86a8"))  # spout
	_rect(img, 13, 6, 2, 2, Color("5f86a8"))
	_rect(img, 5, 3, 6, 1, Color("48657f"))  # handle
	_rect(img, 5, 4, 1, 2, Color("48657f"))
	_rect(img, 10, 4, 1, 2, Color("48657f"))
	return img


func _seed_packet(accent: Color) -> Image:
	var img := _new(T, T)
	_rect(img, 3, 2, 10, 12, OUTLINE)
	_rect(img, 4, 3, 8, 10, Color("e9dcb8"))
	_rect(img, 4, 3, 8, 2, accent)
	_rect(img, 6, 7, 4, 4, accent)
	return img


func _corn_item() -> Image:
	var img := _new(T, T)
	_rect(img, 6, 2, 4, 10, CORN)
	_rect(img, 7, 1, 2, 1, CORN)
	for y: int in range(3, 12, 2):
		_rect(img, 6, y, 4, 1, CORN.darkened(0.15))
	_rect(img, 4, 9, 3, 5, LEAF)  # husk
	_rect(img, 9, 9, 3, 5, LEAF)
	_rect(img, 6, 12, 4, 3, LEAF_DARK)
	return img


func _beans_item() -> Image:
	var img := _new(T, T)
	for p: Vector2i in [Vector2i(3, 4), Vector2i(8, 3), Vector2i(5, 9), Vector2i(10, 8)]:
		_rect(img, p.x, p.y, 4, 3, BEAN)
		_rect(img, p.x + 1, p.y, 2, 1, BEAN.lightened(0.3))
	return img


# --- crops -------------------------------------------------------------------

## Five 16x16 frames: seeds, sprout, young, grown, ripe.
## `bushy` draws a low wide plant (beans); otherwise a tall stalk (corn).
func _crop_strip(fruit: Color, bushy: bool) -> Image:
	var img := _new(T * 5, T)
	# Frame 0: seeds on the soil.
	for p: Vector2i in [Vector2i(4, 10), Vector2i(8, 12), Vector2i(11, 9)]:
		_rect(img, p.x, p.y, 2, 1, Color("e9dcb8"))
	# Frames 1-4: a plant that gets taller (or wider) each stage.
	for stage: int in range(1, 5):
		var ox := stage * T
		var height := 2 + stage * 3
		var half_width := (1 + stage) if bushy else 1
		if bushy:
			height = 2 + stage * 2
			_rect(img, ox + 8 - half_width, T - 1 - height, half_width * 2, height, LEAF)
			_rect(img, ox + 8 - half_width, T - 1 - height, half_width * 2, 1, LEAF.lightened(0.2))
		else:
			_rect(img, ox + 7, T - 1 - height, 2, height, LEAF_DARK)  # stalk
			for leaf_y: int in range(T - 3, T - 1 - height, -3):
				_rect(img, ox + 4, leaf_y, 3, 1, LEAF)
				_rect(img, ox + 9, leaf_y - 1, 3, 1, LEAF)
		if stage == 4:
			if bushy:
				for p: Vector2i in [Vector2i(4, 9), Vector2i(8, 7), Vector2i(11, 10), Vector2i(6, 12)]:
					_rect(img, ox + p.x, p.y, 2, 2, fruit)
			else:
				_rect(img, ox + 9, 4, 3, 5, fruit)
				_rect(img, ox + 4, 7, 3, 4, fruit)
	return img
