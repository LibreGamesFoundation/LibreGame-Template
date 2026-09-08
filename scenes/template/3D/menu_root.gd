extends Control
## Main menu controller. Manages switching between sibling menu Containers
## (Main, Settings, Credits, etc.) under [member menu_container], with a
## navigation stack for back buttons and [code]ui_cancel[/code] support.

@export_category("References")
@export var menu_container : Container
@export var initial_menu_name : StringName = &"MainContainer"

@export_category("Scene Targets")
@export var play_scene_path : String = "res://scenes/template/3D/world_3d.tscn"

@export_category("Debug")
@export var debug : bool = false

var _menus : Dictionary = {}
var _menu_stack : Array[Container] = []
var _current_menu : Container


func _ready() -> void:
	_register_menus()
	_connect_all_buttons()

	for menu_name in _menus:
		_menus[menu_name].visible = false

	if _menus.has(initial_menu_name):
		show_menu(initial_menu_name)
	else:
		push_error("MainMenu: initial_menu_name '%s' not found under menu_container." % initial_menu_name)


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _menu_stack.size() > 1:
		go_back()
		get_viewport().set_input_as_handled()

#----------------#
# Public Methods #
#----------------#

## Shows the menu registered under [param menu_name], hiding the current one,
## and pushes it onto the navigation stack (for [method go_back]).
func show_menu(menu_name : StringName) -> void:
	if not _menus.has(menu_name):
		push_error("MainMenu: no menu named '%s'." % menu_name)
		return

	var new_menu : Container = _menus[menu_name]
	if new_menu == _current_menu:
		return

	if _current_menu != null:
		_current_menu.visible = false

	new_menu.visible = true
	_current_menu = new_menu
	_menu_stack.append(new_menu)
	_focus_first_button(new_menu)

	if debug: print("MainMenu: showing '%s' (stack depth %d)" % [menu_name, _menu_stack.size()])


## Pops the navigation stack and shows the previous menu. No-ops if there's
## nowhere to go back to.
func go_back() -> void:
	if _menu_stack.size() <= 1:
		return

	_menu_stack.pop_back()
	var previous_menu : Container = _menu_stack.back()

	_current_menu.visible = false
	previous_menu.visible = true
	_current_menu = previous_menu
	_focus_first_button(previous_menu)

	if debug: print("MainMenu: back to '%s' (stack depth %d)" % [previous_menu.name, _menu_stack.size()])

#-----------------#
# Private Methods #
#-----------------#

func _register_menus() -> void:
	for child in menu_container.get_children():
		if child is Container:
			_menus[StringName(child.name)] = child
		else:
			if debug: print("MainMenu: skipping non-Container child '%s'" % child.name)


func _connect_all_buttons() -> void:
	for menu_name in _menus:
		var menu : Container = _menus[menu_name]
		if menu.get_script() != null:
			_connect_panel_signals(menu)
		else:
			_connect_buttons_recursive(menu)


func _connect_panel_signals(panel : Container) -> void:
	if panel.has_signal("back_requested"):
		panel.back_requested.connect(go_back)


func _connect_buttons_recursive(node : Node) -> void:
	for child in node.get_children():
		if child is Button:
			child.pressed.connect(_on_button_pressed.bind(child.name))
		if child.get_child_count() > 0:
			_connect_buttons_recursive(child)


func _focus_first_button(menu : Container) -> void:
	for child in menu.get_children():
		if child is Button:
			child.grab_focus()
			return
		if child is Container:
			_focus_first_button(child)
			return


func _on_button_pressed(button_name : String) -> void:
	if debug: print("MainMenu: '%s' pressed" % button_name)

	match button_name:
		"PlayButton":
			_play_button()
		"QuitButton":
			_quit_button()
		"SettingsButton":
			show_menu(&"SettingsContainer")
		"CreditsButton":
			show_menu(&"CreditsContainer")
		"BackButton":
			go_back()
		_:
			push_warning("MainMenu: unhandled button '%s'" % button_name)


func _play_button() -> void:
	SceneManager.change_scene(play_scene_path, {}, GamestateManager.GameState.PLAYING)


func _quit_button() -> void:
	get_tree().quit()
