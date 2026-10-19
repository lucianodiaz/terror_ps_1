class_name HurtComponent
extends Area3D



@export var healthComponent: HealthComponent
@export var velocity_component: VelocityComponent

## area is null when the hit came through receive_hit()
signal on_hurt(area: Area3D)
signal on_knockback_applied(impulse: Vector3)


func _ready() -> void:
	set_process(false)
	# collision_layer = CollisionLayers.HURT
	# collision_mask = CollisionLayers.HIT
	connect("area_entered", _on_area_entered)

	if velocity_component == null and owner:
		velocity_component = owner.get_node_or_null("VelocityComponent") as VelocityComponent


func _on_area_entered(area: Variant) -> void:
	if area == null or area.instigator == owner:
		return

	var hit_area : Area3D = area as Area3D
	if hit_area == null:
		return

	_try_apply_damage(hit_area)
	_try_apply_knockback(hit_area)

	emit_signal("on_hurt", hit_area)


## Damage that doesn't come from an overlapping HitComponent, a hitscan shot for
## example.
func receive_hit(damage: float, impulse: Vector3, instigator: Node) -> bool:
	if instigator != null and instigator == owner:
		return false
	var damaged: bool = _apply_damage(damage)
	_apply_knockback(impulse)
	emit_signal("on_hurt", null)
	return damaged


func _try_apply_damage(area: Area3D) -> bool:
	if not area.has_method("get_damage"):
		return false
	return _apply_damage(area.get_damage())


func _apply_damage(amount: float) -> bool:
	if healthComponent == null:
		return false
	if healthComponent.is_died or healthComponent.hit_invisibility:
		return false

	healthComponent.damage(amount)
	return true


func _try_apply_knockback(area: Area3D) -> void:
	if not area.has_method("get_knockback_impulse"):
		return
	var impulse: Vector3 = area.get_knockback_impulse(owner.global_position)
	_apply_knockback(impulse)


func _apply_knockback(impulse: Vector3) -> void:
	if impulse.length_squared() <= 0.0001:
		return
	## VelocityComponent has no knockback yet, on_knockback_applied still lets the owner react
	if velocity_component and velocity_component.has_method("apply_knockback"):
		velocity_component.apply_knockback(impulse)
	emit_signal("on_knockback_applied", impulse)


func disable_collision() -> void:
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true
