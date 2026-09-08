@icon("res://assets/components/Level3DNode.svg")
class_name Level3D
extends Component3D

@export var player_scene : PackedScene
@export var player_spawn_point : Marker3D

# In the new scene's _ready()
func _ready() -> void:
	var params := SceneManager.take_params()
	_init_player()


#----------------#
# Public Methods #
#----------------#

func get_player_spawn_position() -> Vector3:
	if player_spawn_point == null:
		push_error("Player Spawn Point Does Not Exist")
		return Vector3(0, 0, 0)
	
	return player_spawn_point.global_position

#-----------------#
# Private Methods #
#-----------------#

func _init_player() -> void:
	var player : PlayerCharacter3D = player_scene.instantiate()
	add_child(player)
	player.global_position = get_player_spawn_position()
