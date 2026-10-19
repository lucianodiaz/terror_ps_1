@tool
class_name RangedWeapon
extends Weapon

## Hitscan gun. Each shot takes a round from the magazine stored in the
## inventory slot, the ray goes out the muzzle along the instigator's facing.

## Hurtboxes and walls, walls stop the shot before it reaches what is behind
@export_flags_3d_physics var hit_mask: int = 32 | 8
## Where the ray starts, falls back to the weapon's origin
@export var muzzle: Node3D

## use() comes from input, the space state is only safe to query during physics
var _shot_pending: bool = false


func _perform() -> bool:
	if not Inventory.consume_loaded(item_id):
		print("[RangedWeapon] - Click, no ammo")
		return false
	_shot_pending = true
	return true


func _physics_process(_delta: float) -> void:
	if not _shot_pending:
		return
	_shot_pending = false
	_shoot()


func _shoot() -> void:
	var origin: Vector3 = muzzle.global_position if muzzle else global_position
	var direction: Vector3 = _get_aim_direction()
	var fire_range: float = data.fire_range if data else 30.0
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * fire_range, hit_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = _get_excluded_rids()

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var hurt: HurtComponent = hit["collider"] as HurtComponent
	if hurt == null:
		return
	var knockback: float = data.knockback_force if data else 0.0
	hurt.receive_hit(data.damage if data else 10.0, direction * knockback, instigator)


## Flat forward of the instigator, the hand bobs with the aim animation and
## would make the shot drift
func _get_aim_direction() -> Vector3:
	var source: Node3D = instigator as Node3D if instigator is Node3D else self
	var forward: Vector3 = -source.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


func _get_excluded_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if instigator is CollisionObject3D:
		rids.append((instigator as CollisionObject3D).get_rid())
	if instigator:
		for child in instigator.get_children():
			if child is HurtComponent:
				rids.append((child as CollisionObject3D).get_rid())
	return rids
