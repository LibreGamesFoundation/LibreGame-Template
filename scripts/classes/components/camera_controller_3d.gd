class_name CameraController
extends Component3D
## Drives camera rotation, headbob, and held item sway from analog look input.
##
## Requires an [AnalogCaptureComponent] for input and a [PlayerCharacter3D] to
## forward yaw rotation to. Held item sway is exposed via [method get_held_item_sway]
## for a held item holder node to consume.
##

signal tilt_limit_reached(at_upper_limit : bool)
signal footstep()

@export_category("References")
@export var player_controller : PlayerCharacter3D
@export var analog_component : AnalogCaptureComponent

@export_category("Camera Settings")
@export_group("Camera Tilt")
@export_range(-90, 0) var tilt_lower_limit : int = -90
@export_range(0, 90) var tilt_upper_limit : int = 90

@export_group("Headbob")
@export var headbob_enabled : bool = true
## Overall multiplier applied to all headbob values below — the fastest way to
## tune bob strength without touching each value individually.
@export_range(0.0, 1.0, 0.05) var headbob_intensity : float = 0.3
@export_range(0.0, 0.1, 0.001) var bob_pitch : float = 0.015
@export_range(0.0, 0.1, 0.001) var bob_roll : float = 0.008
@export_range(0.0, 0.04, 0.001) var bob_up : float = 0.0025
@export_range(3.0, 8.0, 0.1) var bob_frequency : float = 5.0
## Minimum horizontal speed (units/sec) on [member player_controller] before
## headbob is applied, to avoid bobbing from tiny physics jitter while idle.
@export var bob_speed_threshold : float = 0.1

@export_group("Held Item Sway")
@export var held_item_sway_enabled : bool = true
@export_range(0.0, 0.05, 0.001) var sway_amount : float = 0.01
@export_range(1.0, 20.0, 0.5) var sway_smoothing : float = 8.0

var _rotation : Vector3
var _step_timer : float = 0.0
var _bob_offset : Vector3 = Vector3.ZERO
var _bob_rotation : Vector3 = Vector3.ZERO
var _sway_target : Vector2 = Vector2.ZERO
var _sway_current : Vector2 = Vector2.ZERO
var _base_transform_origin : Vector3


func _ready() -> void:
	_base_transform_origin = transform.origin


func _process(delta : float) -> void:
	var input := analog_component.consume_input()
	update_camera_rotation(input)

	if headbob_enabled:
		_update_headbob(delta)

	if held_item_sway_enabled:
		_update_held_item_sway(input, delta)

	transform.origin = _base_transform_origin + _bob_offset

#----------------#
# Public Methods #
#----------------#

func update_camera_rotation(input : Vector2) -> void:
	_rotation.x += input.y
	_rotation.y += input.x

	var clamped_x : float = clamp(_rotation.x, deg_to_rad(tilt_lower_limit), deg_to_rad(tilt_upper_limit))
	if not is_equal_approx(clamped_x, _rotation.x):
		tilt_limit_reached.emit(clamped_x < _rotation.x)
	_rotation.x = clamped_x

	player_controller.update_rotation(Vector3(0.0, _rotation.y, 0.0))
	transform.basis = Basis.from_euler(Vector3(_rotation.x, 0.0, 0.0) + _bob_rotation)
	_rotation.z = 0.0


## Returns the current smoothed held_item sway offset for a held_item holder node to
## apply to its own local transform. Does not clear/consume state, unlike
## [method AnalogCaptureComponent.consume_input], since sway is continuous rather
## than accumulated per-frame.
func get_held_item_sway() -> Vector2:
	return _sway_current

#-----------------#
# Private Methods #
#-----------------#

func _update_headbob(delta : float) -> void:
	var horizontal_speed := Vector3(player_controller.velocity.x, 0.0, player_controller.velocity.z).length()
	var is_moving := horizontal_speed > bob_speed_threshold and player_controller.is_on_floor()

	if not is_moving:
		_step_timer = 0.0
		_bob_offset = _bob_offset.lerp(Vector3.ZERO, 8.0 * delta)
		_bob_rotation = _bob_rotation.lerp(Vector3.ZERO, 8.0 * delta)
		return

	var previous_step_timer := _step_timer
	_step_timer += delta * bob_frequency

	_bob_offset.y = sin(_step_timer) * bob_up * headbob_intensity
	_bob_rotation.x = sin(_step_timer * 2.0) * bob_pitch * headbob_intensity
	_bob_rotation.z = cos(_step_timer) * bob_roll * headbob_intensity

	# Emit a footstep once per half-cycle (each foot's contact point).
	if int(_step_timer / PI) != int(previous_step_timer / PI):
		if debug: print("%s: footstep" % name)
		footstep.emit()


func _update_held_item_sway(input : Vector2, delta : float) -> void:
	_sway_target = -input * sway_amount
	_sway_current = _sway_current.lerp(_sway_target, sway_smoothing * delta)
