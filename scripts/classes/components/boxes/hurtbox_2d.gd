@icon("res://assets/components/Hurtbox2DNode.svg")
class_name Hurtbox2D
extends Area2D
## Receives hits from any [Hitbox2D] it overlaps and forwards damage to [member target].
##
## Automatically added to the "hurtbox" group so [Hitbox2D] can detect it without a
## direct type dependency. Configure collision layers/masks in the editor.
##
## @experimental

signal hit_received(hitbox : Hitbox2D, damage_amount : float, damage_type : Hitbox2D.DamageType)
signal invincibility_started()
signal invincibility_finished()

@export_category("Hurtbox Settings")
## Node that receives damage. If it has a [code]change_current_resource_quantity(amount)[/code]
## method (e.g. a [ResourceComponent]), it will be called automatically on hit.
@export var target : Node
@export var damage_multiplier : float = 1.0
## If true, all hits are ignored regardless of [member invincibility_duration].
@export var invincible : bool = false
## Seconds of automatic invincibility applied after receiving a hit. Set to 0.0 to disable.
@export var invincibility_duration : float = 0.0

@export_category("Debug")
@export var debug : bool = false

var _invincibility_timer : float = 0.0
var _auto_invincible : bool = false

func _ready() -> void:
	add_to_group("hurtbox")


func _physics_process(delta : float) -> void:
	if not _auto_invincible:
		return

	_invincibility_timer -= delta
	if _invincibility_timer <= 0.0:
		_auto_invincible = false
		invincible = false
		invincibility_finished.emit()

#----------------#
# Public Methods #
#----------------#

## Called by [Hitbox2D] when it overlaps this hurtbox. Returns true if the hit was
## accepted, or false if it was ignored (e.g. due to invincibility).
func receive_hit(hitbox : Hitbox2D) -> bool:
	if invincible:
		if debug: print("%s: hit from %s ignored (invincible)" % [name, hitbox.name])
		return false

	var final_amount := hitbox.damage_amount * damage_multiplier
	hit_received.emit(hitbox, final_amount, hitbox.damage_type)

	if target != null and target.has_method("change_current_resource_quantity"):
		target.change_current_resource_quantity(-final_amount)

	if debug: print("%s: received %.1f damage from %s (target: %s)" % [name, final_amount, hitbox.name, target.name if target else "none"])

	if invincibility_duration > 0.0:
		start_invincibility(invincibility_duration)

	return true


## Enables invincibility for [param duration] seconds, after which it is automatically
## cleared and [signal invincibility_finished] is emitted.
func start_invincibility(duration : float) -> void:
	invincible = true
	_auto_invincible = true
	_invincibility_timer = duration
	if debug: print("%s: invincibility started for %.2fs" % [name, duration])
	invincibility_started.emit()


func end_invincibility() -> void:
	invincible = false
	_auto_invincible = false
	_invincibility_timer = 0.0
	if debug: print("%s: invincibility ended" % name)
	invincibility_finished.emit()
