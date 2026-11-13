class_name Inventory
extends RefCounted
## Fixed-size list of item stacks. Pure data: UI listens to `changed`.

signal changed

var _slots: Array[ItemStack] = []


func _init(slot_count: int) -> void:
	_slots.resize(slot_count)


func size() -> int:
	return _slots.size()


## The stack at `index`, or null if the slot is empty or out of range.
func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


## Adds as many as fit and returns how many did NOT fit.
func add_item(item: ItemData, count: int = 1) -> int:
	var remaining := count
	# Top up existing stacks first so items do not scatter across slots.
	for stack: ItemStack in _slots:
		if remaining <= 0:
			break
		if stack != null and stack.item == item and stack.count < item.max_stack:
			var moved: int = mini(remaining, item.max_stack - stack.count)
			stack.count += moved
			remaining -= moved
	for i: int in _slots.size():
		if remaining <= 0:
			break
		if _slots[i] == null:
			var moved: int = mini(remaining, item.max_stack)
			_slots[i] = ItemStack.new(item, moved)
			remaining -= moved
	if remaining != count:
		changed.emit()
	return remaining


func can_fit(item: ItemData, count: int = 1) -> bool:
	var space := 0
	for stack: ItemStack in _slots:
		if stack == null:
			space += item.max_stack
		elif stack.item == item:
			space += item.max_stack - stack.count
		if space >= count:
			return true
	return false


## Removes up to `count` from one slot and returns how many were removed.
func remove_from_slot(index: int, count: int = 1) -> int:
	var stack := get_slot(index)
	if stack == null:
		return 0
	var removed: int = mini(count, stack.count)
	stack.count -= removed
	if stack.count <= 0:
		_slots[index] = null
	changed.emit()
	return removed


## Moves slot `from` onto slot `to`: merges matching items, otherwise swaps.
func move_slot(from: int, to: int) -> void:
	if from == to or get_slot(from) == null or to < 0 or to >= _slots.size():
		return
	var source := _slots[from]
	var target := _slots[to]
	if target != null and target.item == source.item:
		var moved: int = mini(source.count, source.item.max_stack - target.count)
		target.count += moved
		source.count -= moved
		if source.count <= 0:
			_slots[from] = null
	else:
		_slots[from] = target
		_slots[to] = source
	changed.emit()
