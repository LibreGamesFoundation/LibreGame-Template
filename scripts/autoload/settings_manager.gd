extends Node
## Global manager for audio, video, and control settings.
##
## Autoloaded as [code]SettingsManager[/code]. Owns a single [SaveableComponent]
## (persistent, category "settings") so [code]SaveManager[/code] persists this
## data to [member SaveManager.settings_directory], shared across all save slots
## and unaffected by [method SaveManager.delete_save].

signal audio_bus_volume_changed(bus_name : StringName, old_volume : float, new_volume : float)
signal video_settings_changed()
signal keybind_changed(action : StringName, events : Array[InputEvent])
signal keybind_conflict(action : StringName, conflicting_action : StringName, event : InputEvent)
signal settings_applied()
signal settings_reset()

enum WindowMode {
	WINDOWED,
	FULLSCREEN,
	BORDERLESS_WINDOWED,
}

@export_category("Audio Settings")
## Buses exposed to the settings system. Each is saved/loaded and controllable
## via [method set_bus_volume]. Must match bus names configured in the Audio bus layout.
@export var audio_buses : Array[StringName] = [&"Master", &"Music", &"SFX"]
@export_range(0.0, 1.0, 0.01) var default_bus_volume : float = 1.0

@export_category("Video Settings")
@export var default_window_mode : WindowMode = WindowMode.WINDOWED
@export var default_vsync_enabled : bool = true
## 0 disables the frame rate cap.
@export var default_max_fps : int = 60

@export_category("Control Settings")
## Action name prefixes excluded from [method get_remappable_actions]
## (built-in UI actions by default).
@export var excluded_action_prefixes : Array[String] = ["ui_"]

@export_category("Debug")
@export var debug : bool = false

var _bus_volumes : Dictionary = {}
var _window_mode : WindowMode
var _vsync_enabled : bool
var _max_fps : int
var _default_bindings : Dictionary = {}
var _saveable : SaveComponent


func _ready() -> void:
	# Snapshot defaults BEFORE anything (including a loaded save) can change them.
	_capture_default_bindings()
	_window_mode = default_window_mode
	_vsync_enabled = default_vsync_enabled
	_max_fps = default_max_fps
	for bus_name in audio_buses:
		_bus_volumes[bus_name] = default_bus_volume

	_saveable = SaveComponent.new()
	_saveable.target = self
	_saveable.save_id = "settings_manager"
	_saveable.save_category = &"settings"
	_saveable.persistent = true
	add_child(_saveable)

	apply_all_settings()
	load_and_apply()

#----------------#
# Public Methods #
#----------------#

## Loads persisted settings via [code]SaveManager[/code] and applies them. If no
## settings file exists yet (first launch), current defaults remain applied.
func load_and_apply() -> void:
	SaveManager.load_settings()


## Re-applies all current in-memory settings to the engine. Useful after changing
## values without going through the setters, or to force a re-apply.
func apply_all_settings() -> void:
	for bus_name in audio_buses:
		set_bus_volume(bus_name, _bus_volumes.get(bus_name, default_bus_volume))
	_apply_video_settings()


## Applies all current settings and immediately persists them. Convenience for
## an "Apply" button in a settings menu.
func apply_and_save() -> void:
	apply_all_settings()
	SaveManager.save_settings()


# --- Audio ---

## Sets [param bus_name]'s volume (linear 0.0–1.0) and applies it immediately.
func set_bus_volume(bus_name : StringName, linear_volume : float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("SettingsManager: no audio bus named '%s'." % bus_name)
		return

	linear_volume = clamp(linear_volume, 0.0, 1.0)
	var old_volume : float = _bus_volumes.get(bus_name, default_bus_volume)

	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_volume))
	AudioServer.set_bus_mute(bus_index, is_zero_approx(linear_volume))
	_bus_volumes[bus_name] = linear_volume

	if debug: print("SettingsManager: bus '%s' volume %.2f -> %.2f" % [bus_name, old_volume, linear_volume])
	audio_bus_volume_changed.emit(bus_name, old_volume, linear_volume)


## Returns the current linear volume (0.0–1.0) for [param bus_name].
func get_bus_volume(bus_name : StringName) -> float:
	return _bus_volumes.get(bus_name, default_bus_volume)


# --- Video ---

func set_window_mode(mode : WindowMode) -> void:
	_window_mode = mode
	_apply_video_settings()


func set_vsync_enabled(enabled : bool) -> void:
	_vsync_enabled = enabled
	_apply_video_settings()


## [param fps] of 0 disables the cap.
func set_max_fps(fps : int) -> void:
	_max_fps = max(fps, 0)
	_apply_video_settings()


func get_window_mode() -> WindowMode:
	return _window_mode

func get_vsync_enabled() -> bool:
	return _vsync_enabled

func get_max_fps() -> int:
	return _max_fps


# --- Controls ---

## Returns all remappable action names (excludes [member excluded_action_prefixes]).
func get_remappable_actions() -> Array[StringName]:
	var actions : Array[StringName] = []
	for action in InputMap.get_actions():
		var excluded := false
		for prefix in excluded_action_prefixes:
			if String(action).begins_with(prefix):
				excluded = true
				break
		if not excluded:
			actions.append(action)
	return actions


## Returns the [InputEvent]s currently bound to [param action].
func get_events_for_action(action : StringName) -> Array[InputEvent]:
	return InputMap.action_get_events(action)


