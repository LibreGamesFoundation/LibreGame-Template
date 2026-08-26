@icon("res://assets/components/ResourceComponentNode.svg")
class_name ResourceComponent
extends ComponentBase
## Component for creating and managing any type of singular resource.
##
## Examples include health, stamina, mana, etc.
##

signal current_resource_quantity_changed(old_quantity : float, new_quantity : float)
signal max_resource_quantity_changed(old_quantity : float, new_quantity : float)
signal current_resource_quantity_at_max()
signal current_resource_quantity_at_min()
signal regeneration_started()
signal regeneration_finished()

enum RegenType {
	LINEAR, ## Regenerates at a constant [member regen_rate] per second.
	CURVE, ## Regenerates at a rate scaled by [member regen_curve], sampled by current percentage.
}

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
## Determines how [member regen_rate] is applied over time.
@export var regen_type : RegenType = RegenType.LINEAR
## Amount of resource regenerated per second while regeneration is active (used directly
## in [constant RegenType.LINEAR], and as a multiplier for [member regen_curve] in
## [constant RegenType.CURVE]).
@export var regen_rate : float = 5.0
## Sampled by current resource percentage (0.0 to 1.0) to scale [member regen_rate] when
## [member regen_type] is [constant RegenType.CURVE]. For example, a curve that starts low
## and rises can simulate regen that accelerates the longer it continues.
@export var regen_curve : Curve
## Seconds to wait after [member current_resource_quantity] decreases before
## regeneration resumes. Set to 0.0 to regenerate continuously.
@export var regen_delay : float = 0.0

@export_category("Source Collection")
@export var collect_sources : bool = false

var source_dictionary : Dictionary[String, float]

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
			if debug: print("%s: regeneration interrupted" % name)
			regeneration_finished.emit()

	if debug: print("%s: %s changed from %.2f to %.2f" % [name, resource_name, current_resource_quantity, new_quantity])
	current_resource_quantity_changed.emit(current_resource_quantity, new_quantity)
	current_resource_quantity = new_quantity

	if is_equal_approx(current_resource_quantity, max_resource_quantity):
		if debug: print("%s: %s reached max" % [name, resource_name])
		current_resource_quantity_at_max.emit()
	elif is_zero_approx(current_resource_quantity):
		if debug: print("%s: %s reached min" % [name, resource_name])
		current_resource_quantity_at_min.emit()

## Sets the [member max_resource_quantity] to a new quantity
func set_max_resource_quantity(new_quantity : float) -> void:
	if new_quantity < 0.0:
		set_max_resource_quantity(0.0)
		return

	if debug: print("%s: max %s changed from %.2f to %.2f" % [name, resource_name, max_resource_quantity, new_quantity])
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

## Returns [member current_resource_quantity] as a percentage of [member max_resource_quantity],
## in the range 0.0 to 1.0. Returns 0.0 if [member max_resource_quantity] is 0 to avoid
## dividing by zero.
func get_percentage() -> float:
	if is_zero_approx(max_resource_quantity):
		return 0.0
	return current_resource_quantity / max_resource_quantity

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
		if debug: print("%s: regeneration started" % name)
		regeneration_started.emit()

	set_current_resource_quantity(current_resource_quantity + _get_current_regen_amount(delta))

	if is_equal_approx(current_resource_quantity, max_resource_quantity):
		_is_regenerating = false
		if debug: print("%s: regeneration finished" % name)
		regeneration_finished.emit()

func _get_current_regen_amount(delta : float) -> float:
	match regen_type:
		RegenType.CURVE:
			if regen_curve == null:
				push_warning("ResourceComponent: regen_type is CURVE but no regen_curve is assigned. Falling back to LINEAR.")
				return regen_rate * delta
			return regen_curve.sample(get_percentage()) * regen_rate * delta
		_:
			return regen_rate * delta
