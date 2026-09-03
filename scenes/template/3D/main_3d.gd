extends Node

@export var player_scene : PackedScene

# Game World Root Nodes
@onready var level_root : Node3D = %LevelRoot
@onready var entity_root : Node3D = %EntityRoot

# UI Root Nodes
@onready var menu_root : Control = %MenuRoot
@onready var pause_root : Control = %PauseRoot
@onready var transition_root : Control = %TransitionRoot
@onready var debug_root : Control = %DebugRoot

func _ready() -> void:
	_init_level()
	#_init_player()

#-----------------#
# Private Methods #
#-----------------#

func _init_player() -> void:
	if player_scene == null:
		push_error("Player Scene Invalid: " + str(player_scene))
		return
	
	var player_node : PlayerCharacter3D = player_scene.instantiate()
	if player_node == null:
		push_error("Could not load player scene: " + str(player_scene))
		return
	
	entity_root.add_child(player_node)

func _init_level() -> void:
	pass
