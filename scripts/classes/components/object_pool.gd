@icon("res://assets/components/ObjectPoolNode.svg")
class_name ObjectPool
extends ComponentBase
## Generic object pool for reusing scene instances instead of instantiate()/queue_free().
##
## Pooled scenes should include a [PoolableComponent] on their root (preferred), or
## implement [code]_on_pool_acquire()[/code]/[code]_on_pool_release()[/code] directly
## as a fallback for non-component-based scenes.
##
## @experimental

signal pool_exhausted()
signal pool_grew(new_size : int)

@export_category("Pool Configuration")
@export var pooled_scene : PackedScene
@export var initial_size : int = 20
## If true, a new instance is created when the pool is empty and [method acquire] is called.
## If false, [method acquire] returns null instead.
@export var allow_growth : bool = true

var _available : Array[Node] = []
var _active : Array[Node] = []


func _ready() -> void:
	for i in initial_size:
		_available.append(_create_instance())

	if debug: print("%s: pool warmed with %d instances" % [name, initial_size])

#----------------#
# Public Methods #
#----------------#

## Retrieves an instance from the pool, activating it. Returns null if the pool is
## empty and [member allow_growth] is false.
func acquire() -> Node:
	var instance : Node

	if _available.is_empty():
		if not allow_growth:
			if debug: print("%s: pool exhausted, growth disabled" % name)
			pool_exhausted.emit()
			return null
		instance = _create_instance()
		pool_grew.emit(_active.size() + _available.size() + 1)

	else:
		instance = _available.pop_back()

	_active.append(instance)
	_notify_lifecycle(instance, "acquire")

	if debug: print("%s: acquired instance (%d active, %d available)" % [name, _active.size(), _available.size()])

	return instance


## Returns an instance to the pool, deactivating it.
func release(instance : Node) -> void:
	if not _active.has(instance):
		if debug: print("%s: attempted to release an instance not owned by this pool" % name)
		return

	_active.erase(instance)
	_available.append(instance)
	_notify_lifecycle(instance, "release")

	if debug: print("%s: released instance (%d active, %d available)" % [name, _active.size(), _available.size()])

#-----------------#
# Private Methods #
#-----------------#

func _create_instance() -> Node:
	var instance := pooled_scene.instantiate()
	add_child(instance)
	_notify_lifecycle(instance, "release")  # start deactivated
	return instance


func _notify_lifecycle(instance : Node, phase : String) -> void:
	var poolable := _find_poolable_component(instance)
	var method_name := "on_pool_acquire" if phase == "acquire" else "on_pool_release"
	var fallback_method_name := "_on_pool_acquire" if phase == "acquire" else "_on_pool_release"

	if poolable != null:
		poolable.call(method_name)
	elif instance.has_method(fallback_method_name):
		instance.call(fallback_method_name)


func _find_poolable_component(instance : Node) -> PoolableComponent:
	for child in instance.get_children():
		if child is PoolableComponent:
			return child
	return null
