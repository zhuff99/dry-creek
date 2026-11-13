class_name SpawnPoint
extends Marker2D
## A named place in an area where the player can arrive. Lives under the
## area's `Spawns` node; the node's name is what doors refer to.

## Which way the player looks on arriving.
@export var facing := Vector2.DOWN
