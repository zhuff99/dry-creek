extends SceneTree
## Dev tool: draws the few pieces of art the Ninja Adventure pack has no
## match for, as simple code-made placeholders in res://assets/placeholder/.
## Right now that is the corn and bean crops, their harvested items, the tile
## cursor, and the revolver (the pack has swords and bows but no guns).
##
## Run from the project folder:
##   godot --headless --path . -s res://tools/gen_placeholder_art.gd
## then let the editor (or `godot --headless --path . --import`) import the PNGs.

const T := 16
const OUT := "res://assets/placeholder/"

const CLEAR := Color(0, 0, 0, 0)
const LEAF := Color("4f9a3c")
const LEAF_DARK := Color("356f2c")
const CORN := Color("f2cf3f")
const BEAN := Color("b5562f")

# The revolver is drawn in the pack's own colours. One letter per pixel:
# O outline, M metal, S metal in shade, G grip, g grip in shade,
# B brass, b brass in shade, L lead.
const INK := {
	"O": Color("141b1b"), "M": Color("8d977f"), "S": Color("5f7160"),
	"G": Color("a3754e"), "g": Color("91522c"),
	"B": Color("f1c471"), "b": Color("d78b4a"), "L": Color("8d977f"),
	"F": Color("8f8371"), "f": Color("5e5246"), "C": Color("eecf9b"),
}
# A coyote pelt, stretched: F fur, f darker fur, C the pale belly.
const PELT_ICON: Array[String] = [
	"................",
	"..OO........OO..",
	".OFFO.OOOO.OFFO.",
	".OFFFOFFFFOFFFO.",
	"..OFFFFFFFFFFO..",
	"...OFFfFFfFFO...",
	"...OFFFCCFFFO...",
	"...OFfFCCFfFO...",
	"...OFFFCCFFFO...",
	"..OFFFfFFfFFFO..",
	".OFFFOFFFFOFFFO.",
	".OFFO.OFFO.OFFO.",
	"..OO..OFFO..OO..",
	".......OO.......",
	"................",
	"................",
]
# A hand saw: the tool for building.
const SAW_ICON: Array[String] = [
	"................",
	"................",
	"..........OOO...",
	".........OGGGO..",
	"........OGGOGGO.",
	".......OMOGOOGO.",
	"......OMMMOGGGO.",
	".....OMMMMSOGO..",
	"....OMMMMSOOO...",
	"...OMMMMSO......",
	"..OMMMMSO.......",
	".OMMMMSO........",
	".OSOSOSO........",
	"..O.O.O.........",
	"................",
	"................",
]
# Fence and gate timber, in the pack's wood colours.
const TIMBER_OUTLINE := Color("141b1b")
const TIMBER := Color("a3754e")
const TIMBER_LIGHT := Color("d78b4a")
const TIMBER_SHADE := Color("91522c")
const TIMBER_DARK := Color("61372e")
const REVOLVER_ICON: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"....OOOOOOOOOOO.",
	"...OMMMSSMMMMMMO",
	"...OMSSSSSOOOOO.",
	"..OGGSSSSO......",
	".OGGGOOSO.......",
	".OGGgO.OO.......",
	".OGggO..........",
	"OGGgO...........",
	"OGggO...........",
	".OOO............",
	"................",
	"................",
]
const ROUNDS_ICON: Array[String] = [
	"................",
	"................",
	"................",
	"..OO...OO...OO..",
	".OLLO.OLLO.OLLO.",
	".OLLO.OLLO.OLLO.",
	".OBBO.OBBO.OBBO.",
	".OBbO.OBbO.OBbO.",
	".OBbO.OBbO.OBbO.",
	".OBbO.OBbO.OBbO.",
	".OBbO.OBbO.OBbO.",
	".OBbO.OBbO.OBbO.",
	".ObbO.ObbO.ObbO.",
	".OOOO.OOOO.OOOO.",
	"................",
	"................",
]
## The gun in the hand, pointing right, grip at the bottom left. Kept small:
## the whole character is sixteen pixels.
const REVOLVER_HELD: Array[String] = [
	"..OOOOOO",
	".OMSMMMO",
	"OGSOOOO.",
	"OGO.....",
	".O......",
]


func _init() -> void:
	for sub: String in ["items", "crops", "ui", "weapons"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + sub))
	_save(_tile_cursor(), "ui/tile_cursor.png")
	_save(_corn_item(), "items/corn.png")
	_save(_beans_item(), "items/beans.png")
	_save(_crop_strip(CORN, false), "crops/corn_growth.png")
	_save(_crop_strip(BEAN, true), "crops/beans_growth.png")
	_save(_from_rows(REVOLVER_ICON), "items/revolver.png")
	_save(_from_rows(PELT_ICON), "items/coyote_pelt.png")
	_save(_from_rows(SAW_ICON), "items/saw.png")
	var fence := _fence_sheet()
	_save(fence, "built/fence.png")
	# A length joined left and right is the picture of "a fence".
	_save(fence.get_region(Rect2i(10 * T, 0, T, T)), "built/fence_icon.png")
	var gate := _gate_sheet()
	_save(gate, "built/gate.png")
	_save(gate.get_region(Rect2i(0, 0, T, T)), "built/gate_icon.png")
	_save(_from_rows(ROUNDS_ICON), "items/revolver_rounds.png")
	_save(_from_rows(REVOLVER_HELD), "weapons/revolver_held.png")
	print("Placeholder art written to ", OUT)
	quit()


