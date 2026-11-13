extends Control
## Always-on overlay: day, money, held item name, interaction prompt, toasts.

const TOAST_HOLD_SECONDS := 2.5
const TOAST_FADE_SECONDS := 0.5

var _toast_tween: Tween

@onready var _day_label: Label = $TopBar/DayLabel
@onready var _money_label: Label = $TopBar/MoneyLabel
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
	_on_day_started(GameClock.day)
	_on_money_changed(GameState.money)
	_on_prompt_changed("")
	_refresh_item_label()
	_set_text(_toast_label, "")


func _on_day_started(day: int) -> void:
	_set_text(_day_label, "Day %d" % day)


func _on_money_changed(amount: int) -> void:
	_set_text(_money_label, "$%d" % amount)


func _on_prompt_changed(text: String) -> void:
	_set_text(_prompt_label, "[E] %s" % text if text != "" else "")


func _on_slot_selected(_index: int) -> void:
	_refresh_item_label()


func _refresh_item_label() -> void:
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
	_toast_tween.tween_interval(TOAST_HOLD_SECONDS)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, TOAST_FADE_SECONDS)


## Labels have a dark backing box, so hide them while they are empty.
func _set_text(label: Label, text: String) -> void:
	label.text = text
	label.visible = text != ""
