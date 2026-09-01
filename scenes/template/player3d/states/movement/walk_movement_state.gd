extends MovementState
## Walk state. Transitions to jump, idle, sprint (if enough stamina), or fall
## if the player is no longer on the floor (e.g. walked off a ledge).

## Minimum stamina required to begin sprinting. Ignored if [member stamina_component] is unset.
@export var min_stamina_to_sprint : float = 10.0

func _enter(previous_state : State) -> void:
	super._enter(previous_state)

func _exit() -> void:
	pass

func _update(delta : float) -> void:
	target.update_gravity(delta)
	target.update_input(speed, acceleration, deceleration)
	target.update_velocity()

	if not target.is_on_floor():
		transition.emit("FallMovementState")
		return

	if Input.is_action_just_pressed("jump"):
		transition.emit("JumpMovementState")
		return

	if target.velocity.length() <= 0.0:
		transition.emit("IdleMovementState")
		return

	if Input.is_action_pressed("sprint") and _has_enough_stamina():
		transition.emit("SprintMovementState")
		return

func _physics_update(delta : float) -> void:
	pass

#-----------------#
# Private Methods #
#-----------------#

func _has_enough_stamina() -> bool:
	if state_machine.stamina_component == null:
		return true
	return state_machine.stamina_component.current_resource_quantity >= min_stamina_to_sprint
