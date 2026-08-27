@icon("res://assets/components/PoolableComponentNode.svg")
class_name PoolableComponent
extends ComponentBase
## Handles activation/deactivation lifecycle for a node managed by an [ObjectPool].
##
## Attach to any pooled scene alongside a [member target] (inherited from [ComponentBase])
## pointing at the node to activate/deactivate — typically the scene's root.
##
## @experimental

signal pool_acquired()
signal pool_released()

@export_category("Pool Behavior")
## Toggles [member target].visible on acquire/release, if [member target] has the property.
@export var toggle_visibility : bool = true
## Toggles physics processing on [member target] via [method Node.set_physics_process].
@export var toggle_physics_process : bool = true
## Toggles [code]monitoring[/code]/[code]monitorable[/code] on [member target] if it's an
## [Area2D]/[Area3D]. Ignored for other node types.
@export var toggle_area_monitoring : bool = true
## If true, [member target] is moved to [member release_position] when released,
## keeping inactive instances out of the play space.
@export var move_on_release : bool = true
@export var release_position : Vector3 = Vector3(0.0, -1000.0, 0.0)

func _ready() -> void:
	if !target:
		push_warning("No Target Selected, falling back to parent")
		target = get_parent()

#----------------#
# Public Methods #
#----------------#

## Called by [ObjectPool] when this instance is handed out. Activates [member target]
## according to the exported toggles.
func on_pool_acquire() -> void:
	if target == null:
		push_warning("%s: PoolableComponent has no target assigned." % name)
		return

	if toggle_visibility and "visible" in target:
		target.visible = true

	if toggle_physics_process and target.has_method("set_physics_process"):
		target.set_physics_process(true)

	if toggle_area_monitoring and (target is Area2D or target is Area3D):
		target.monitoring = true
		target.monitorable = true

	if debug: print("%s: acquired from pool" % name)
	pool_acquired.emit()


## Called by [ObjectPool] on creation and when this instance is returned. Deactivates
## [member target] according to the exported toggles.
func on_pool_release() -> void:
	if target == null:
		push_warning("%s: PoolableComponent has no target assigned." % name)
		return

	if toggle_visibility and "visible" in target:
		target.visible = false

	if toggle_physics_process and target.has_method("set_physics_process"):
		target.set_physics_process(false)

	if toggle_area_monitoring and (target is Area2D or target is Area3D):
		target.monitoring = false
		target.monitorable = false

	if move_on_release and "global_position" in target:
		target.global_position = release_position

	if debug: print("%s: released to pool" % name)
	pool_released.emit()
