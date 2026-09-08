extends VBoxContainer
## Settings panel UI: reads/writes audio, video, and control settings through
## SettingsManager. Owns its own controls entirely; only communicates upward
## via [signal back_requested] so MainMenu can pop the navigation stack.

signal back_requested()

@export_category("Audio References")
@export var master_slider : HSlider
@export var music_slider : HSlider
@export var sfx_slider : HSlider

@export_category("Video References")
@export var window_mode_option : OptionButton
@export var vsync_checkbox : CheckBox
@export var max_fps_spinbox : SpinBox

@export_category("Keybind References")
@export var keybind_list : VBoxContainer
## Scene for one keybind row, instantiated per remappable action. Must have a
## script exposing [code]setup(action : StringName, prompt_text : String)[/code]
## and a [code]rebind_requested(action : StringName)[/code] signal.
@export var keybind_row_scene : PackedScene

@export_category("Navigation")
@export var audio_button : Button
@export var audio_control : Container
@export var video_button : Button
@export var video_control : Container
@export var keybind_button : Button
@export var keybind_control : Container

@export var back_button : Button

@export_category("Debug")
@export var debug : bool = false

var _rebinding_action : StringName = &""


func _ready() -> void:
	back_button.pressed.connect(func(): back_requested.emit())

	master_slider.value_changed.connect(_on_slider_changed.bind(&"Master"))
	music_slider.value_changed.connect(_on_slider_changed.bind(&"Music"))
	sfx_slider.value_changed.connect(_on_slider_changed.bind(&"SFX"))

	window_mode_option.item_selected.connect(_on_window_mode_selected)
	vsync_checkbox.toggled.connect(_on_vsync_toggled)
	max_fps_spinbox.value_changed.connect(_on_max_fps_changed)

	SettingsManager.audio_bus_volume_changed.connect(_on_external_volume_changed)
	SettingsManager.video_settings_changed.connect(_sync_video_controls)
	SettingsManager.keybind_changed.connect(_on_external_keybind_changed)
	SettingsManager.keybind_conflict.connect(_on_keybind_conflict)
	
	audio_button.pressed.connect(_on_nav_button_pressed.bind(audio_button.name))
	video_button.pressed.connect(_on_nav_button_pressed.bind(video_button.name))
	keybind_button.pressed.connect(_on_nav_button_pressed.bind(keybind_button.name))

	_populate_window_mode_options()
	_populate_keybind_list()
	_sync_all_controls()


func _unhandled_input(event : InputEvent) -> void:
	if _rebinding_action == &"":
		return
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return

	SettingsManager.rebind_action(_rebinding_action, event)
	_rebinding_action = &""
	_rebinding_row = null
	get_viewport().set_input_as_handled()

#-----------------#
# Private Methods #
#-----------------#

func _sync_all_controls() -> void:
	master_slider.set_value_no_signal(SettingsManager.get_bus_volume(&"Master"))
	music_slider.set_value_no_signal(SettingsManager.get_bus_volume(&"Music"))
	sfx_slider.set_value_no_signal(SettingsManager.get_bus_volume(&"SFX"))
	_sync_video_controls()


func _sync_video_controls() -> void:
	window_mode_option.select(SettingsManager.get_window_mode())
	vsync_checkbox.set_pressed_no_signal(SettingsManager.get_vsync_enabled())
	max_fps_spinbox.set_value_no_signal(SettingsManager.get_max_fps())


func _populate_window_mode_options() -> void:
	window_mode_option.clear()
	window_mode_option.add_item("Windowed", SettingsManager.WindowMode.WINDOWED)
	window_mode_option.add_item("Fullscreen", SettingsManager.WindowMode.FULLSCREEN)
	window_mode_option.add_item("Borderless Windowed", SettingsManager.WindowMode.BORDERLESS_WINDOWED)


func _populate_keybind_list() -> void:
	for action in SettingsManager.get_remappable_actions():
		var row := keybind_row_scene.instantiate()
		keybind_list.add_child(row)
		row.setup(action, _display_name_for_events(SettingsManager.get_events_for_action(action)))
		row.rebind_requested.connect(_on_rebind_requested)


func _display_name_for_events(events : Array[InputEvent]) -> String:
	if events.is_empty():
		return "Unbound"
	return events[0].as_text()


func _on_slider_changed(value : float, bus_name : StringName) -> void:
	SettingsManager.set_bus_volume(bus_name, value)


func _on_window_mode_selected(index : int) -> void:
	SettingsManager.set_window_mode(window_mode_option.get_item_id(index) as SettingsManager.WindowMode)


func _on_vsync_toggled(enabled : bool) -> void:
	SettingsManager.set_vsync_enabled(enabled)


func _on_max_fps_changed(value : float) -> void:
	SettingsManager.set_max_fps(int(value))


# SettingsContainer — replace _on_rebind_requested and _on_external_keybind_changed

var _rebinding_row : Node


func _on_rebind_requested(action : StringName) -> void:
	if _rebinding_row != null:
		_rebinding_row.set_listening(false)

	if debug: print("SettingsContainer: waiting for input to rebind '%s'" % action)
	_rebinding_action = action
	_rebinding_row = _find_row_for_action(action)
	if _rebinding_row != null:
		_rebinding_row.set_listening(true)


func _find_row_for_action(target_action : StringName) -> Node:
	for row in keybind_list.get_children():
		if row.action == target_action:
			return row
	return null


func _on_external_keybind_changed(changed_action : StringName, events : Array[InputEvent]) -> void:
	var row := _find_row_for_action(changed_action)
	if row != null:
		row.refresh(_display_name_for_events(events))


func _on_external_volume_changed(bus_name : StringName, _old_volume : float, new_volume : float) -> void:
	match bus_name:
		&"Master": master_slider.set_value_no_signal(new_volume)
		&"Music": music_slider.set_value_no_signal(new_volume)
		&"SFX": sfx_slider.set_value_no_signal(new_volume)


func _on_keybind_conflict(action : StringName, conflicting_action : StringName, _event : InputEvent) -> void:
	push_warning("SettingsContainer: '%s' conflicts with '%s'" % [action, conflicting_action])
	# Hook a toast/dialog here if you want the conflict surfaced in the UI.

func _on_nav_button_pressed(name : StringName) -> void:
	audio_control.hide()
	video_control.hide()
	keybind_control.hide()
	
	match name:
		&'AudioButton':
			audio_control.show()
		&'VideoButton':
			video_control.show()
		&'KeybindButton':
			keybind_control.show()
