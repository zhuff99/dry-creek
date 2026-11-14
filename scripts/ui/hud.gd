extends Control
## Always-on overlay: day, health, stamina, money, held item name,
## interaction prompt, toasts.

const TOAST_HOLD_SECONDS := 2.0
const TOAST_SECONDS_PER_LETTER := 0.04
const TOAST_FADE_SECONDS := 0.5

var _toast_tween: Tween
var _gun_drawn: bool = false

@onready var _day_label: Label = $TopBar/DayLabel
@onready var _money_label: Label = $TopBar/MoneyLabel
@onready var _health_bar: ProgressBar = $TopBar/Vitals/Bars/Health
@onready var _stamina_bar: StaminaBar = $TopBar/Vitals/Bars/Stamina
@onready var _toast_label: Label = $ToastRow/ToastLabel
@onready var _prompt_label: Label = $Bottom/PromptLabel
@onready var _item_label: Label = $Bottom/ItemLabel


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.toast_requested.connect(_show_toast)
	EventBus.hotbar_slot_selected.connect(_on_slot_selected)
	GameState.inventory.changed.connect(_refresh_item_label)
	EventBus.weapon_drawn_changed.connect(_on_weapon_drawn_changed)
	EventBus.rounds_changed.connect(func(_loaded: int) -> void: _refresh_item_label())
	EventBus.health_changed.connect(_on_health_changed)
	_on_health_changed(GameState.health, GameState.max_health)
	EventBus.stamina_changed.connect(_stamina_bar.show_levels)
	EventBus.stamina_lacking.connect(_on_stamina_lacking)
	_stamina_bar.show_levels(GameState.stamina, GameState.stamina_ceiling, GameState.max_stamina)
	_on_day_started(GameClock.day)
	_on_money_changed(GameState.money)
	_on_prompt_changed("")
	_refresh_item_label()
	_set_text(_toast_label, "")


func _on_day_started(day: int) -> void:
	_set_text(_day_label, "Day %d" % day)


func _on_health_changed(health: int, max_health: int) -> void:
	var dropped := health < _health_bar.value
	_health_bar.max_value = max_health
	_health_bar.value = health
	if dropped:
		# Flash the bar so a hit is noticed even when looking elsewhere.
		_health_bar.modulate = Color(3, 3, 3)
		create_tween().tween_property(_health_bar, "modulate", Color.WHITE, 0.35)


## Flash the bar so it is clear why nothing happened.
func _on_stamina_lacking() -> void:
	_stamina_bar.modulate = Color(3, 1.2, 1.2)
	create_tween().tween_property(_stamina_bar, "modulate", Color.WHITE, 0.35)


func _on_money_changed(amount: int) -> void:
	_set_text(_money_label, "$%d" % amount)


func _on_prompt_changed(text: String) -> void:
	_set_text(_prompt_label, "[E] %s" % text if text != "" else "")


func _on_slot_selected(_index: int) -> void:
	_refresh_item_label()


func _on_weapon_drawn_changed(drawn: bool) -> void:
	_gun_drawn = drawn
	_refresh_item_label()


## Names what is in hand: the drawn gun and its rounds, or the hotbar item.
func _refresh_item_label() -> void:
	var weapon := GameState.weapon
	if _gun_drawn and weapon != null:
		_set_text(_item_label, "%s  %d/%d   %d spare" % [
			weapon.display_name, GameState.rounds_loaded, weapon.chambers,
			GameState.inventory.count_of(weapon.ammo_item),
		])
		return
	var stack := GameState.selected_stack()
	if stack == null:
		_set_text(_item_label, "")
	elif stack.capacity() > 0:
		_set_text(_item_label, "%s  %d/%d" % [stack.item.display_name, stack.charge, stack.capacity()])
	else:
		_set_text(_item_label, stack.item.display_name)


func _show_toast(text: String) -> void:
	_set_text(_toast_label, text)
	_toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	# Longer messages stay up longer, so there is time to read them.
	_toast_tween.tween_interval(TOAST_HOLD_SECONDS + text.length() * TOAST_SECONDS_PER_LETTER)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, TOAST_FADE_SECONDS)


## Labels have a dark backing box, so hide them while they are empty.
func _set_text(label: Label, text: String) -> void:
	label.text = text
	label.visible = text != ""
