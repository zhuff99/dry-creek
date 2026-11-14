extends Node
## Persistent player and ranch state (autoload "GameState").
##
## State lives here rather than in scenes so it survives area changes and keeps
## simulating while the player is away from the farm (in town, or in jail).

const INVENTORY_SIZE := 27
const HOTBAR_SIZE := 9
## Item id -> count handed to a new game, in hotbar order.
## The axe, pickaxe and scythe are here only until the town exists (M3): they
## will be bought there instead, and should then be removed from this list.
const STARTING_ITEMS := {
	&"hoe": 1,
	&"watering_can": 1,
	&"axe": 1,
	&"pickaxe": 1,
	&"scythe": 1,
	&"corn_seeds": 12,
	&"bean_seeds": 12,
	&"revolver_rounds": 24,
}
const STARTING_HEALTH := 10
const STARTING_STAMINA := 100.0
## Seconds without working before stamina starts coming back.
const STAMINA_REST_DELAY := 1.2
## Stamina regained per second after that.
const STAMINA_REGEN := 14.0
## How much of every point spent is gone until you sleep: the level stamina
## refills to drops by this share of the cost.
const FATIGUE_SHARE := 0.25
## Share of your money that passing out costs (someone has to get you home).
const PASS_OUT_COST := 0.1
## The gun the ranch came with. It is worn, not carried in the bag.
const STARTING_WEAPON := &"revolver"

var money: int = 0
var inventory := Inventory.new(INVENTORY_SIZE)
var farm := FarmData.new()
var selected_slot: int = 0
var max_health: int = STARTING_HEALTH
var health: int = STARTING_HEALTH:
	set(value):
		health = clampi(value, 0, max_health)
		EventBus.health_changed.emit(health, max_health)
var max_stamina: float = STARTING_STAMINA
## How far stamina refills today. Work wears it down; a night's sleep puts
## it back to `max_stamina`.
var stamina_ceiling: float = STARTING_STAMINA
## What is left right now. Tool work spends it; shooting does not.
var stamina: float = STARTING_STAMINA
## The gun on the player's hip, or null if they own none.
var weapon: WeaponData
## Rounds in that gun right now.
var rounds_loaded: int = 0:
	set(value):
		rounds_loaded = value
		EventBus.rounds_changed.emit(rounds_loaded)
## Goods waiting in the shipping crate: item id -> count. Paid out overnight.
var shipping_bin: Dictionary[StringName, int] = {}
## Wild animals killed today, by the key their spawner gave them. They are
## back tomorrow.
var wildlife_killed: Dictionary[String, bool] = {}

## Seconds of rest still needed before stamina starts refilling.
var _rest_wait: float = 0.0


func _ready() -> void:
	for id: StringName in STARTING_ITEMS:
		inventory.add_item(ItemDB.get_item(id), STARTING_ITEMS[id])
	weapon = ItemDB.get_item(STARTING_WEAPON) as WeaponData
	rounds_loaded = weapon.chambers
	EventBus.day_ended.connect(_on_day_ended)


func _process(delta: float) -> void:
	if stamina >= stamina_ceiling:
		return
	_rest_wait -= delta
	if _rest_wait > 0.0:
		return
	stamina = minf(stamina + STAMINA_REGEN * delta, stamina_ceiling)
	_report_stamina()


func add_money(amount: int) -> void:
	money += amount
	EventBus.money_changed.emit(money)


## Takes health away. At nothing, the player passes out: the day ends, a
## share of their money goes, and they wake at home (World and the day
## transition do the rest).
func hurt(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	if health <= 0:
		var lost := int(money * PASS_OUT_COST)
		if lost > 0:
			add_money(-lost)
		EventBus.player_passed_out.emit(lost)


func heal(amount: int) -> void:
	health += amount


## True if there is stamina for something costing `cost`.
func can_exert(cost: float) -> bool:
	return cost <= 0.0 or stamina >= cost


## True if `cost` is more than today's rest can ever give back: no amount of
## waiting will do, only sleep.
func is_worn_out_for(cost: float) -> bool:
	return cost > stamina_ceiling


## Spends stamina on a piece of work. Most of it comes back with rest; the
## remainder is the day's wear, and lowers how far the bar refills.
func exert(cost: float) -> void:
	if cost <= 0.0:
		return
	stamina = maxf(stamina - cost, 0.0)
	stamina_ceiling = maxf(stamina_ceiling - cost * FATIGUE_SHARE, 0.0)
	_rest_wait = STAMINA_REST_DELAY
	_report_stamina()


## Fully rested, as after a night's sleep.
func rest_fully() -> void:
	stamina_ceiling = max_stamina
	stamina = max_stamina
	_report_stamina()


func _report_stamina() -> void:
	EventBus.stamina_changed.emit(stamina, stamina_ceiling, max_stamina)


func select_slot(index: int) -> void:
	selected_slot = posmod(index, HOTBAR_SIZE)
	EventBus.hotbar_slot_selected.emit(selected_slot)


## The stack in the selected hotbar slot, or null if that slot is empty.
func selected_stack() -> ItemStack:
	return inventory.get_slot(selected_slot)


func ship(item: ItemData, count: int) -> void:
	shipping_bin[item.id] = shipping_bin.get(item.id, 0) + count


func shipping_bin_value() -> int:
	var total := 0
	for id: StringName in shipping_bin:
		total += ItemDB.get_item(id).sell_price * shipping_bin[id]
	return total


func _on_day_ended(_day: int) -> void:
	# A night's sleep mends everything, for now.
	health = max_health
	rest_fully()
	wildlife_killed.clear()
	farm.advance_day()
	var total := shipping_bin_value()
	shipping_bin.clear()
	if total > 0:
		add_money(total)
	EventBus.shipment_paid.emit(total)
