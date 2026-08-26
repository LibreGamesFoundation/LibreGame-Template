@icon("res://assets/components/InventoryComponentNode.svg")
class_name InventoryComponent
extends ComponentBase
## Component for storing and managing a collection of stackable items.
##
## Items are represented by [InventoryItem] resources; each slot holds an item
## reference and a quantity.
##
## @experimental

signal item_added(item : InventoryItem, quantity : int)
signal item_removed(item : InventoryItem, quantity : int)
signal item_quantity_changed(item : InventoryItem, old_quantity : int, new_quantity : int)
signal inventory_full()
signal inventory_changed()

@export_category("Inventory Configuration")
## Maximum number of distinct item stacks (slots) this inventory can hold.
## Set to 0 for unlimited slots.
@export var slot_capacity : int = 20
## If true, items stack up to their [member InventoryItem.max_stack_size].
## If false, every item occupies its own slot regardless of stack size.
@export var allow_stacking : bool = true

var _slots : Array[InventorySlot] = []


class InventorySlot:
	var item : InventoryItem
	var quantity : int

	func _init(p_item : InventoryItem, p_quantity : int) -> void:
		item = p_item
		quantity = p_quantity

#----------------#
# Public Methods #
#----------------#

## Attempts to add [param quantity] of [param item] to the inventory.
## Returns the quantity that could NOT be added (0 if fully successful).
func add_item(item : InventoryItem, quantity : int = 1) -> int:
	if item == null or quantity <= 0:
		return quantity

	var remaining := quantity

	if allow_stacking:
		remaining = _fill_existing_stacks(item, remaining)

	while remaining > 0:
		if is_full():
			inventory_full.emit()
			break

		var stack_amount := remaining
		if allow_stacking:
			stack_amount = min(remaining, item.max_stack_size)

		_slots.append(InventorySlot.new(item, stack_amount))
		remaining -= stack_amount
		item_added.emit(item, stack_amount)

	if remaining != quantity:
		inventory_changed.emit()

	return remaining


## Attempts to remove [param quantity] of [param item] from the inventory.
## Returns the quantity that could NOT be removed (0 if fully successful).
func remove_item(item : InventoryItem, quantity : int = 1) -> int:
	if item == null or quantity <= 0:
		return quantity

	var remaining := quantity
	var i := _slots.size() - 1
	while i >= 0 and remaining > 0:
		var slot := _slots[i]
		if slot.item == item:
			var removed : int = min(slot.quantity, remaining)
			var old_quantity := slot.quantity
			slot.quantity -= removed
			remaining -= removed

			if slot.quantity <= 0:
				_slots.remove_at(i)
			else:
				item_quantity_changed.emit(item, old_quantity, slot.quantity)

			item_removed.emit(item, removed)
		i -= 1

	if remaining != quantity:
		inventory_changed.emit()

	return remaining


## Returns true if the inventory contains at least [param quantity] of [param item].
func has_item(item : InventoryItem, quantity : int = 1) -> bool:
	return get_item_quantity(item) >= quantity


## Returns the total quantity of [param item] across all slots.
func get_item_quantity(item : InventoryItem) -> int:
	var total := 0
	for slot in _slots:
		if slot.item == item:
			total += slot.quantity
	return total


## Returns true if the inventory has no free slots remaining.
## Always returns false if [member slot_capacity] is 0 (unlimited).
func is_full() -> bool:
	if slot_capacity <= 0:
		return false
	return _slots.size() >= slot_capacity


## Returns the number of free slots remaining, or -1 if [member slot_capacity] is 0 (unlimited).
func get_free_slot_count() -> int:
	if slot_capacity <= 0:
		return -1
	return slot_capacity - _slots.size()


## Removes all items from the inventory.
func clear() -> void:
	_slots.clear()
	inventory_changed.emit()


## Returns a duplicated array of all current slots. Modify the inventory via
## [method add_item]/[method remove_item] rather than editing this array directly.
func get_all_slots() -> Array[InventorySlot]:
	return _slots.duplicate()

#-----------------#
# Private Methods #
#-----------------#

## Fills existing stacks of [param item] with as much of [param quantity] as possible.
## Returns the quantity that still could not be placed into existing stacks.
func _fill_existing_stacks(item : InventoryItem, quantity : int) -> int:
	var remaining := quantity
	for slot in _slots:
		if remaining <= 0:
			break
		if slot.item != item or slot.quantity >= item.max_stack_size:
			continue

		var space := item.max_stack_size - slot.quantity
		var added : int = min(space, remaining)
		var old_quantity := slot.quantity
		slot.quantity += added
		remaining -= added
		item_quantity_changed.emit(item, old_quantity, slot.quantity)

	return remaining
