@icon("res://assets/components/AnalogCaptureComponentNode.svg")
class_name AnalogCaptureComponent
extends ComponentBase
## Used for getting mouse and joystick movement.
##
## Designed to be used with a CameraController. Call [method consume_input] once per
## frame to retrieve and clear accumulated look input.
##

signal mouse_mode_changed(old_mode : Input.MouseMode, new_mode : Input.MouseMode)
signal vibration_started()
signal vibration_finished()

@export_category("Mouse Capture Settings")
@export var current_mouse_mode : Input.MouseMode = Input.MOUSE_MODE_CAPTURED
@export var mouse_sensitivity : float = 0.005
@export var mouse_sensitivity_divisor : float = 5.0
@export var mouse_visible_states : Array[GamestateManager.GameState] = [GamestateManager.GameState.MENU, GamestateManager.GameState.PAUSED]
@export var mouse_capture_states : Array[GamestateManager.GameState] = [GamestateManager.GameState.PLAYING]

@export_category("Joypad Capture Settings")
@export var joy_sensitivity : float = 0.05
## Minimum stick displacement (0.0 to 1.0) required before joypad input registers,
## to avoid drift from imprecise sticks.
@export_range(0.0, 1.0, 0.01) var joy_deadzone : float = 0.2

@export_category("Look Settings")
## Inverts horizontal look input for both mouse and joypad.
@export var invert_look_x : bool = false
## Inverts vertical look input for both mouse and joypad.
@export var invert_look_y : bool = false

@export_category("Controller Vibration Settings")
## Device index passed to [method Input.start_joy_vibration]. 0 is the first connected controller.
@export var vibration_device : int = 0
@export_range(0.0, 1.0) var vibration_weak_magnitude : float = 0.5
@export_range(0.0, 1.0) var vibration_strong_magnitude : float = 0.5
@export var vibration_duration : float = 0.2

var _mouse_input : Vector2
var _joy_input : Vector2


func _ready() -> void:
	Input.mouse_mode = current_mouse_mode
	GamestateManager.game_state_changed.connect(_on_game_state_changed)

	# Sync immediately to the manager's current state rather than waiting for
	# the next transition, so mouse mode is correct from the first frame.
	_on_game_state_changed(GamestateManager.current_state, GamestateManager.current_state)


func _physics_process(_delta : float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_joy_input = Vector2.ZERO
		return

	var joy_x := Input.get_axis("joy_look_right", "joy_look_left")
	var joy_y := Input.get_axis("joy_look_up", "joy_look_down")
	var joy_vector := _apply_deadzone(Vector2(joy_x, joy_y), joy_deadzone)

	_joy_input = joy_vector * joy_sensitivity * _get_invert_multiplier()


func _unhandled_input(event : InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_mouse_input += -motion.screen_relative * (mouse_sensitivity / mouse_sensitivity_divisor) * _get_invert_multiplier()

	if debug:
		print(_mouse_input)

#----------------#
# Public Methods #
#----------------#

## Returns and clears the accumulated look input for this frame.
func consume_input() -> Vector2:
	var input := _mouse_input + _joy_input
	_mouse_input = Vector2.ZERO
	_joy_input = Vector2.ZERO
	return input


## Sets [member current_mouse_mode] and applies it to [member Input.mouse_mode].
func set_mouse_capture_mode(new_mode : Input.MouseMode) -> void:
	if new_mode == current_mouse_mode:
		return
	if debug: print("%s: mouse mode %s -> %s" % [name, current_mouse_mode, new_mode])
	mouse_mode_changed.emit(current_mouse_mode, new_mode)
	current_mouse_mode = new_mode
	Input.mouse_mode = new_mode


## Convenience toggle between [constant Input.MOUSE_MODE_CAPTURED] and
## [constant Input.MOUSE_MODE_VISIBLE], e.g. for pause menus.
func toggle_mouse_capture() -> void:
	if current_mouse_mode == Input.MOUSE_MODE_CAPTURED:
		set_mouse_capture_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		set_mouse_capture_mode(Input.MOUSE_MODE_CAPTURED)


## Plays controller vibration on [member vibration_device]. Any parameter left at -1.0
## falls back to the corresponding exported default.
func play_controller_vibration(weak_magnitude : float = -1.0, strong_magnitude : float = -1.0, duration : float = -1.0) -> void:
	var weak := vibration_weak_magnitude if weak_magnitude < 0.0 else weak_magnitude
	var strong := vibration_strong_magnitude if strong_magnitude < 0.0 else strong_magnitude
	var length := vibration_duration if duration < 0.0 else duration

	Input.start_joy_vibration(vibration_device, weak, strong, length)
	if debug: print("%s: vibration started (weak %.2f, strong %.2f, %.2fs)" % [name, weak, strong, length])
	vibration_started.emit()


## Immediately stops vibration on [member vibration_device].
func stop_controller_vibration() -> void:
	Input.stop_joy_vibration(vibration_device)
	if debug: print("%s: vibration stopped" % name)
	vibration_finished.emit()

#-----------------#
# Private Methods #
#-----------------#

func _apply_deadzone(vector : Vector2, deadzone : float) -> Vector2:
	if vector.length() < deadzone:
		return Vector2.ZERO
	return vector


func _get_invert_multiplier() -> Vector2:
	return Vector2(
		-1.0 if invert_look_x else 1.0,
		-1.0 if invert_look_y else 1.0
	)


func _on_game_state_changed(_previous_state : GamestateManager.GameState, new_state : GamestateManager.GameState) -> void:
	# mouse_visible_states takes precedence if a state is misconfigured into both arrays.
	if mouse_visible_states.has(new_state):
		set_mouse_capture_mode(Input.MOUSE_MODE_VISIBLE)
	elif mouse_capture_states.has(new_state):
		set_mouse_capture_mode(Input.MOUSE_MODE_CAPTURED)
