class_name PlayerToolAnimator
extends Node2D
## Plays the player's tool-use animations.
##
## Placeholder implementation: it swings the tool's own inventory icon with
## tweens. When real character sheets arrive, this is the one script to replace.
## Callers only use play(), which reports the moment the tool lands.

const SWING_WINDUP := 0.14
const SWING_STRIKE := 0.07
const SWING_RECOVER := 0.16
const POUR_TILT := 0.12
const POUR_HOLD := 0.36
const POUR_RETURN := 0.1
const DIP_DOWN := 0.14
const DIP_HOLD := 0.22
const DIP_UP := 0.14

## Where the hand is, relative to the player's feet.
const HAND := Vector2(0, -7)
## Item icons are drawn pointing up and to the right.
const ICON_ANGLE := -PI / 4.0
## Pixel of a swung icon that sits in the hand (the bottom of the handle).
const GRIP_PIXEL := Vector2(2, 14)
## Default colour of the burst thrown up when a swing lands.
const DIRT_COLOR := Color(0.42, 0.28, 0.17)
## How far the body leans into a strike.
const LUNGE_PIXELS := 2.0
## How far from the hand the watering can is held out.
const CAN_REACH := 10.0

## The character sprite, nudged forward on a strike.
@export var body: Sprite2D

@onready var _held: Sprite2D = $HeldTool
@onready var _drops: CPUParticles2D = $WaterDrops
@onready var _dirt: CPUParticles2D = $DirtBurst


func _ready() -> void:
	_held.hide()


## Plays one tool use and returns when it is over (await it).
## `direction` points from the player to the tile, `target` is the tile centre,
## `on_impact` is called at the moment the tool takes effect, and `chips` is
## the colour of what a swing knocks loose.
func play(
	kind: ToolData.UseAnimation,
	icon: Texture2D,
	direction: Vector2,
	target: Vector2,
	on_impact: Callable,
	chips: Color = DIRT_COLOR,
) -> void:
	_held.texture = icon
	show_behind_parent = false
	var tween: Tween
	match kind:
		ToolData.UseAnimation.POUR:
			tween = _pour(direction, on_impact)
		ToolData.UseAnimation.DIP:
			tween = _dip(direction, on_impact)
		_:
			# Chopping at a tile above: the tool passes behind the character.
			show_behind_parent = direction.y < -0.5
			tween = _swing(direction, target, on_impact, chips)
	_held.show()
	await tween.finished
	_held.hide()


## Overhead chop: raise the tool back, bring it down on the tile.
func _swing(direction: Vector2, target: Vector2, on_impact: Callable, chips: Color) -> Tween:
	_held.centered = false
	_held.offset = -GRIP_PIXEL
	_held.flip_h = false
	_held.position = HAND
	# Rotation at which the icon points straight along `direction`.
	var aim := direction.angle() - ICON_ANGLE
	# "Back" is anticlockwise when working to the right, clockwise to the left.
	var side := -1.0 if direction.x < 0.0 else 1.0
	_held.rotation = aim - side * 0.6
	var body_home := body.position

	var tween := create_tween()
	tween.tween_property(_held, "rotation", aim - side * 1.5, SWING_WINDUP) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_held, "rotation", aim + side * 0.5, SWING_STRIKE) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(body, "position", body_home + direction * LUNGE_PIXELS, SWING_STRIKE)
	tween.tween_callback(on_impact)
	tween.tween_callback(_burst.bind(target, chips))
	tween.tween_property(body, "position", body_home, SWING_RECOVER)
	return tween


## Hold the can out over the tile, tip it, let water fall, stand it back up.
func _pour(direction: Vector2, on_impact: Callable) -> Tween:
	# The can icon has its spout on the right, so mirror it when working left.
	var side := -1.0 if direction.x < 0.0 else 1.0
	_held.centered = true
	_held.offset = Vector2.ZERO
	_held.flip_h = side < 0.0
	_held.position = HAND + direction * CAN_REACH
	_held.rotation = 0.0
	_drops.position = _held.position + Vector2(side * 7.0, 2.0)

	var tween := create_tween()
	tween.tween_property(_held, "rotation", side * 0.7, POUR_TILT)
	tween.tween_callback(_drops.set_emitting.bind(true))
	tween.tween_interval(POUR_HOLD / 2.0)
	tween.tween_callback(on_impact)
	tween.tween_interval(POUR_HOLD / 2.0)
	tween.tween_callback(_drops.set_emitting.bind(false))
	tween.tween_property(_held, "rotation", 0.0, POUR_RETURN)
	return tween


## Filling up: reach out over the water, dunk the can, lift it back.
func _dip(direction: Vector2, on_impact: Callable) -> Tween:
	var side := -1.0 if direction.x < 0.0 else 1.0
	_held.centered = true
	_held.offset = Vector2.ZERO
	_held.flip_h = side < 0.0
	_held.rotation = 0.0
	var reach := HAND + direction * CAN_REACH
	var dunked := reach + direction * 4.0 + Vector2(0, 3)
	_held.position = reach
	_drops.position = dunked

	var tween := create_tween()
	tween.tween_property(_held, "position", dunked, DIP_DOWN)
	# Tip the opening into the current.
	tween.parallel().tween_property(_held, "rotation", -side * 0.6, DIP_DOWN)
	tween.tween_callback(_drops.set_emitting.bind(true))
	tween.tween_interval(DIP_HOLD)
	tween.tween_callback(_drops.set_emitting.bind(false))
	tween.tween_callback(on_impact)
	tween.tween_property(_held, "position", reach, DIP_UP)
	tween.parallel().tween_property(_held, "rotation", 0.0, DIP_UP)
	return tween


func _burst(at: Vector2, color: Color) -> void:
	_dirt.global_position = at
	_dirt.color = color
	_dirt.restart()
