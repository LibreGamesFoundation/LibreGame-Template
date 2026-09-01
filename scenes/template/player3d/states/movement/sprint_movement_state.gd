extends MovementState
## Sprint state. Drains [member stamina_component] while active and transitions to
## walk automatically once stamina is depleted, jump on jump input, idle if the
## player stops moving, or fall if no longer on the floor (e.g. sprinted off a ledge).

## Stamina drained per second while sprinting. Ignored if [member stamina_component] is unset.
@export var stamina_drain_rate : float = 15.0

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

	if state_machine.stamina_component != null:
		state_machine.stamina_component.change_current_resource_quantity(-stamina_drain_rate * delta)
		if is_zero_approx(state_machine.stamina_component.current_resource_quantity):
			transition.emit("WalkMovementState")
			return

	if Input.is_action_just_released("sprint"):
		transition.emit("WalkMovementState")
		return

	if Input.is_action_just_pressed("jump"):
		transition.emit("JumpMovementState")
		return

	if target.velocity.length() <= 0.0:
		transition.emit("IdleMovementState")
		return

func _physics_update(delta : float) -> void:
	pass
