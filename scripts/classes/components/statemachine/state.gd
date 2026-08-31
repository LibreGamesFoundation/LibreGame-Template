class_name State
extends ComponentBase
## Base class for any StateMachine setup
##
## Designed to be used with [StateMachine]
##

var state_machine : StateMachine

signal transition(new_state_name : String)

func _enter(previous_state : State) -> void:
	state_machine = get_parent()
	target = state_machine.target

func _exit() -> void:
	pass

func _update(delta : float) -> void:
	pass

func _physics_update(delta : float) -> void:
	pass
