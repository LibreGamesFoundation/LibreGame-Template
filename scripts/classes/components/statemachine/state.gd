@icon("res://assets/components/StateNode.svg")
class_name State
extends ComponentBase
## Base class for any StateMachine setup
##
## Designed to be used with [StateMachine]
##

var state_machine : StateMachine

signal transition(new_state_name : String)

## Called when the state is entered.
func _enter(previous_state : State) -> void:
	state_machine = get_parent()
	target = state_machine.target


## Called when the state is exited.
func _exit() -> void:
	pass


## Called every frame when the state is active. 'delta' is the elapsed time since the previous frame
func _update(delta : float) -> void:
	pass


## Called every frame when the state is active. 'delta' is the elapsed time since the previous frame
func _physics_update(delta : float) -> void:
	pass
