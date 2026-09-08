extends Control

@export var debug : bool = false
@onready var container_container : Container = %MarginContainer

func _ready() -> void:
	var containers = container_container.get_children() as Array[Container]
	for container in containers:
		for element in container.get_children():
			if element is Button:
				element.pressed.connect(_on_button_pressed.bind(element.name))


func _on_button_pressed(button_name : String) -> void:
	match button_name:
		"PlayButton":
			_play_button()
		"QuitButton":
			_quit_button()


func _play_button() -> void:
	SceneManager.change_scene("res://scenes/template/3D/world_3d.tscn", {}, GamestateManager.GameState.PLAYING)


func _quit_button() -> void:
	get_tree().quit()
