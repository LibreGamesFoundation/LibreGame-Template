@icon("res://assets/components/SaveComponentNode.svg")
class_name SaveComponent
extends ComponentBase
## Marks [member target] as participating in the save system.
##
## [member target] should implement [code]get_save_data() -> Dictionary[/code] and
## [code]load_save_data(data : Dictionary) -> void[/code]. If [member target] doesn't
## implement these, an empty dictionary is saved and load is a no-op.
##
## Automatically joins the "saveable" group so [SaveManager] can discover it without
## a direct type dependency.
##
## @experimental

## Stable identifier used to match saved data back to this node. Must be unique
## within [member save_category]. Leave blank to auto-generate one from
## [member target]'s node path on first save (only reliable if scene structure
## doesn't change between save and load).
@export var save_id : String

## Which file this component's data is grouped into (e.g. "player", "world",
## "settings"). Components sharing a category are written to the same file.
@export var save_category : StringName = &"game"

## If true, this component's data is written to a single shared location
## ([member SaveManager.settings_directory]) rather than being tied to a specific
## save slot. Use for audio/control/video settings — anything that shouldn't be
## duplicated per-slot or wiped when a save slot is deleted.
@export var persistent : bool = false


func _ready() -> void:
	add_to_group("saveable")
	if save_id.is_empty() and target != null:
		save_id = str(target.get_path())

#----------------#
# Public Methods #
#----------------#

## Returns [member target]'s save data, or an empty [Dictionary] if [member target]
## doesn't implement [code]get_save_data()[/code].
func get_save_data() -> Dictionary:
	if target == null or not target.has_method("get_save_data"):
		return {}
	return target.get_save_data()


## Forwards [param data] to [member target]'s [code]load_save_data()[/code], if implemented.
func load_save_data(data : Dictionary) -> void:
	if target == null or not target.has_method("load_save_data"):
		return
	if debug: print("%s: loading save data for '%s' (category '%s')" % [name, save_id, save_category])
	target.load_save_data(data)
