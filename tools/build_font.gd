extends SceneTree
## Dev tool: builds the game's pixel font from the hand-drawn glyphs in
## tools/dry_creek_font.txt, as a BMFont pair Godot imports directly:
## res://assets/fonts/dry_creek.png (the glyph sheet) and dry_creek.fnt.
##
## Godot's own font is a smooth outline font; shrunk to pixel-art sizes its
## letters lose their shapes. This one is drawn for the size it is shown at.
##
## Run from the project folder:
##   godot --headless --path . -s res://tools/build_font.gd
## then let the editor (or `godot --headless --path . --import`) import it.

const SOURCE := "res://tools/dry_creek_font.txt"
const OUT_DIR := "res://assets/fonts/"
const NAME := "dry_creek"

## Rows a glyph may use: 7 for a capital, 2 below the line.
const GLYPH_ROWS := 9
## The row the letters stand on (the first row below a capital).
const BASELINE_ROW := 7
## Blank rows above a capital, so lines of text do not touch.
const TOP_GAP := 2
const LINE_HEIGHT := TOP_GAP + GLYPH_ROWS
## Blank columns after each glyph, and the width of a space.
const LETTER_GAP := 1
const SPACE_ADVANCE := 3
## Sheet layout. Cells are bigger than any glyph so neighbours never bleed.
const CELL := Vector2i(8, 10)
const COLUMNS := 16
const FIRST := 32
const LAST := 126


func _init() -> void:
	var glyphs := _read_glyphs()
	var missing := ""
	for code: int in range(FIRST + 1, LAST + 1):
		if not glyphs.has(code):
			missing += char(code)
	if missing != "":
		push_error("Font is missing: " + missing)

	var count := LAST - FIRST + 1
	var sheet := Image.create_empty(COLUMNS * CELL.x, ceili(float(count) / COLUMNS) * CELL.y, false, Image.FORMAT_RGBA8)
	var lines: PackedStringArray = [
		'info face="Dry Creek" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0' % LINE_HEIGHT,
		"common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4" % [
			LINE_HEIGHT, TOP_GAP + BASELINE_ROW, sheet.get_width(), sheet.get_height()],
		'page id=0 file="%s.png"' % NAME,
		"chars count=%d" % count,
	]
	for code: int in range(FIRST, LAST + 1):
		var index := code - FIRST
		var origin := Vector2i(index % COLUMNS, index / COLUMNS) * CELL
		var rows: Array = glyphs.get(code, [])
		var width := 0
		for y: int in rows.size():
			var row: String = rows[y]
			width = maxi(width, row.length())
			for x: int in row.length():
				if row[x] == "#":
					sheet.set_pixel(origin.x + x, origin.y + y, Color.WHITE)
		var advance := SPACE_ADVANCE if code == FIRST else width + LETTER_GAP
		lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=%d xadvance=%d page=0 chnl=15" % [
			code, origin.x, origin.y, width, GLYPH_ROWS if width > 0 else 0, TOP_GAP, advance])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	sheet.save_png(OUT_DIR + NAME + ".png")
	var file := FileAccess.open(OUT_DIR + NAME + ".fnt", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("Wrote %d glyphs to %s%s.fnt" % [glyphs.size(), OUT_DIR, NAME])
	quit()


## Character code -> its rows, padded with blank rows above where the glyph
## starts lower down. The file's opening block of notes is skipped.
func _read_glyphs() -> Dictionary:
	var glyphs := {}
	var blocks := FileAccess.get_file_as_string(SOURCE).replace("\r", "").split("\n\n", false)
	for i: int in range(1, blocks.size()):
		var block := blocks[i].strip_edges().split("\n")
		var header := block[0]
		var code := header.unicode_at(0)
		var top := int(header.substr(1)) if header.length() > 1 else 0
		var rows: Array[String] = []
		for y: int in top:
			rows.append("")
		for y: int in range(1, block.size()):
			rows.append(block[y].strip_edges())
		if rows.size() > GLYPH_ROWS:
			push_error("Glyph '%s' has %d rows; the most is %d" % [char(code), rows.size(), GLYPH_ROWS])
		if glyphs.has(code):
			push_error("Glyph '%s' is drawn twice" % char(code))
		glyphs[code] = rows
	return glyphs
