class_name PlayerWeapon
extends Node2D
## The player's gun: drawing and holstering, aiming, firing and reloading.
## The numbers come from the WeaponData in GameState.weapon.
##
## Controls: toggle_weapon draws or holsters. With the gun out, hold aim to
## raise it (the cone appears and steadies), primary_action fires, and
## holding reload feeds rounds in one at a time. Tools cannot be used while
## the gun is out.
##
## A shot is a ray, not a moving bullet: it lands the moment it is fired.
## The ray stops at the first "world" collider (walls, trees, rocks) or the
## first Hurtbox, whichever is nearer. Water and rails are on the "low"
## layer, which stops feet but not bullets.

const WORLD_LAYER := 1
const HURTBOX_LAYER := 1 << 3
## Pixel of the held sprite that sits in the hand (the grip).
const GRIP := Vector2(1.5, 2.5)
## Distance from the grip to the end of the barrel.
const BARREL := 6.0
## Where the fist is in the aiming stance, measured from the feet, for each
## way the body faces. Read off the pack's arm-thrust pose (cowboy_aim.png).
const AIM_FISTS := {
	Vector2.LEFT: Vector2(-8.0, -4.5),
	Vector2.RIGHT: Vector2(8.0, -4.5),
	Vector2.DOWN: Vector2(-2.5, -0.5),
	Vector2.UP: Vector2(-3.5, -15.5),
}
## Gun out but lowered: where the gun hand is in each of the four walk
## frames, for each way the body faces, measured from the feet. Read off
## the walk sheet (cowboy_walk.png), so the gun swings with the arm. Where
## the arm is swung back out of sight, the spot is a guess beside the hip.
const LOWERED_HANDS := {
	Vector2.DOWN: [Vector2(6.0, -2.5), Vector2(3.0, -3.0), Vector2(6.0, -2.5), Vector2(6.0, -4.0)],
	Vector2.UP: [Vector2(6.0, -3.0), Vector2(6.0, -4.0), Vector2(6.0, -3.0), Vector2(4.0, -4.0)],
	Vector2.LEFT: [Vector2(1.0, -2.5), Vector2(-4.0, -4.0), Vector2(1.0, -2.5), Vector2(2.0, -4.0)],
	Vector2.RIGHT: [Vector2(-1.0, -2.5), Vector2(4.0, -4.0), Vector2(-1.0, -2.5), Vector2(-2.0, -4.0)],
}
## The angle the barrel hangs at when lowered: down and a little forward.
const LOWERED_ANGLES := {
	Vector2.LEFT: PI - 0.7,
	Vector2.RIGHT: 0.7,
	Vector2.DOWN: PI / 2.0,
	Vector2.UP: PI / 2.0,
}
## Loading: held in front of the chest, barrel tipped up.
const LOADING_HAND := Vector2(2.0, -3.0)
## A holstered gun points at the ground; drawing swings it up from there.
const HOLSTER_ANGLE := PI / 2.0
const DRAW_SECONDS := 0.14
## Recoil: how far the barrel jumps (radians) and the gun slides back.
const RECOIL_TILT := 0.55
const RECOIL_SLIDE := 2.0
const RECOIL_SECONDS := 0.2
const BODY_KICK := 1.0
## How far the gun dips as each round is pushed home.
const LOAD_DIP := 1.5
const TRACER_SECONDS := 0.08
const SHAKE_PIXELS := 2.0
const DUST := Color(0.78, 0.66, 0.5)

## True while the gun is out of its holster.
var drawn: bool = false
## True while it is raised and the cone is showing.
var aiming: bool = false
## Current width of the aim cone, in degrees.
var spread: float = 0.0
## Where the last bullet ended up. For tests and debugging.
var last_hit_point := Vector2.ZERO
## Aim here instead of at the mouse. For tests and scripted scenes.
var aim_override: Variant = null

var _cooldown: float = 0.0
var _load_timer: float = 0.0
var _tracer_tween: Tween
var _hint_given: bool = false
# Animation amounts, each driven from 1 to 0 (or 0 to 1) by a tween.
## 0 = in the holster, 1 = fully out.
var _raise: float = 0.0
var _raise_tween: Tween
## 1 at the instant of a shot, easing back to 0.
var _recoil: float = 0.0
## 1 as a round goes in, easing back to 0.
var _load_bump: float = 0.0

@onready var _player: Player = owner
@onready var _gun: Sprite2D = $Gun
@onready var _guide: AimGuide = $AimGuide
@onready var _tracer: Line2D = $Tracer
@onready var _flash: CPUParticles2D = $MuzzleFlash
@onready var _impact: CPUParticles2D = $Impact
@onready var _smoke: CPUParticles2D = $Smoke


func _ready() -> void:
	add_to_group(&"player_weapon")
	_gun.hide()
	_tracer.hide()


func _exit_tree() -> void:
	# Leaving the area (through a door) puts the gun away.
	if drawn:
		EventBus.weapon_drawn_changed.emit(false)


