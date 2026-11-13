class_name BlobTiles
extends RefCounted
## Picks the right piece from a 47-tile "blob" block, the layout the Ninja
## Adventure pack uses for terrain that needs edges (tilled soil, water).
##
## A piece is identified by which of its eight neighbours are the same
## terrain, as a bitmask. A diagonal only counts when both sides next to it are
## filled too, which is what brings 256 combinations down to 47.

const N := 1
const NE := 2
const E := 4
const SE := 8
const S := 16
const SW := 32
const W := 64
const NW := 128

## Neighbour offsets in bit order, clockwise from north.
const OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

## The block as drawn in the art, row by row: the mask each cell is for.
## -1 is a cell the 47 pieces do not use.
const LAYOUT: Array[Array] = [
	[28, 124, 112, 16, 20, 116, 92, 80, 84, 221, -1],
	[31, 255, 241, 17, 23, 247, 223, 209, 215, 119, -1],
	[7, 199, 193, 1, 29, 253, 127, 113, 125, 93, 117],
	[4, 68, 64, 0, 5, 197, 71, 65, 69, 87, 213],
	[-1, -1, -1, -1, 21, 245, 95, 81, 85, -1, -1],
]
const BLOCK_SIZE := Vector2i(11, 5)

static var _lookup: Dictionary[int, Vector2i] = {}


## Where the piece for `mask` sits, relative to the block's top-left cell.
static func coords(mask: int) -> Vector2i:
	if _lookup.is_empty():
		for row: int in LAYOUT.size():
			for col: int in LAYOUT[row].size():
				var value: int = LAYOUT[row][col]
				if value >= 0:
					_lookup[value] = Vector2i(col, row)
	return _lookup[mask]


## The mask for `cell`. `is_member` takes a cell and says whether it is the
## same terrain.
static func mask_at(cell: Vector2i, is_member: Callable) -> int:
	var mask := 0
	for i: int in OFFSETS.size():
		if is_member.call(cell + OFFSETS[i]):
			mask |= 1 << i
	return without_loose_corners(mask)


## Clears diagonal bits that do not have both neighbouring sides set.
static func without_loose_corners(mask: int) -> int:
	for corner: int in 4:
		var bit := 1 << (corner * 2 + 1)
		var before := 1 << (corner * 2)
		var after := 1 << ((corner * 2 + 2) % 8)
		if not (mask & before and mask & after):
			mask &= ~bit
	return mask
