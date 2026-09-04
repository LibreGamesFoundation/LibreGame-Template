@icon("res://assets/components/InteractionComponent3DNode.svg")
class_name InteractionComponent3D
extends ComponentBase
## Detects and interacts with nearby [InteractionArea3D]s via a [ShapeCast3D].
##
## Requires a [ShapeCast3D] assigned via [member shape_cast], typically a child of
## the camera pointing forward. Casts every frame to track focus, so UI (prompts,
## outline shaders) can react to [signal focus_changed] in real time.
##
## @experimental

signal focus_changed(old_target : InteractionArea3D, new_target : InteractionArea3D)
signal interaction_succeeded(target : InteractionArea3D)
signal interaction_failed(target : InteractionArea3D)

@export_category("References")
@export var shape_cast : ShapeCast3D

@export_category("Interaction Settings")
@export var interact_action : StringName = &"interact"
## Maximum distance an [InteractionArea3D] can be focused from, even if
## [member shape_cast]'s range is longer. Set to 0.0 to use the cast's full range.
@export var max_interact_distance : float = 0.0

var current_target : InteractionArea3D


func _ready() -> void:
	if shape_cast == null:
		push_warning("%s: no ShapeCast3D assigned; interaction detection disabled." % name)
	shape_cast.collide_with_areas = true

func _physics_process(_delta : float) -> void:
	if shape_cast == null:
		return

	var detected := _find_closest_interactable()
	_update_focus(detected)


func _unhandled_input(event : InputEvent) -> void:
	if not event.is_action_pressed(interact_action):
		return
	if current_target == null:
		if debug: print("Pressed interact, no current_target")
		return
	try_interact()

#----------------#
# Public Methods #
#----------------#

## Attempts to interact with [member current_target]. Returns false if there is
## no current target or the target rejected the interaction.
func try_interact() -> bool:
	if debug: print("Trying Interaction")
	
	if current_target == null:
		return false

	var accepted : bool = current_target.interact(target if target != null else self)

	if accepted:
		if debug: print("%s: interaction succeeded on %s" % [name, current_target.name])
		interaction_succeeded.emit(current_target)
	else:
		if debug: print("%s: interaction failed on %s" % [name, current_target.name])
		interaction_failed.emit(current_target)

	return accepted

#-----------------#
# Private Methods #
#-----------------#

func _find_closest_interactable() -> InteractionArea3D:
	if not shape_cast.is_colliding():
		return null

	var closest : InteractionArea3D = null
	var closest_distance := INF

	for i in shape_cast.get_collision_count():
		var collider := shape_cast.get_collider(i)
		if not collider is InteractionArea3D:
			continue
		if not collider.is_in_group("interactable") or not collider.interaction_enabled:
			continue

		var distance := shape_cast.global_position.distance_to(collider.global_position)
		if max_interact_distance > 0.0 and distance > max_interact_distance:
			continue

		if distance < closest_distance:
			closest = collider
			closest_distance = distance

	return closest


func _update_focus(detected : InteractionArea3D) -> void:
	if detected == current_target:
		return

	var interactor := target if target != null else self

	if current_target != null:
		current_target.on_unfocus(interactor)

	if detected != null:
		detected.on_focus(interactor)

	if debug: print("%s: focus %s -> %s" % [name, current_target.name if current_target else "none", detected.name if detected else "none"])
	focus_changed.emit(current_target, detected)
	current_target = detected
