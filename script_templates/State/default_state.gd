extends State

## Called when the state is entered.
func _enter(previous_state : State) -> void:
	super._enter(previous_state)


## Called when the state is exited.
func _exit() -> void:
	pass


## Called every frame when the state is active. 'delta' is the elapsed time since the previous frame
func _update(delta : float) -> void:
	pass


## Called every frame when the state is active. 'delta' is the elapsed time since the previous frame
func _physics_update(delta : float) -> void:
	pass
