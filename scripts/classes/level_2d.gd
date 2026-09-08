@icon("res://assets/components/Level2DNode.svg")
class_name Level2D
extends Component2D

@export var player_spawn_point : Marker2D

# In the new scene's _ready()
func _ready() -> void:
	var params := SceneManager.take_params()


#----------------#
# Public Methods #
#----------------#

func get_player_spawn_position() -> Vector2:
	if player_spawn_point == null:
		push_error("Player Spawn Point Does Not Exist")
		return Vector2(0, 0)
	
	return player_spawn_point.global_position
