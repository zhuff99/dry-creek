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
## The gun the ranch came with. It is worn, not carried in the bag.
const STARTING_WEAPON := &"revolver"

var money: int = 0
var inventory := Inventory.new(INVENTORY_SIZE)
var farm := FarmData.new()
var selected_slot: int = 0
## The gun on the player's hip, or null if they own none.
var weapon: WeaponData
## Rounds in that gun right now.
var rounds_loaded: int = 0:
	set(value):
		rounds_loaded = value
		EventBus.rounds_changed.emit(rounds_loaded)
## Goods waiting in the shipping crate: item id -> count. Paid out overnight.
var shipping_bin: Dictionary[StringName, int] = {}


func _ready() -> void:
	for id: StringName in STARTING_ITEMS:
		inventory.add_item(ItemDB.get_item(id), STARTING_ITEMS[id])
	weapon = ItemDB.get_item(STARTING_WEAPON) as WeaponData
	rounds_loaded = weapon.chambers
	EventBus.day_ended.connect(_on_day_ended)


func add_money(amount: int) -> void:
	money += amount
	EventBus.money_changed.emit(money)


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
	farm.advance_day()
	var total := shipping_bin_value()
	shipping_bin.clear()
	if total > 0:
		add_money(total)
	EventBus.shipment_paid.emit(total)
