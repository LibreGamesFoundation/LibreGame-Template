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

@export_category("Resource Initialization")
@export var resource_name : String
@export var max_resource_quantity : float = 100.0
## If set to true, [member current_resource_quantity] will be set to the [member maximum_resource_quantity] on ready
@export var start_at_max : bool = true
@export var current_resource_quantity : float

var regen_timer : float = 0.0

func _ready() -> void:
	current_resource_quantity = max_resource_quantity

#----------------#
# Public Methods #
#----------------#

## Sets the [member current_resource_quantity] to a new quantity
func set_current_resource_quantity(new_quantity : float) -> void:
	if new_quantity < 0.0:
		set_current_resource_quantity(0.0)
		return
	current_resource_quantity_changed.emit(current_resource_quantity, new_quantity)
	current_resource_quantity = new_quantity

## Sets the [member max_resource_quantity] to a new quantity
func set_max_resource_quantity(new_quantity : float) -> void:
	if new_quantity < 0.0:
		set_current_resource_quantity(0.0)
		return
	max_resource_quantity_changed.emit(max_resource_quantity, new_quantity)
	max_resource_quantity = new_quantity