func _process(delta: float) -> void:
	if not drawn:
		# Still on its way back to the holster.
		if _gun.visible:
			_pose_gun(_player.facing, false)
		return
	var weapon := GameState.weapon
	_cooldown = maxf(0.0, _cooldown - delta)
	var loading := _feed_rounds(weapon, delta)
	var was_aiming := aiming
	aiming = Input.is_action_pressed(&"aim") and not loading and not _player.busy
	if aiming and not was_aiming:
		spread = weapon.snap_spread
	_player.speed_factor = weapon.aim_walk_speed if aiming or loading else 1.0
	_player.facing_locked = aiming
	_player.aim_pose = aiming

	var direction := _aim_direction() if aiming else _player.facing
	if aiming:
		_player.face(direction)
		var settle_at := weapon.moving_spread if _player.velocity != Vector2.ZERO else weapon.steady_spread
		var rate := (weapon.snap_spread - weapon.steady_spread) / weapon.steady_seconds
		spread = move_toward(spread, settle_at, rate * delta)
		_show_cone(weapon, direction)
	else:
		_guide.hide()
	_pose_gun(direction, loading)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_weapon"):
		if GameState.weapon != null and not _player.busy:
			set_drawn(not drawn)
		get_viewport().set_input_as_handled()
	elif not drawn:
		return
	elif event.is_action_pressed(&"primary_action"):
		# A click with the gun lowered does nothing: no accidental shots.
		# Nor does one with the backpack open.
		if aiming and not GameState.backpack_open:
			fire()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"reload"):
		_explain_if_cannot_load(GameState.weapon)


func set_drawn(value: bool) -> void:
	if value == drawn:
		return
	var weapon := GameState.weapon
	drawn = value
	aiming = false
	_load_timer = 0.0
	_player.armed = drawn
	_player.speed_factor = 1.0
	_player.facing_locked = false
	_player.aim_pose = false
	_gun.texture = weapon.held_sprite
	_guide.hide()
	# Swing the gun up out of the holster, or back down into it.
	if _raise_tween != null:
		_raise_tween.kill()
	_raise_tween = create_tween()
	_raise_tween.tween_property(self, "_raise", 1.0 if drawn else 0.0, DRAW_SECONDS)
	if drawn:
		_gun.show()
		_pose_gun(_player.facing, false)
	else:
		_raise_tween.tween_callback(_gun.hide)
	Audio.play(weapon.draw_sound if drawn else weapon.holster_sound)
	EventBus.weapon_drawn_changed.emit(drawn)
	# A drawn gun is something people can see. Nobody reacts yet.
	EventBus.report(&"weapon_drawn" if drawn else &"weapon_holstered", _player, _player.global_position,
			{"weapon": weapon.id})
	if drawn and not _hint_given:
		_hint_given = true
		EventBus.toast_requested.emit("Right-click: aim.  Left-click: fire.  Hold R: reload.  Q: holster.")


## Fires along the cone. Does nothing between shots; clicks on empty.
func fire() -> void:
	var weapon := GameState.weapon
	if not drawn or _cooldown > 0.0:
		return
	if GameState.rounds_loaded <= 0:
		_cooldown = weapon.fire_interval * 0.5
		Audio.play(weapon.empty_sound)
		return
	GameState.rounds_loaded -= 1
	_cooldown = weapon.fire_interval

	# Two random numbers subtracted cluster around zero, so most shots land
	# near the middle of the cone and few at its edges.
	var stray := deg_to_rad(spread) * 0.5 * (randf() - randf())
	var direction := _aim_direction().rotated(stray)
	var from := global_position
	var hit := _cast(weapon, from, direction)
	last_hit_point = hit.point
	if hit.hurtbox != null:
		(hit.hurtbox as Hurtbox).take_shot(Shot.new(weapon, _player, hit.point, direction))
	elif hit.blocked:
		_impact.global_position = hit.point
		_impact.color = DUST
		_impact.direction = -direction
		_impact.restart()

	spread = minf(weapon.snap_spread, spread + weapon.recoil_spread)
	var muzzle := _muzzle()
	_show_tracer(muzzle, hit.point)
	_flash.global_position = muzzle
	_flash.direction = direction
	_flash.restart()
	_smoke.global_position = muzzle
	_smoke.restart()
	# The barrel jumps, the gun slides back in the hand, the body rocks.
	_recoil = 1.0
	create_tween().tween_property(self, "_recoil", 0.0, RECOIL_SECONDS).set_ease(Tween.EASE_OUT)
	_player.kick(-direction * BODY_KICK)
	_player.shake(SHAKE_PIXELS)
	Audio.play(weapon.fire_sound)
	# Gunfire is heard, not just seen. NPC hearing arrives with milestone 5.
	EventBus.report(&"gunshot", _player, from, {"weapon": weapon.id, "noise_radius": weapon.noise_radius})


