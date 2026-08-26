@icon("res://assets/components/Hitbox3DNode.svg")
class_name Hitbox3D
extends Area3D
## Deals damage to any [Hurtbox3D] it overlaps.
##
## Attach to weapons, projectiles, or hazard volumes. Configure collision layers/masks
## in the editor so this only detects the appropriate [Hurtbox3D] nodes.
##
## @experimental

signal hit_landed(hurtbox : Hurtbox3D, damage_amount : float)
signal hit_blocked(hurtbox : Hurtbox3D)

# These are examples of damage types, they can be modified
enum DamageType {
	PHYSICAL,
	FIRE,
	ICE,
	POISON,
}

@export_category("Hit Settings")
## If false, overlaps are ignored entirely. Use [method set_active] to toggle at runtime.
@export var active : bool = true
@export var damage_amount : float = 10.0
@export var damage_type : DamageType = DamageType.PHYSICAL
@export var knockback_force : float = 0.0
## Optional reference to the attacking entity, forwarded to [Hurtbox3D] for attribution
## (e.g. kill credit, damage logs).
@export var source : Node

@export_category("Repeat Hit Settings")
## Seconds before this hitbox can hit the same [Hurtbox3D] again while still overlapping.
## Set to 0.0 to allow only a single hit per overlap (until the areas separate and re-enter).
@export var hit_interval : float = 0.0

@export_category("Debug")
@export var debug : bool = false

var _last_hit_time : Dictionary = {}

func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area : Area3D) -> void:
	if not active:
		return
	if not area.is_in_group("hurtbox") or not area.has_method("receive_hit"):
		return
	_try_hit(area)

#----------------#
# Public Methods #
#----------------#

## Enables or disables this hitbox without affecting its collision monitoring.
func set_active(new_active : bool) -> void:
	active = new_active


## Clears all recorded hit-cooldown timestamps, allowing every overlapping [Hurtbox3D]
## to be hit again immediately.
func reset_hit_cooldowns() -> void:
	_last_hit_time.clear()

#-----------------#
# Private Methods #
#-----------------#

func _try_hit(hurtbox : Area3D) -> void:
	var hurtbox_id := hurtbox.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0

	if _last_hit_time.has(hurtbox_id):
		var elapsed : float = now - _last_hit_time[hurtbox_id]
		if elapsed < hit_interval:
			if debug: print("%s: hit on %s ignored (cooldown, %.2fs remaining)" % [name, hurtbox.get_parent().name, hit_interval - elapsed])
			return

	var accepted : bool = hurtbox.receive_hit(self)
	_last_hit_time[hurtbox_id] = now

	if accepted:
		if debug: print("%s: hit landed on %s for %.1f %s damage" % [name, hurtbox.get_parent().name, damage_amount, DamageType.keys()[damage_type]])
		hit_landed.emit(hurtbox, damage_amount)
	else:
		if debug: print("%s: hit on %s blocked" % [name, hurtbox.get_parent().name])
		hit_blocked.emit(hurtbox)
