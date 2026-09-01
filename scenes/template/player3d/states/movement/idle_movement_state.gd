extends MovementState
## Idle state. Transitions to walk on movement input, jump on jump input, or fall
## if the player is no longer on the floor (e.g. walked off a ledge).

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

	if target.velocity.length() > 0.0:
		transition.emit("WalkMovementState")
		return

func _physics_update(delta : float) -> void:
	pass
