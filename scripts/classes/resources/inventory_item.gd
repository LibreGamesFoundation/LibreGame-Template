class_name InventoryItem
extends Resource
## Base resource describing a stackable inventory item.
##
## Author individual items as .tres files using this resource (or a subclass of it).
## Two slots are considered the "same item" if they reference the same InventoryItem
## resource instance.

@export var item_id : StringName
@export var display_name : String
@export var icon : Texture2D
@export var max_stack_size : int = 99
@export_multiline var description : String
