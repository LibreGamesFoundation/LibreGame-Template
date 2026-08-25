@icon("res://assets/components/ComponentNode.svg")
class_name ComponentBase
extends Node

## Base for all Components that exist outside of 2D or 3D Space.
##
## Contains the most universal variables for all components.
##

@export var debug : bool = false
@export var target : Node
