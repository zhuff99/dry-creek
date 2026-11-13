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
## - cowboy_walk.png: the pack has no cowboy. Its "Inspector" already wears a
##   wide-brimmed hat, a neckerchief and a long coat, so this is him with the
##   white fedora turned into a tan hat with a dark band and the trench coat
##   into a blue work shirt.
## - log_cabin.png: the pack's buildings are Japanese houses. The homestead
##   cabin is drawn from scratch in the pack's colours by cabin_painter.gd.

const CabinPainter := preload("res://tools/cabin_painter.gd")

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

const INSPECTOR_WALK := "res://assets/ninja_adventure/characters/inspector/Walk.png"
## The hat is the top eight rows of the figure in every frame.
const HAT_ROWS := 8
const HAT_SWAPS := {
	"f2eaf1ff": Color("e0b877"),  # white felt -> tan
	"abc2bcff": Color("b98b55"),  # its shading
	"a3754eff": Color("5a3a2a"),  # hat band
}
const CLOTHES_SWAPS := {
	"a3754eff": Color("5b7186"),  # brown coat -> blue shirt
	"91522cff": Color("465a6e"),  # its shading
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

	_save(_cowboy(), "cowboy_walk.png")
	_save(CabinPainter.paint(), "log_cabin.png")
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


## The Inspector's walk sheet in ranch clothes. The hat and the coat share a
## brown, so which swap applies depends on whether a pixel is in the hat.
func _cowboy() -> Image:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(INSPECTOR_WALK))
	sheet.convert(Image.FORMAT_RGBA8)
	for frame_y: int in sheet.get_height() / T:
		for frame_x: int in sheet.get_width() / T:
			var frame := Rect2i(frame_x * T, frame_y * T, T, T)
			# The figure bobs a pixel as it walks, so find where its hat starts.
			var top := 0
			while top < T and _row_is_empty(sheet, frame, top):
				top += 1
			for y: int in T:
				var swaps: Dictionary = HAT_SWAPS if y < top + HAT_ROWS else CLOTHES_SWAPS
				for x: int in T:
					var at := frame.position + Vector2i(x, y)
					var key := sheet.get_pixelv(at).to_html(true)
					if swaps.has(key):
						sheet.set_pixelv(at, swaps[key])
	return sheet


func _row_is_empty(img: Image, frame: Rect2i, y: int) -> bool:
	for x: int in frame.size.x:
		if img.get_pixel(frame.position.x + x, frame.position.y + y).a > 0.0:
			return false
	return true


func _save(img: Image, file_name: String) -> void:
	var err := img.save_png(OUT + file_name)
	if err != OK:
		push_error("Could not save %s (error %d)" % [file_name, err])