func _new(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	return img


func _save(img: Image, rel_path: String) -> void:
	var err := img.save_png(OUT + rel_path)
	if err != OK:
		push_error("Could not save %s (error %d)" % [rel_path, err])


func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), color)


## Builds a picture from rows of letters, one letter per pixel (see INK).
## A dot is a see-through pixel.
func _from_rows(rows: Array[String]) -> Image:
	var img := _new(rows[0].length(), rows.size())
	for y: int in rows.size():
		for x: int in rows[y].length():
			var letter := rows[y][x]
			if letter != ".":
				img.set_pixel(x, y, INK[letter])
	return img


## Every way a length of fence can join its neighbours, as one row of 16
## tiles: the column number has bit 1 set for a neighbour to the north, 2
## east, 4 south, 8 west. A second row has the same pieces broken.
func _fence_sheet() -> Image:
	var img := _new(16 * T, 2 * T)
	for sides: int in 16:
		_fence_piece(img, sides * T, 0, sides, false)
		_fence_piece(img, sides * T, T, sides, true)
	return img


func _fence_piece(img: Image, ox: int, oy: int, sides: int, broken: bool) -> void:
	# Rails first, so the post stands in front of them.
	if sides & 2:
		_fence_rails(img, ox + 10, oy, ox + 12, broken)
	if sides & 8:
		_fence_rails(img, ox, oy, ox + 2, broken)
	# A run going away up or down the screen: a plank from post to post.
	for top: int in [0 if sides & 1 else -1, 14 if sides & 4 else -1]:
		if top >= 0 and not broken:
			_rect(img, ox + 6, oy + top, 4, 2, TIMBER_OUTLINE)
			_rect(img, ox + 7, oy + top, 2, 2, TIMBER_SHADE)
	_rect(img, ox + 5, oy + 1, 6, 14, TIMBER_OUTLINE)
	_rect(img, ox + 6, oy + 2, 4, 12, TIMBER)
	_rect(img, ox + 6, oy + 2, 1, 12, TIMBER_LIGHT)
	_rect(img, ox + 9, oy + 2, 1, 12, TIMBER_SHADE)
	_rect(img, ox + 6, oy + 2, 4, 1, TIMBER_LIGHT)
	if broken:
		_rect(img, ox + 7, oy + 5, 1, 3, TIMBER_DARK)
		_rect(img, ox + 8, oy + 7, 1, 3, TIMBER_DARK)


## Two rails across the six pixels from `x`. A broken piece has its top rail
## snapped at `gap_x`.
func _fence_rails(img: Image, x: int, oy: int, gap_x: int, broken: bool) -> void:
	for top: int in [4, 8]:
		_rect(img, x, oy + top, 6, 4, TIMBER_OUTLINE)
		_rect(img, x, oy + top + 1, 6, 1, TIMBER_LIGHT)
		_rect(img, x, oy + top + 2, 6, 1, TIMBER_SHADE)
	if broken:
		_rect(img, gap_x, oy + 4, 2, 4, CLEAR)


## The gate, hung across the way (frame 0) and along it (frame 1). Paler
## than the fence, with a brace, so it reads as the way through.
func _gate_sheet() -> Image:
	var img := _new(2 * T, T)
	for x: int in [0, 12]:
		_rect(img, x, 1, 4, 14, TIMBER_OUTLINE)
		_rect(img, x + 1, 2, 2, 12, TIMBER)
		_rect(img, x + 1, 2, 2, 1, TIMBER_LIGHT)
	for top: int in [4, 9]:
		_rect(img, 4, top, 8, 3, TIMBER_OUTLINE)
		_rect(img, 4, top + 1, 8, 1, TIMBER_LIGHT)
	for step: int in 8:
		img.set_pixel(4 + step, 9 - step * 4 / 7, TIMBER_DARK)
	_rect(img, T + 5, 0, 6, 16, TIMBER_OUTLINE)
	_rect(img, T + 6, 0, 4, 16, TIMBER_LIGHT)
	_rect(img, T + 9, 0, 1, 16, TIMBER)
	for y: int in [3, 12]:
		_rect(img, T + 6, y, 4, 1, TIMBER_DARK)
	return img


func _tile_cursor() -> Image:
	var img := _new(T, T)
	# Corner brackets only, so the tile underneath stays readable.
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(T - 4, 0), Vector2i(0, T - 4), Vector2i(T - 4, T - 4)]:
		var top := corner.y == 0
		var left := corner.x == 0
		_rect(img, corner.x, corner.y if top else T - 1, 4, 1, Color.WHITE)
		_rect(img, corner.x if left else T - 1, corner.y, 1, 4, Color.WHITE)
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
