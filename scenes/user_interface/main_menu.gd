extends Control


func _ready() -> void:
	%QuitButton.pressed.connect(quit_game)

func quit_game() -> void:
	get_tree().quit()
