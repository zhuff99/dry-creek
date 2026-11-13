class_name FarmTiles
extends RefCounted
## Where things live in the farm TileSet: source ids and the atlas coordinates
## the code needs to know about. tools/gen_farm_map.gd builds the TileSet from
## these, and FarmGrid uses them to draw tilled and watered soil.

# One atlas source per image.
const SRC_FLOOR := 0  # TilesetFloor.png: bare ground
const SRC_WATER := 1  # derived/water_on_dirt.png: the river
const SRC_WET_SOIL := 2  # derived/soil_wet.png: watered soil
const SRC_NATURE := 3  # TilesetNature.png: trees, rocks, plants
const SRC_CAMP := 4  # tileset_camp.png: woodpile, hay, barrel, lantern
const SRC_ELEMENT := 5  # TilesetElement.png: hitching rail, clothesline, scarecrow
const SRC_DETAIL := 6  # TilesetFloorDetail.png: pebbles, twigs, bones
const SRC_RIPPLE := 7  # WaterRipples.png: animated ripple
const SRC_SOIL := 8  # derived/soil_dry.png: tilled soil
const SRC_ROAD := 9  # derived/road.png: the wagon road

# The river, the road and both soil images hold exactly one blob block, so a piece's
# atlas coordinates are what BlobTiles.coords() returns.

## Bare dirt: one plain tile and four with faint marks.
const GROUND: Array[Vector2i] = [
	Vector2i(11, 19), Vector2i(12, 19), Vector2i(13, 19), Vector2i(14, 19), Vector2i(15, 19),
]
