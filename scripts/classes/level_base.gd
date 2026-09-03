class_name Level3D
extends Component3D

@export var player_spawn_point : Marker3D

#----------------#
# Public Methods #
#----------------#

func get_player_spawn_position() -> Vector3:
	if player_spawn_point == null:
		push_error("Player Spawn Point Does Not Exist")
		return Vector3(0, 0, 0)
	
	return player_spawn_point.global_position
