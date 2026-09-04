@icon("res://assets/interaction/InteractionArea3DNode.svg")
class_name InteractionArea3D
extends Area3D
## Marks this area as interactable by an [InteractionComponent3D].
##
## Automatically added to the "interactable" group so [InteractionComponent3D] can
## detect it without a direct type dependency. Configure collision layers/masks
## in the editor so only the interactor's [ShapeCast3D] detects this.
##
## @experimental

signal focused(interactor : Node)
signal unfocused(interactor : Node)
signal interacted(interactor : Node)

@export_category("Interaction Settings")
## If false, this area is ignored by [InteractionComponent3D] entirely.
@export var interaction_enabled : bool = true
## Shown by UI (e.g. "Press E to open") while this area has focus. Left to the
## consumer of [signal focused] to actually render.
@export var interact_prompt : String = "Interact"
## Maximum uses before [member interaction_enabled] is automatically set to false.
## Set to 0 for unlimited uses.
@export var max_uses : int = 0

@export_category("Debug")
@export var debug : bool = false

var use_count : int = 0


func _ready() -> void:
	add_to_group("interactable")

#----------------#
# Public Methods #
#----------------#

## Called by [InteractionComponent3D] when [param interactor] triggers interaction
## while this area has focus. Returns true if the interaction was accepted, or
## false if it was ignored (e.g. disabled, out of uses).
func interact(interactor : Node) -> bool:
	if not interaction_enabled:
		if debug: print("%s: interaction ignored (disabled)" % name)
		return false

	use_count += 1
	if debug: print("%s: interacted by %s (use %d)" % [name, interactor.name, use_count])
	interacted.emit(interactor)

	if max_uses > 0 and use_count >= max_uses:
		interaction_enabled = false
		if debug: print("%s: reached max_uses, disabling" % name)

	return true


## Called by [InteractionComponent3D] when this area gains focus (the interactor's
## cast starts resting on it). Not called if [member interaction_enabled] is false.
func on_focus(interactor : Node) -> void:
	if debug: print("%s: focused by %s" % [name, interactor.name])
	focused.emit(interactor)


## Called by [InteractionComponent3D] when this area loses focus.
func on_unfocus(interactor : Node) -> void:
	if debug: print("%s: unfocused by %s" % [name, interactor.name])
	unfocused.emit(interactor)


## Resets [member use_count] and re-enables interaction. Useful for re-usable
## interactables (a chest that refills, a switch that resets).
func reset_uses() -> void:
	use_count = 0
	interaction_enabled = true
	if debug: print("%s: uses reset" % name)