## Loads one round every `seconds_per_round` while reload is held and there
## is room and ammunition. Returns true while loading is under way.
func _feed_rounds(weapon: WeaponData, delta: float) -> bool:
	var can_load := Input.is_action_pressed(&"reload") \
			and GameState.rounds_loaded < weapon.chambers \
			and GameState.inventory.count_of(weapon.ammo_item) > 0
	if not can_load:
		_load_timer = 0.0
		return false
	_load_timer += delta
	if _load_timer >= weapon.seconds_per_round:
		_load_timer = 0.0
		GameState.inventory.remove_item(weapon.ammo_item, 1)
		GameState.rounds_loaded += 1
		Audio.play(weapon.load_sound)
		_load_bump = 1.0
		create_tween().tween_property(self, "_load_bump", 0.0, weapon.seconds_per_round * 0.5)
	return true


func _explain_if_cannot_load(weapon: WeaponData) -> void:
	if GameState.rounds_loaded >= weapon.chambers:
		return
	if GameState.inventory.count_of(weapon.ammo_item) <= 0:
		EventBus.toast_requested.emit("No %s left." % weapon.ammo_item.display_name.to_lower())
		Audio.play(&"error")


## Unit vector from the hand to the mouse (or the override).
func _aim_direction() -> Vector2:
	var target: Vector2 = aim_override if aim_override != null else get_global_mouse_position()
	var offset := target - global_position
	# Too close to tell: keep looking the way we already are.
	return offset.normalized() if offset.length() > 2.0 else _player.facing


## Follows a bullet's path. Returns where it ends (`point`), the Hurtbox it
## struck if any (`hurtbox`), and whether something stopped it (`blocked`).
func _cast(weapon: WeaponData, from: Vector2, direction: Vector2) -> Dictionary:
	var end := from + direction * weapon.reach
	var query := PhysicsRayQueryParameters2D.create(from, end, WORLD_LAYER | HURTBOX_LAYER)
	query.collide_with_areas = true
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {"point": end, "hurtbox": null, "blocked": false}
	return {"point": result.position, "hurtbox": result.collider as Hurtbox, "blocked": true}


func _show_cone(weapon: WeaponData, direction: Vector2) -> void:
	var half := deg_to_rad(spread) * 0.5
	# Bullets are traced from the middle of the body, so that reaching the
	# gun past a wall cannot shoot through it. The lines are drawn from the
	# muzzle, where the eye expects them.
	var from := global_position
	var centre := _cast(weapon, from, direction)
	var left := _cast(weapon, from, direction.rotated(-half))
	var right := _cast(weapon, from, direction.rotated(half))
	_guide.show_cone(_muzzle(), centre.point, left.point, right.point, centre.hurtbox != null)


## Puts the gun in the hand. Aiming: in the fist of the thrust-out arm,
## pointing exactly along `direction`. Lowered: hanging at the side.
## Loading: at the chest, tipped up. Then the draw, the recoil and the push
## of a round going in are added on top.
func _pose_gun(direction: Vector2, loading: bool) -> void:
	var facing := _player.facing
	var hand: Vector2 = LOWERED_HANDS[facing][_player.walk_frame]
	var angle: float = LOWERED_ANGLES[facing]
	if aiming:
		hand = AIM_FISTS[facing]
		angle = direction.angle()
	elif loading:
		hand = LOADING_HAND + Vector2(0.0, LOAD_DIP * _load_bump)
		angle = -PI / 2.0 + (0.5 if facing.x >= 0.0 else -0.5)
	angle = lerp_angle(HOLSTER_ANGLE, angle, _raise)

	var along := Vector2.from_angle(angle)
	var to_the_left := along.x < 0.0
	hand -= along * RECOIL_SLIDE * _recoil
	# "Up" for the barrel is anticlockwise when it points right.
	angle += (RECOIL_TILT if to_the_left else -RECOIL_TILT) * _recoil

	_gun.rotation = angle
	_gun.flip_v = to_the_left
	# Keep the grip in the hand whichever way the picture is flipped.
	var height := _gun.texture.get_height()
	_gun.offset = Vector2(-GRIP.x, -(height - GRIP.y) if to_the_left else -GRIP.y)
	# `hand` is measured from the feet; this node sits at chest height.
	_gun.position = hand - position
	# Lowered and facing away, the gun is on the far side of the body.
	show_behind_parent = not aiming and not loading and facing == Vector2.UP


## The end of the barrel, in world coordinates.
func _muzzle() -> Vector2:
	return _gun.global_position + Vector2.from_angle(_gun.rotation) * BARREL


func _show_tracer(from: Vector2, to: Vector2) -> void:
	_tracer.points = PackedVector2Array([from, to])
	_tracer.modulate.a = 1.0
	_tracer.show()
	if _tracer_tween != null:
		_tracer_tween.kill()
	_tracer_tween = create_tween()
	_tracer_tween.tween_property(_tracer, "modulate:a", 0.0, TRACER_SECONDS)
	_tracer_tween.tween_callback(_tracer.hide)
