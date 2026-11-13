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
## Walking speed while aiming or reloading, as a share of normal.
const SLOW_FACTOR := 0.45
## Pixel of the held sprite that sits in the hand (the grip).
const GRIP := Vector2(1.5, 3.5)
## How far from the hand the gun is held out when raised.
const RAISED_REACH := 4.0
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

@onready var _player: Player = owner
@onready var _gun: Sprite2D = $Gun
@onready var _guide: AimGuide = $AimGuide
@onready var _tracer: Line2D = $Tracer
@onready var _flash: CPUParticles2D = $MuzzleFlash
@onready var _impact: CPUParticles2D = $Impact


func _ready() -> void:
	_gun.hide()
	_tracer.hide()


func _exit_tree() -> void:
	# Leaving the area (through a door) puts the gun away.
	if drawn:
		EventBus.weapon_drawn_changed.emit(false)


func _process(delta: float) -> void:
	if not drawn:
		return
	var weapon := GameState.weapon
	_cooldown = maxf(0.0, _cooldown - delta)
	var loading := _feed_rounds(weapon, delta)
	var was_aiming := aiming
	aiming = Input.is_action_pressed(&"aim") and not loading and not _player.busy
	if aiming and not was_aiming:
		spread = weapon.snap_spread
	_player.speed_factor = SLOW_FACTOR if aiming or loading else 1.0
	_player.facing_locked = aiming

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
		if aiming:
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
	_gun.texture = weapon.held_sprite
	_gun.visible = drawn
	_guide.hide()
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
	_show_tracer(from + direction * 6.0, hit.point)
	_flash.position = direction * 8.0
	_flash.direction = direction
	_flash.restart()
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
	var from := global_position
	var centre := _cast(weapon, from, direction)
	var left := _cast(weapon, from, direction.rotated(-half))
	var right := _cast(weapon, from, direction.rotated(half))
	_guide.show_cone(from, centre.point, left.point, right.point, centre.hurtbox != null)


## Holds the gun out along `direction` when raised, close to the body when
## lowered, and tipped up while loading.
func _pose_gun(direction: Vector2, loading: bool) -> void:
	var angle := direction.angle()
	if loading:
		angle = -PI / 2.0 + (0.5 if direction.x >= 0.0 else -0.5)
	var to_the_left := absf(angle) > PI / 2.0
	_gun.rotation = angle
	_gun.flip_v = to_the_left
	# Keep the grip in the hand whichever way the picture is flipped.
	var height := _gun.texture.get_height()
	_gun.offset = Vector2(-GRIP.x, -(height - GRIP.y) if to_the_left else -GRIP.y)
	_gun.position = direction * (RAISED_REACH if aiming else 1.0)
	# Pointing up the screen, the gun is on the far side of the body.
	show_behind_parent = direction.y < -0.5


func _show_tracer(from: Vector2, to: Vector2) -> void:
	_tracer.points = PackedVector2Array([from, to])
	_tracer.modulate.a = 1.0
	_tracer.show()
	if _tracer_tween != null:
		_tracer_tween.kill()
	_tracer_tween = create_tween()
	_tracer_tween.tween_property(_tracer, "modulate:a", 0.0, TRACER_SECONDS)
	_tracer_tween.tween_callback(_tracer.hide)
