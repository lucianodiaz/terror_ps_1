@tool
class_name MeleeWeapon
extends Weapon

## The hitbox stays off except during data.hit_window, so walking into an
## enemy with the weapon in hand doesn't hurt it.

## Each swing bumps this, timers from an older swing see a different value and do nothing
var _swing_id: int = 0


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	if hit_component:
		hit_component.set_active(false)


func setup(new_skeleton: Skeleton3D, new_instigator: Node, new_item_id: String, new_data: WeaponData) -> void:
	super.setup(new_skeleton, new_instigator, new_item_id, new_data)
	if hit_component and data:
		hit_component.damage_amount = data.damage
		hit_component.knockback_force = data.knockback_force


func _perform() -> bool:
	if hit_component == null:
		return true
	_swing_id += 1
	var window: Vector2 = data.hit_window if data else Vector2(0.0, 0.3)
	hit_component.set_active(false)
	get_tree().create_timer(window.x, false).timeout.connect(_set_hitbox.bind(true, _swing_id))
	get_tree().create_timer(window.y, false).timeout.connect(_set_hitbox.bind(false, _swing_id))
	return true


## Getting hit in the middle of a swing has to close the window right away
func cancel() -> void:
	_swing_id += 1
	if hit_component:
		hit_component.set_active(false)


func _set_hitbox(active: bool, swing_id: int) -> void:
	if swing_id != _swing_id or hit_component == null:
		return
	hit_component.set_active(active)
