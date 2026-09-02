extends Node
## Global manager for overall game state (menu, playing, paused, cutscene, etc).
##
## Autoloaded as [code]GameStateManager[/code]. Other systems should react to
## [signal game_state_changed] rather than polling [member current_state] every frame.

signal game_state_changed(previous_state : GameState, new_state : GameState)
signal game_paused()
signal game_resumed()

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	CUTSCENE,
}

@export_category("State Configuration")
@export var initial_state : GameState = GameState.MENU
## States in which [member SceneTree.paused] is automatically set to true.
## Nodes that should keep running while paused (e.g. a pause menu UI) need
## [member Node.process_mode] set to [constant Node.PROCESS_MODE_ALWAYS] or
## [constant Node.PROCESS_MODE_WHEN_PAUSED].
@export var tree_paused_states : Array[GameState] = [GameState.PAUSED]
## States in which [member Input.mouse_mode] is forced to
## [constant Input.MOUSE_MODE_VISIBLE], e.g. so the player can click menu buttons.
@export var mouse_visible_states : Array[GameState] = [GameState.MENU, GameState.PAUSED]

@export_category("Pause Input")
## If true, [param pause_action] toggles between PLAYING and PAUSED automatically.
## Set to false to drive pausing entirely through [method change_state] instead.
@export var handle_pause_input : bool = true
@export var pause_action : StringName = &"pause"

@export_category("Debug")
@export var debug : bool = false

var current_state : GameState
var previous_state : GameState


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	current_state = initial_state
	_apply_state_side_effects(current_state)
	if debug: print("GameStateManager: initial state %s" % GameState.keys()[current_state])


func _unhandled_input(event : InputEvent) -> void:
	if not handle_pause_input:
		return
	if not event.is_action_pressed(pause_action):
		return
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)
	elif current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)

#----------------#
# Public Methods #
#----------------#

## Transitions to [param new_state], applying pause/mouse-mode side effects and
## emitting [signal game_state_changed]. No-ops if already in [param new_state].
func change_state(new_state : GameState) -> void:
	if new_state == current_state:
		return

	if debug: print("GameStateManager: %s -> %s" % [GameState.keys()[current_state], GameState.keys()[new_state]])

	previous_state = current_state
	current_state = new_state
	_apply_state_side_effects(current_state)
	game_state_changed.emit(previous_state, current_state)


## Returns true if [member current_state] matches [param state].
func is_state(state : GameState) -> bool:
	return current_state == state


## Convenience for returning to [member previous_state], e.g. closing a pause
## menu back to whatever state was active before it.
func revert_to_previous_state() -> void:
	change_state(previous_state)

#-----------------#
# Private Methods #
#-----------------#

func _apply_state_side_effects(state : GameState) -> void:
	var should_pause_tree := tree_paused_states.has(state)
	get_tree().paused = should_pause_tree

	if should_pause_tree and not was_paused_last_apply:
		game_paused.emit()
	elif not should_pause_tree and was_paused_last_apply:
		game_resumed.emit()
	was_paused_last_apply = should_pause_tree

	#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mouse_visible_states.has(state) else Input.MOUSE_MODE_CAPTURED


var was_paused_last_apply : bool = false
