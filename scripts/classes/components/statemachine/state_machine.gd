@icon("res://assets/components/StateMachineNode.svg")
class_name StateMachine
extends ComponentBase
## Manages [State] nodes and the transitions between them.
##
## Designed to be used with [State]. Add [State] children to this node; the first
## child is used as the initial state unless [member current_state] is set manually.
##

signal state_changed(previous_state : State, new_state : State)

@export var current_state : State

var previous_state : State
var states : Dictionary[String, State]


func _ready() -> void:
	if target == null:
		target = get_parent()

	for child in get_children():
		if child is State:
			states[child.name] = child
			child.transition.connect(_on_child_transition)
		else:
			push_warning("State Machine Contains Incompatible Child Node: ", child)

	if current_state == null:
		if get_child_count() == 0:
			push_error("StateMachine '%s' has no State children to use as an initial state." % name)
			return
		var first_child := get_child(0)
		if first_child is State:
			current_state = first_child
		else:
			push_error("StateMachine '%s': first child is not a State and current_state was not set manually." % name)
			return

	current_state.state_machine = self
	if debug: print("%s: entering initial state %s" % [name, current_state.name])
	current_state._enter(current_state)


func _process(delta : float) -> void:
	current_state._update(delta)


func _physics_process(delta : float) -> void:
	current_state._physics_update(delta)

#----------------#
# Public Methods #
#----------------#

## Returns the [State] registered under [param state_name], or null if it doesn't exist.
func get_state_from_name(state_name : String) -> State:
	if not states.has(state_name):
		push_error("State does not exist: ", state_name, " in StateMachine: ", name)
		return null
	return states.get(state_name)


## Forces a transition to the state registered under [param state_name], as if the
## current state had emitted [signal State.transition]. Useful for triggering
## transitions from outside the state machine (animation callbacks, other components).
func transition_to(state_name : String) -> void:
	_change_state(state_name)

#-----------------#
# Private Methods #
#-----------------#

func _on_child_transition(new_state_name : String) -> void:
	_change_state(new_state_name)


func _change_state(new_state_name : String) -> void:
	var new_state : State = states.get(new_state_name)
	if new_state == null:
		push_warning("State Does Not Exist: ", new_state_name)
		return
	if new_state == current_state:
		return

	if debug: print("%s: transitioning from %s to %s" % [name, current_state.name, new_state.name])

	current_state._exit()
	new_state._enter(current_state)

	previous_state = current_state
	current_state = new_state
	state_changed.emit(previous_state, current_state)
