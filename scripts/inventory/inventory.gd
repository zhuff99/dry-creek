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


## How many of `item` are held, over all slots.
func count_of(item: ItemData) -> int:
	var total := 0
	for stack: ItemStack in _slots:
		if stack != null and stack.item == item:
			total += stack.count
	return total


## Removes up to `count` of `item` from wherever it is held and returns how
## many were removed.
func remove_item(item: ItemData, count: int = 1) -> int:
	var remaining := count
	for i: int in _slots.size():
		if remaining <= 0:
			break
		var stack := _slots[i]
		if stack == null or stack.item != item:
			continue
		var taken: int = mini(remaining, stack.count)
		stack.count -= taken
		remaining -= taken
		if stack.count <= 0:
			_slots[i] = null
	if remaining != count:
		changed.emit()
	return count - remaining


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


## Sets the uses left in the tool at `index`, clamped to what it can hold.
func set_charge(index: int, value: int) -> void:
	var stack := get_slot(index)
	if stack == null:
		return
	stack.charge = clampi(value, 0, stack.capacity())
	changed.emit()


## Moves `count` of the stack in slot `from` onto slot `to`. A whole stack
## merges with the same item or swaps with anything else; part of a stack
## goes into an empty slot or onto the same item, never swaps. True if
## anything moved.
func move_part(from: int, to: int, count: int) -> bool:
	var source := get_slot(from)
	if source == null or from == to or to < 0 or to >= _slots.size() or count <= 0:
		return false
	var target := _slots[to]
	if count >= source.count:
		if target != null and target.item == source.item and target.count >= source.item.max_stack:
			return false
		move_slot(from, to)
		return true
	if target == null:
		_slots[to] = ItemStack.new(source.item, count)
		source.count -= count
	elif target.item == source.item:
		var moved: int = mini(count, source.item.max_stack - target.count)
		if moved <= 0:
			return false
		target.count += moved
		source.count -= moved
	else:
		return false
	changed.emit()
	return true


## Takes `count` out of slot `index` and returns them as a stack of their
## own (a whole tool keeps what it holds), or null if the slot is empty.
func take_from_slot(index: int, count: int) -> ItemStack:
	var stack := get_slot(index)
	if stack == null or count <= 0:
		return null
	if count >= stack.count:
		_slots[index] = null
		changed.emit()
		return stack
	stack.count -= count
	changed.emit()
	return ItemStack.new(stack.item, count)


## Adds a whole stack and returns how many did not fit. A tool that holds
## something (water in the can) goes into an empty slot as it is, so it
## keeps what it holds.
func add_stack(stack: ItemStack) -> int:
	if stack.capacity() <= 0:
		return add_item(stack.item, stack.count)
	for i: int in _slots.size():
		if _slots[i] == null:
			_slots[i] = stack
			changed.emit()
			return 0
	return stack.count


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
