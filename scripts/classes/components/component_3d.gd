@icon("res://assets/components/Component3DNode.svg")
class_name Component3D
extends Node3D

## Base for all Components that exist within 3D Space.
##
## Contains the most universal variables for all components.
##

@export var debug : bool = false
@export var target : Node
@export var initial_position : Vector3
