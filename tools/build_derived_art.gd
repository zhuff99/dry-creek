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
##   neckerchief and a long coat, so this is him with the trench coat turned
##   into a blue work shirt and his white fedora replaced, pixel for pixel,
##   by a brown cowboy hat: creased crown, brim curling up at the sides.
## - road.png: the pack's patch-of-darker-dirt tiles in the paler colour of a
##   packed wagon road, for the track from the cabin to the river and away.
## - cowboy_aim.png: the same change made to his "attack" pose, one frame
##   per direction with the arm thrust out. It is the stance for aiming a gun.
## - rattlesnake.png: the pack's green snake in a rattler's sandy browns,
##   with a pale tail tip for the rattle.
## - coyote.png: the pack's white dog (sitting and running) in a coyote's
##   grey-buff coat, its collar turned into a pale throat.
## - log_cabin.png: the pack's buildings are Japanese houses. The homestead
##   cabin is drawn from scratch in the pack's colours by cabin_painter.gd.
## - cabin_room.png: the inside of that cabin (log walls, board floor, stone
##   fireplace), drawn the same way by cabin_room_painter.gd.
## - cabin_furniture.png: the pack's table, chair, stool, trunk, shelf and
##   dresser with their bright orange paint swapped for plain wood.

const CabinPainter := preload("res://tools/cabin_painter.gd")
const RoomPainter := preload("res://tools/cabin_room_painter.gd")

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

const SNAKE := "res://assets/ninja_adventure/characters/Snake3.png"
const RATTLER_SWAPS := {
	"adbc3aff": Color("d2b37d"),  # light green -> sand
	"74a334ff": Color("a3754e"),  # green -> brown
	"56864cff": Color("eecf9b"),  # dark tail -> pale rattle
	"ffad5dff": Color("f1c471"),  # belly
}

const DOG := "res://assets/ninja_adventure/characters/DogWhite.png"
const COYOTE_SWAPS := {
	"f2eaf1ff": Color("8f8371"),  # white coat -> grey-buff
	"9ba7aaff": Color("5e5246"),  # grey tail and ears -> dark
	"ef914fff": Color("eecf9b"),  # collar -> pale throat
	"f1c471ff": Color("d2b37d"),
}

## Painted furniture to bare wood.
const RUSTIC_SWAPS := {
	"e46d3aff": Color("a3754e"),
	"ffad5dff": Color("d78b4a"),
	"ffcba9ff": Color("f1c471"),
	"f2ad7dff": Color("d78b4a"),
}
## Furniture taken from TilesetElement.png: where each piece is there, how
## many cells it covers, and where it goes on the new sheet.
const FURNITURE: Array[Dictionary] = [
	{"from": Vector2i(3, 9), "cells": Vector2i(1, 1), "to": Vector2i(0, 0)},  # table
	{"from": Vector2i(0, 9), "cells": Vector2i(1, 1), "to": Vector2i(1, 0)},  # chair
	{"from": Vector2i(9, 1), "cells": Vector2i(1, 1), "to": Vector2i(2, 0)},  # stool
	{"from": Vector2i(3, 1), "cells": Vector2i(1, 1), "to": Vector2i(3, 0)},  # trunk
	{"from": Vector2i(4, 7), "cells": Vector2i(1, 2), "to": Vector2i(0, 1)},  # shelf
	{"from": Vector2i(6, 7), "cells": Vector2i(2, 2), "to": Vector2i(1, 1)},  # dresser
]
const FURNITURE_SHEET := Vector2i(4, 3)

