extends MovementState

@export var jump_velocity : float = 4.5
@export var speed_decrease : float = 1.2

func _enter(previous_state : State) -> void:
	super._enter(previous_state)
	speed = (previous_state.speed / speed_decrease)
	target.velocity.y += jump_velocity

func _exit() -> void:
	pass

func _update(delta : float) -> void:
	target.update_gravity(delta)
	target.update_input(speed, acceleration, deceleration)
	target.update_velocity()
	
	if target.velocity.y <= 0:
		transition.emit("FallMovementState")
		return

	if target.is_on_floor():
		transition.emit("IdleMovementState")
		return

func _physics_update(delta : float) -> void:
	pass
