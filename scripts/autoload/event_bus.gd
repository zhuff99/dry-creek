extends Node
## Global signal hub (autoload "EventBus").
##
## Systems talk through here instead of holding references to each other, so
## scenes stay swappable. Signals are emitted from other scripts, which is why
## each one carries an unused_signal ignore.

# --- Time ---
## Fired just before the day counter increments. Overnight simulation hooks in here.
@warning_ignore("unused_signal")
signal day_ended(day: int)
@warning_ignore("unused_signal")
signal day_started(day: int)
## The player asked to sleep (bed). The day transition UI runs the rollover.
@warning_ignore("unused_signal")
signal sleep_requested
## The clock moved on a step. `minutes` counts from midnight, and past 24:00
## in the small hours (see GameClock).
@warning_ignore("unused_signal")
signal time_changed(minutes: int)

# --- Economy ---
@warning_ignore("unused_signal")
signal money_changed(amount: int)
## Overnight shipping crate payout. Emitted every night, total may be 0.
@warning_ignore("unused_signal")
signal shipment_paid(total: int)

# --- UI ---
@warning_ignore("unused_signal")
signal hotbar_slot_selected(index: int)
## Empty string means "nothing to interact with".
@warning_ignore("unused_signal")
signal interaction_prompt_changed(text: String)
@warning_ignore("unused_signal")
signal toast_requested(text: String)

# --- Health ---
@warning_ignore("unused_signal")
signal health_changed(health: int, max_health: int)
## The player dropped: health ran out (`cause` is &"hurt") or they stayed up
## until the day ran out (&"late"). The night passes, they wake at home, and
## `money_lost` has already been taken.
@warning_ignore("unused_signal")
signal player_passed_out(money_lost: int, cause: StringName)

# --- The cabin ---
## Coyotes tore at the cabin, or the player mended it.
@warning_ignore("unused_signal")
signal cabin_damage_changed(damage: int)

# --- Building ---
## The saw was set to build something else (GameState.blueprint()).
@warning_ignore("unused_signal")
signal blueprint_changed

# --- Stamina ---
## `ceiling` is how far it can refill today; `max_stamina` is a rested day's.
@warning_ignore("unused_signal")
signal stamina_changed(stamina: float, ceiling: float, max_stamina: float)
## The player tried to work without the stamina for it.
@warning_ignore("unused_signal")
signal stamina_lacking

# --- Weapons ---
## The player's gun came out of, or went back into, its holster.
@warning_ignore("unused_signal")
signal weapon_drawn_changed(drawn: bool)
## Rounds in the gun changed (a shot, or a round loaded).
@warning_ignore("unused_signal")
signal rounds_changed(loaded: int)

# --- World ---
## A door was used: show the area in `scene_path`, with the player on its
## spawn point named `spawn`. The World node does the swap.
@warning_ignore("unused_signal")
signal area_change_requested(scene_path: String, spawn: StringName)
## Something happened in the world that an NPC could perceive.
## M1 only reports farm events; crimes, gunfire and drawn weapons arrive with
## combat (M4) and witnesses subscribe in M5.
signal world_event(event: WorldEvent)


## Convenience wrapper so callers do not build WorldEvent objects by hand.
func report(type: StringName, actor: Node, position: Vector2, data: Dictionary = {}) -> void:
	world_event.emit(WorldEvent.new(type, actor, position, data))