const INSPECTOR := "res://assets/ninja_adventure/characters/inspector/"
const HAT_WHITE := "f2eaf1ff"
## The hat, drawn over the fedora in every frame. One letter per pixel:
## O outline, H felt, S felt in shade, B band, and a dot for nothing.
const COWBOY_HAT: Array[String] = [
	"....OOO..OOO....",
	"...OHHHOOHHHO...",
	"...OSHHHHHHSO...",
	"OO.OBBBBBBBBO.OO",
	"OHOOSHHHHHHSOOHO",
	"OHHHHHHHHHHHHHHO",
	".OSHHHHHHHHHHSO.",
	"..OSSSSSSSSSSO..",
]
const HAT_INK := {
	"O": Color("141b1b"), "H": Color("9b6a45"), "S": Color("7a4e34"), "B": Color("3b2a22"),
}
const ROAD_SWAPS := {
	"90775eff": Color("c7aa90"),  # the patch itself: paler than the ground
	"816855ff": Color("b3957f"),  # its marks, as wheel ruts
	"8e7c73ff": Color("a28672"),  # the edge
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
	var road := dry.duplicate() as Image
	_swap_colours(road, ROAD_SWAPS)
	_save(road, "road.png")
	_swap_colours(dry, DRY_SOIL_SWAPS)
	_save(dry, "soil_dry.png")
	_swap_colours(wet, WET_SOIL_SWAPS)
	_save(wet, "soil_wet.png")

	_save(_cowboy(INSPECTOR + "Walk.png"), "cowboy_walk.png")
	_save(_cowboy(INSPECTOR + "Attack.png"), "cowboy_aim.png")
	var snake := _cut(SNAKE, Vector2i.ZERO, Vector2i(4, 4))
	_swap_colours(snake, RATTLER_SWAPS)
	_save(snake, "rattlesnake.png")
	var coyote := Image.load_from_file(ProjectSettings.globalize_path(DOG))
	coyote.convert(Image.FORMAT_RGBA8)
	_swap_colours(coyote, COYOTE_SWAPS)
	_save(coyote, "coyote.png")
	_save(CabinPainter.paint(), "log_cabin.png")
	_save(RoomPainter.paint(), "cabin_room.png")
	_save(_furniture(), "cabin_furniture.png")
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


func _furniture() -> Image:
	var sheet := Image.create_empty(FURNITURE_SHEET.x * T, FURNITURE_SHEET.y * T, false, Image.FORMAT_RGBA8)
	for piece: Dictionary in FURNITURE:
		var cut := _cut(PACK + "TilesetElement.png", piece.from, piece.cells)
		_swap_colours(cut, RUSTIC_SWAPS)
		sheet.blit_rect(cut, Rect2i(Vector2i.ZERO, cut.get_size()), piece.to * T)
	return sheet


## One of the Inspector's sheets in ranch clothes: the fedora's rows are
## replaced by the cowboy hat and the coat's browns become the shirt's blues.
func _cowboy(sheet_path: String) -> Image:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(sheet_path))
	sheet.convert(Image.FORMAT_RGBA8)
	for frame_y: int in sheet.get_height() / T:
		for frame_x: int in sheet.get_width() / T:
			var frame := Rect2i(frame_x * T, frame_y * T, T, T)
			# The figure bobs a pixel as it walks, and in one pose a hand is
			# raised above the hat, so find the hat by its white: the outline
			# is the row above the first white one.
			var top := 0
			while top < T - 1 and not _row_has(sheet, frame, top + 1, HAT_WHITE):
				top += 1
			for y: int in T:
				var hat_row := y - top
				for x: int in T:
					var at := frame.position + Vector2i(x, y)
					if hat_row >= 0 and hat_row < COWBOY_HAT.size():
						var letter := COWBOY_HAT[hat_row][x]
						sheet.set_pixelv(at, HAT_INK[letter] if letter != "." else Color(0, 0, 0, 0))
						continue
					var key := sheet.get_pixelv(at).to_html(true)
					if CLOTHES_SWAPS.has(key):
						sheet.set_pixelv(at, CLOTHES_SWAPS[key])
	return sheet


func _row_has(img: Image, frame: Rect2i, y: int, colour: String) -> bool:
	for x: int in frame.size.x:
		if img.get_pixel(frame.position.x + x, frame.position.y + y).to_html(true) == colour:
			return true
	return false


func _save(img: Image, file_name: String) -> void:
	var err := img.save_png(OUT + file_name)
	if err != OK:
		push_error("Could not save %s (error %d)" % [file_name, err])
