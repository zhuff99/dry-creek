extends Node2D
## A bottle stood on a rail for target practice. One hit breaks it. Bottles
## are stood back up every morning, and whenever the farm is reloaded (they
## are not worth remembering in a save).

const GLASS := Color(0.55, 0.59, 0.5)

var broken: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var _shards: CPUParticles2D = $Shards


func _ready() -> void:
	_hurtbox.shot.connect(_on_shot)
	EventBus.day_started.connect(_on_day_started)


func _on_shot(hit: Shot) -> void:
	if broken:
		return
	broken = true
	_sprite.hide()
	# Physics shapes cannot change in the middle of a physics query.
	_shape.set_deferred(&"disabled", true)
	_shards.color = GLASS
	_shards.direction = hit.direction
	_shards.restart()
	Audio.play(&"bottle_break")


func _on_day_started(_day: int) -> void:
	broken = false
	_sprite.show()
	_shape.set_deferred(&"disabled", false)
