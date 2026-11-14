extends PanelContainer
## Development panel: a slider for each of the gun's handling numbers, so
## shooting can be tuned while playing. The toggle_tuning key opens it.
##
## The game keeps running underneath. Changes take effect at once but last
## only until the game closes, unless Save is pressed, which writes them to
## the weapon's resource file. Only present in debug builds (the editor).
##
## The sliders are made from the weapon's own exported ranges, so a number
## added to WeaponData shows up here without touching this script.

## Exported ranges that are not about how the gun handles.
const SKIPPED: Array[StringName] = [&"max_stack", &"damage", &"noise_radius"]
const NAME_WIDTH := 90
const SLIDER_WIDTH := 60
const VALUE_WIDTH := 24
## The engine's own slider knob is 16 pixels tall, a lot on a 270-pixel
## screen, so the sliders get a small one.
const KNOB_SIZE := Vector2i(4, 8)
const KNOB_COLOUR := Color("eecf9b")
const TRACK_COLOUR := Color(0, 0, 0, 0.45)
const FILL_COLOUR := Color("a3754e")
const SPARE_ROUNDS := 24

var _weapon: WeaponData
## Property name -> value when the panel was built, for Reset.
var _original: Dictionary[StringName, float] = {}
var _sliders: Dictionary[StringName, HSlider] = {}
var _value_labels: Dictionary[StringName, Label] = {}
var _cone_label: Label
var _save_button: Button
var _knob: Texture2D
var _track: StyleBoxFlat
var _fill: StyleBoxFlat


func _ready() -> void:
	hide()
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_input(false)
		return
	_weapon = GameState.weapon
	if _weapon != null:
		_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_tuning") and _weapon != null:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	var gun := get_tree().get_first_node_in_group(&"player_weapon") as PlayerWeapon
	if gun == null or not gun.drawn:
		_cone_label.text = "Cone now: (gun holstered)"
	elif not gun.aiming:
		_cone_label.text = "Cone now: (not aiming)"
	else:
		_cone_label.text = "Cone now: %.1f degrees" % gun.spread


## Current value of one of the weapon's numbers. For tests.
func slider_for(property: StringName) -> HSlider:
	return _sliders.get(property)


func _build() -> void:
	var knob_image := Image.create_empty(KNOB_SIZE.x, KNOB_SIZE.y, false, Image.FORMAT_RGBA8)
	knob_image.fill(KNOB_COLOUR)
	_knob = ImageTexture.create_from_image(knob_image)
	_track = StyleBoxFlat.new()
	_track.bg_color = TRACK_COLOUR
	_track.content_margin_top = 1.0
	_track.content_margin_bottom = 1.0
	_fill = StyleBoxFlat.new()
	_fill.bg_color = FILL_COLOUR

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	add_child(box)
	var title := Label.new()
	title.text = "%s tuning  (F3 hides)" % _weapon.display_name
	box.add_child(title)
	for property: Dictionary in _weapon.get_property_list():
		if _is_tunable(property):
			box.add_child(_make_row(property))
	_cone_label = Label.new()
	box.add_child(_cone_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 2)
	box.add_child(buttons)
	_save_button = _add_button(buttons, "Save", _save)
	_add_button(buttons, "Reset", _reset)
	_add_button(buttons, "+%d rounds" % SPARE_ROUNDS, _give_rounds)
	_add_button(buttons, "Bottles", _stand_bottles_up)
	# Nothing in the world hurts the player yet, so these stand in for it.
	var health_buttons := HBoxContainer.new()
	health_buttons.add_theme_constant_override(&"separation", 2)
	box.add_child(health_buttons)
	_add_button(health_buttons, "Hurt 2", _hurt_player)
	_add_button(health_buttons, "Heal", func() -> void: GameState.heal(GameState.max_health))
	_add_button(health_buttons, "Tire 25", func() -> void: GameState.exert(25.0))
	_add_button(health_buttons, "Rest", GameState.rest_fully)
	_add_button(health_buttons, "+1 hour", func() -> void: GameClock.minutes += 60.0)


## Exported whole or decimal numbers that were given a range.
func _is_tunable(property: Dictionary) -> bool:
	return property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 \
			and property.usage & PROPERTY_USAGE_EDITOR != 0 \
			and property.hint == PROPERTY_HINT_RANGE \
			and property.type in [TYPE_FLOAT, TYPE_INT] \
			and not SKIPPED.has(StringName(property.name))


func _make_row(property: Dictionary) -> HBoxContainer:
	var id := StringName(property.name)
	# The range is written "min,max,step" (step may be missing).
	var parts: PackedStringArray = property.hint_string.split(",")
	var step := float(parts[2]) if parts.size() > 2 and parts[2].is_valid_float() else 1.0
	_original[id] = float(_weapon.get(id))

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 3)
	var name_label := Label.new()
	name_label.text = String(id).capitalize()
	name_label.custom_minimum_size.x = NAME_WIDTH
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = float(parts[0])
	slider.max_value = float(parts[1])
	slider.step = step
	slider.value = _original[id]
	slider.custom_minimum_size.x = SLIDER_WIDTH
	slider.add_theme_icon_override(&"grabber", _knob)
	slider.add_theme_icon_override(&"grabber_highlight", _knob)
	slider.add_theme_stylebox_override(&"slider", _track)
	slider.add_theme_stylebox_override(&"grabber_area", _fill)
	slider.add_theme_stylebox_override(&"grabber_area_highlight", _fill)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Keep the keyboard for the game: arrow keys would otherwise nudge it.
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = VALUE_WIDTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	_sliders[id] = slider
	_value_labels[id] = value_label
	_show_value(id, slider.value)
	slider.value_changed.connect(_on_slider_changed.bind(id))
	return row


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _on_slider_changed(value: float, id: StringName) -> void:
	_weapon.set(id, value)
	_show_value(id, value)
	# A smaller cylinder cannot hold what was in the bigger one.
	if id == &"chambers":
		GameState.rounds_loaded = mini(GameState.rounds_loaded, _weapon.chambers)
	_mark_unsaved()


func _show_value(id: StringName, value: float) -> void:
	var whole := _sliders[id].step >= 1.0
	_value_labels[id].text = str(int(value)) if whole else "%.2f" % value


## The Save button carries a star while the sliders differ from the file.
func _mark_unsaved() -> void:
	var changed := false
	for id: StringName in _sliders:
		if not is_equal_approx(_sliders[id].value, _original[id]):
			changed = true
	_save_button.text = "Save*" if changed else "Save"


func _save() -> void:
	var err := ResourceSaver.save(_weapon, _weapon.resource_path)
	if err == OK:
		for id: StringName in _sliders:
			_original[id] = _sliders[id].value
		_mark_unsaved()
		EventBus.toast_requested.emit("Saved to %s" % _weapon.resource_path.get_file())
	else:
		EventBus.toast_requested.emit("Could not save (error %d)" % err)


## Back to the numbers the panel started with, or the last ones saved.
func _reset() -> void:
	for id: StringName in _sliders:
		_sliders[id].value = _original[id]


func _give_rounds() -> void:
	GameState.inventory.add_item(_weapon.ammo_item, SPARE_ROUNDS)


func _hurt_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.take_damage(2)


func _stand_bottles_up() -> void:
	get_tree().call_group(&"practice_targets", &"stand_up")
