extends SceneTree
## Dev tool: makes the images the pack does not have, by adjusting ones it
## does. Output goes to res://assets/derived/.
##
##   godot --headless --path . -s res://tools/build_derived_art.gd
##
## - water_on_dirt.png: the pack has blue water on sand and on grass, and
##   purple water on dirt. This is the dirt one with the two water colours
##   swapped for the blue ones, so the river sits on the ranch's ground.
## - soil_dry.png / soil_wet.png: the pack's soil is only a shade darker than
##   its dirt, which is too faint to farm by. These are the same block with the
##   two soil colours deepened, and deepened further for watered plots.
## - cabin_walls.png: the wall ring is drawn on a black backdrop meant for
##   indoor rooms, with nothing inside it. This is the ring with the backdrop
##   outside removed and the plank floor laid inside, so it can stand on dirt.

const T := 16
const BLOB_BLOCK := Vector2i(11, 5)
const PACK := "res://assets/ninja_adventure/tilesets/"
const OUT := "res://assets/derived/"

const WATER_SWAPS := {
	"a26a83ff": Color("79b8ce"),
	"bc84b5ff": Color("71ddee"),
}
const DRY_SOIL_SWAPS := {
	"90775eff": Color("7b5c42"),
	"816855ff": Color("694c36"),
}
const WET_SOIL_SWAPS := {
	"90775eff": Color("54402f"),
	"816855ff": Color("463426"),
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var water := _cut(PACK + "TilesetWater.png", Vector2i(13, 6), BLOB_BLOCK)
	_swap_colours(water, WATER_SWAPS)
	_save(water, "water_on_dirt.png")

	var dry := _cut(PACK + "TilesetFloor.png", Vector2i(11, 14), BLOB_BLOCK)
	var wet := dry.duplicate() as Image
	_swap_colours(dry, DRY_SOIL_SWAPS)
	_save(dry, "soil_dry.png")
	_swap_colours(wet, WET_SOIL_SWAPS)
	_save(wet, "soil_wet.png")

	# The orange wall ring is the 5x5 block starting at column 5.
	var walls := _cut(PACK + "TilesetWallSimple.png", Vector2i(5, 0), Vector2i(5, 5))
	_fill_empty(walls, _cut(PACK + "TilesetWater.png", Vector2i(1, 13), Vector2i.ONE))
	_clear_backdrop(walls)
	_save(walls, "cabin_walls.png")
	print("Derived art written to ", OUT)
	quit()


## Copies a block of cells out of a pack image.
func _cut(source_path: String, origin: Vector2i, cells: Vector2i) -> Image:
	var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	source.convert(Image.FORMAT_RGBA8)
	var out := Image.create_empty(cells.x * T, cells.y * T, false, Image.FORMAT_RGBA8)
	out.blit_rect(source, Rect2i(origin * T, cells * T), Vector2i.ZERO)
	return out


## Replaces exact colours. Keys are "rrggbbaa" strings.
func _swap_colours(img: Image, swaps: Dictionary) -> void:
	for y: int in img.get_height():
		for x: int in img.get_width():
			var key := img.get_pixel(x, y).to_html(true)
			if swaps.has(key):
				img.set_pixel(x, y, swaps[key])


## Paints the repeating `tile` into every fully see-through pixel.
func _fill_empty(img: Image, tile: Image) -> void:
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a == 0.0:
				img.set_pixel(x, y, tile.get_pixel(x % T, y % T))


## Makes the backdrop see-through: every pixel of the corner's colour that can
## be reached from the edge of the image without crossing another colour.
func _clear_backdrop(img: Image) -> void:
	var backdrop := img.get_pixel(0, 0)
	var size := img.get_size()
	var queue: Array[Vector2i] = []
	for x: int in size.x:
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, size.y - 1))
	for y: int in size.y:
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(size.x - 1, y))
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		if at.x < 0 or at.y < 0 or at.x >= size.x or at.y >= size.y:
			continue
		if not img.get_pixelv(at).is_equal_approx(backdrop):
			continue
		img.set_pixelv(at, Color(0, 0, 0, 0))
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			queue.append(at + step)


func _save(img: Image, file_name: String) -> void:
	var err := img.save_png(OUT + file_name)
	if err != OK:
		push_error("Could not save %s (error %d)" % [file_name, err])
