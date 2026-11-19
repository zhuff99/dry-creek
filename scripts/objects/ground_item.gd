class_name GroundItem
extends Node2D
## A stack of something lying on the ground. Walk over it to pick it up.
##
## It is a view of one record in GameState.ground_items, which is what
## survives the area being freed. Something just dropped waits until the
## player has stepped away before it can be picked up again, so a dropped
## stack stays put; after that it drifts to the player when they come close.

const ARM_DISTANCE := 30.0
const MAGNET_DISTANCE := 24.0
const PICKUP_DISTANCE := 6.0
const MAGNET_SPEED := 110.0
const HOP_SECONDS := 0.35
const HOP_HEIGHT := 12.0
const BOB_SPEED := 3.0
## Where the icon sits above the spot it lies on.
const REST_HEIGHT := 7.0

## The GameState record this item shows.
var record: Dictionary
## The area it lies in (its scene path), for removing the record.
var area_key: String

var _item: ItemData
var _armed: bool = false
var _hop_left: float = 0.0
var _hop_from := Vector2.ZERO
var _hop_to := Vector2.ZERO
var _time: float = 0.0
var _told_full: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _back: Sprite2D = $Back


## Call before adding it to the tree. With `from`, it first arcs from that
## point to where it lies (a throw from the player's hands).
func setup(p_record: Dictionary, p_area_key: String, from: Variant = null) -> void:
	record = p_record
	area_key = p_area_key
	if from != null:
		_hop_from = from
		_hop_left = HOP_SECONDS


func _ready() -> void:
	add_to_group(&"ground_items")
	# It lands even while the backpack has the game paused; it only waits to
	# be picked up.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_item = ItemDB.get_item(record.item)
	_hop_to = record.position
	global_position = _hop_from if _hop_left > 0.0 else _hop_to
	_time = randf() * TAU
	_sprite.texture = _item.icon
	_back.texture = _item.icon
	_back.visible = record.count > 1
	_place_sprite(0.0)


func _physics_process(delta: float) -> void:
	if _hop_left > 0.0:
		_hop(delta)
		return
	if get_tree().paused:
		return
	_time += delta
	_place_sprite(roundf(sin(_time * BOB_SPEED)))
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var distance := player.global_position.distance_to(global_position)
	if not _armed:
		_armed = distance > ARM_DISTANCE
		return
	if distance > MAGNET_DISTANCE:
		_told_full = false
		return
	if not GameState.inventory.can_fit(_item, record.count):
		if not _told_full:
			_told_full = true
			EventBus.toast_requested.emit("Your bag is full.")
		return
	if distance > PICKUP_DISTANCE:
		global_position = global_position.move_toward(player.global_position, MAGNET_SPEED * delta)
		record.position = global_position
		return
	_pick_up()


func _pick_up() -> void:
	var stack := ItemStack.new(_item, record.count)
	stack.charge = record.charge
	var left := GameState.inventory.add_stack(stack)
	var taken: int = record.count - left
	if taken <= 0:
		return
	Audio.play(&"item_pickup")
	EventBus.toast_requested.emit("+%d %s" % [taken, _item.display_name])
	if left > 0:
		record.count = left
		_back.visible = left > 1
		return
	GameState.remove_ground_item(area_key, record)
	queue_free()


func _hop(delta: float) -> void:
	_hop_left = maxf(_hop_left - delta, 0.0)
	var share := 1.0 - _hop_left / HOP_SECONDS
	global_position = _hop_from.lerp(_hop_to, share)
	_place_sprite(-sin(share * PI) * HOP_HEIGHT)
	if _hop_left <= 0.0:
		Audio.play(&"item_drop")


func _place_sprite(lift: float) -> void:
	_sprite.position = Vector2(0, -REST_HEIGHT + lift)
	_back.position = _sprite.position + Vector2(2, -2)
