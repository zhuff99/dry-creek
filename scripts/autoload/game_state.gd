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


func _ready() -> void:
	for id: StringName in STARTING_ITEMS:
		inventory.add_item(ItemDB.get_item(id), STARTING_ITEMS[id])
	weapon = ItemDB.get_item(STARTING_WEAPON) as WeaponData
	rounds_loaded = weapon.chambers
	EventBus.day_ended.connect(_on_day_ended)


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
	wildlife_killed.clear()
	farm.advance_day()
	var total := shipping_bin_value()
	shipping_bin.clear()
	if total > 0:
		add_money(total)
	EventBus.shipment_paid.emit(total)
