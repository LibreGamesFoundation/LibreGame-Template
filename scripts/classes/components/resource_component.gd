@icon("res://assets/components/ResourceComponentNode.svg")
class_name ResourceComponent
extends ComponentBase
## Experimental component for creating and managing any type of singular resource.
##
## Examples include health, stamina, mana, etc.
##
## @experimental

signal current_resource_quantity_changed(old_quantity : float, new_quantity : float)
signal max_resource_quantity_changed(old_quantity : float, new_quantity : float)
signal current_resource_quantity_at_max()
signal current_resource_quantity_at_min()
signal regeneration_started()
signal regeneration_finished()

@export_category("Resource Initialization")
@export var resource_name : String
@export var max_resource_quantity : float = 100.0
## If set to true, [member current_resource_quantity] will be set to the [member max_resource_quantity] on ready
@export var start_at_max : bool = true
@export var current_resource_quantity : float

@export_category("Regeneration")
## If true, [member current_resource_quantity] will regenerate automatically over time
## up to [member max_resource_quantity].
@export var regen_enabled : bool = false
## Amount of resource regenerated per second while regeneration is active.
@export var regen_rate : float = 5.0
## Seconds to wait after [member current_resource_quantity] decreases before
## regeneration resumes. Set to 0.0 to regenerate continuously.
@export var regen_delay : float = 0.0

var _time_since_last_decrease : float = 0.0
var _is_regenerating : bool = false

func _ready() -> void:
	if start_at_max:
		current_resource_quantity = max_resource_quantity

func _process(delta : float) -> void:
	if not regen_enabled:
		return
	_process_regeneration(delta)

#----------------#
# Public Methods #
#----------------#

## Sets the [member current_resource_quantity] to a new quantity
func set_current_resource_quantity(new_quantity : float) -> void:
	if new_quantity < 0.0:
		set_current_resource_quantity(0.0)
		return

	new_quantity = min(new_quantity, max_resource_quantity)

	if new_quantity < current_resource_quantity:
		_time_since_last_decrease = 0.0
		if _is_regenerating:
			_is_regenerating = false
			regeneration_finished.emit()

	current_resource_quantity_changed.emit(current_resource_quantity, new_quantity)
	current_resource_quantity = new_quantity

	if is_equal_approx(current_resource_quantity, max_resource_quantity):
		current_resource_quantity_at_max.emit()
	elif is_zero_approx(current_resource_quantity):
		current_resource_quantity_at_min.emit()


## Sets the [member max_resource_quantity] to a new quantity
func set_max_resource_quantity(new_quantity : float) -> void:
	if new_quantity < 0.0:
		set_max_resource_quantity(0.0)
		return

	max_resource_quantity_changed.emit(max_resource_quantity, new_quantity)
	max_resource_quantity = new_quantity

	if current_resource_quantity > max_resource_quantity:
		set_current_resource_quantity(max_resource_quantity)

## Applies a relative change to [member current_resource_quantity] by the given amount.
## Use a negative value to decrease (e.g. damage), positive to increase (e.g. healing).
func change_current_resource_quantity(amount : float) -> void:
	set_current_resource_quantity(current_resource_quantity + amount)

## Applies a relative change to [member max_resource_quantity] by the given amount.
## Use a negative value to decrease (e.g. damage), positive to increase (e.g. healing).
func change_max_resource_quantity(amount : float) -> void:
	set_max_resource_quantity(max_resource_quantity + amount)

#-----------------#
# Private Methods #
#-----------------#

func _process_regeneration(delta : float) -> void:
	if is_equal_approx(current_resource_quantity, max_resource_quantity):
		return

	if regen_delay > 0.0 and _time_since_last_decrease < regen_delay:
		_time_since_last_decrease += delta
		return

	if not _is_regenerating:
		_is_regenerating = true
		regeneration_started.emit()

	set_current_resource_quantity(current_resource_quantity + regen_rate * delta)

	if is_equal_approx(current_resource_quantity, max_resource_quantity):
		_is_regenerating = false
		regeneration_finished.emit()
