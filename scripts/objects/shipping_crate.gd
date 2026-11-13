extends StaticBody2D
## Interact while holding something sellable to ship the whole stack.
## Shipped goods are paid for overnight (see GameState).

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(player: Player) -> void:
	var stack := GameState.selected_stack()
	if stack == null or stack.item.sell_price <= 0:
		EventBus.toast_requested.emit("Select something to sell on your hotbar first.")
		return
	var item := stack.item
	var count := GameState.inventory.remove_from_slot(GameState.selected_slot, stack.count)
	GameState.ship(item, count)
	EventBus.toast_requested.emit(
		"Shipped %d %s. $%d will be paid overnight." % [count, item.display_name, item.sell_price * count]
	)
	EventBus.report(&"goods_shipped", player, global_position, {"item": item.id, "count": count})