## Rebinds [param action]'s event at [param slot_index] to [param new_event]. If
## [param slot_index] is beyond the current event count, [param new_event] is
## appended. Returns false (and emits [signal keybind_conflict]) if [param new_event]
## is already bound to a different action, unless [param allow_conflict] is true.
func rebind_action(action : StringName, new_event : InputEvent, slot_index : int = 0, allow_conflict : bool = false) -> bool:
	if not allow_conflict:
		var conflicting_action := _find_conflicting_action(new_event, action)
		if conflicting_action != &"":
			if debug: print("SettingsManager: rebind of '%s' conflicts with '%s'" % [action, conflicting_action])
			keybind_conflict.emit(action, conflicting_action, new_event)
			return false

	var events := InputMap.action_get_events(action)
	if slot_index < events.size():
		InputMap.action_erase_event(action, events[slot_index])
	InputMap.action_add_event(action, new_event)

	if debug: print("SettingsManager: rebound '%s' slot %d" % [action, slot_index])
	keybind_changed.emit(action, InputMap.action_get_events(action))
	return true


## Restores [param action]'s bindings to their project-default events.
func reset_action_to_default(action : StringName) -> void:
	if not _default_bindings.has(action):
		return

	InputMap.action_erase_events(action)
	for event in _default_bindings[action]:
		InputMap.action_add_event(action, event)

	if debug: print("SettingsManager: reset '%s' to default bindings" % action)
	keybind_changed.emit(action, InputMap.action_get_events(action))


## Restores every remappable action to its project-default bindings.
func reset_all_keybinds_to_default() -> void:
	for action in get_remappable_actions():
		reset_action_to_default(action)


## Resets audio, video, and control settings to their defaults and applies them.
func reset_all_to_defaults() -> void:
	for bus_name in audio_buses:
		set_bus_volume(bus_name, default_bus_volume)
	_window_mode = default_window_mode
	_vsync_enabled = default_vsync_enabled
	_max_fps = default_max_fps
	_apply_video_settings()
	reset_all_keybinds_to_default()

	if debug: print("SettingsManager: reset all settings to defaults")
	settings_reset.emit()


# --- SaveableComponent target contract ---
# These two are called by SaveableComponent, not meant to be called directly.

func get_save_data() -> Dictionary:
	var audio_out : Dictionary = {}
	for bus_name in _bus_volumes.keys():
		audio_out[String(bus_name)] = _bus_volumes[bus_name]

	return {
		"audio": audio_out,
		"video": {
			"window_mode": _window_mode,
			"vsync_enabled": _vsync_enabled,
			"max_fps": _max_fps,
		},
		"controls": _serialize_all_bindings(),
	}


func load_save_data(data : Dictionary) -> void:
	var audio_data : Dictionary = data.get("audio", {})
	for bus_name in audio_buses:
		set_bus_volume(bus_name, audio_data.get(String(bus_name), default_bus_volume))

	var video_data : Dictionary = data.get("video", {})
	_window_mode = video_data.get("window_mode", default_window_mode)
	_vsync_enabled = video_data.get("vsync_enabled", default_vsync_enabled)
	_max_fps = video_data.get("max_fps", default_max_fps)
	_apply_video_settings()

	_deserialize_all_bindings(data.get("controls", {}))

	if debug: print("SettingsManager: loaded and applied saved settings")
	settings_applied.emit()

#-----------------#
# Private Methods #
#-----------------#

func _apply_video_settings() -> void:
	match _window_mode:
		WindowMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.BORDERLESS_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if _vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = _max_fps

	if debug: print("SettingsManager: applied video (mode %s, vsync %s, max_fps %d)" % [WindowMode.keys()[_window_mode], _vsync_enabled, _max_fps])
	video_settings_changed.emit()


func _capture_default_bindings() -> void:
	for action in InputMap.get_actions():
		_default_bindings[action] = InputMap.action_get_events(action).duplicate()


func _find_conflicting_action(event : InputEvent, ignore_action : StringName) -> StringName:
	for action in get_remappable_actions():
		if action == ignore_action:
			continue
		for existing_event in InputMap.action_get_events(action):
			if _events_conflict(existing_event, event):
				return action
	return &""


func _events_conflict(a : InputEvent, b : InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode and a.physical_keycode != KEY_NONE
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis
	return false


func _serialize_all_bindings() -> Dictionary:
	var serialized : Dictionary = {}
	for action in get_remappable_actions():
		var events_data : Array = []
		for event in InputMap.action_get_events(action):
			var event_data := _serialize_input_event(event)
			if not event_data.is_empty():
				events_data.append(event_data)
		serialized[String(action)] = events_data
	return serialized


func _deserialize_all_bindings(data : Dictionary) -> void:
	for action_key in data.keys():
		var action := StringName(action_key)
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event_data in data[action_key]:
			var event := _deserialize_input_event(event_data)
			if event != null:
				InputMap.action_add_event(action, event)
		keybind_changed.emit(action, InputMap.action_get_events(action))


func _serialize_input_event(event : InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "physical_keycode": event.physical_keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse_button", "button_index": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button_index": event.button_index}
	if event is InputEventJoypadMotion:
		return {"type": "joy_motion", "axis": event.axis, "axis_value": event.axis_value}
	# Unsupported event type — extend this method to serialize additional types.
	return {}


func _deserialize_input_event(data : Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			var event := InputEventKey.new()
			event.physical_keycode = data.get("physical_keycode", KEY_NONE)
			return event
		"mouse_button":
			var event := InputEventMouseButton.new()
			event.button_index = data.get("button_index", MOUSE_BUTTON_NONE)
			return event
		"joy_button":
			var event := InputEventJoypadButton.new()
			event.button_index = data.get("button_index", 0)
			return event
		"joy_motion":
			var event := InputEventJoypadMotion.new()
			event.axis = data.get("axis", 0)
			event.axis_value = data.get("axis_value", 1.0)
			return event
	return null
