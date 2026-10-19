class_name HitComponent

extends Area3D


@export var damage_amount : float= 10.0
@export var damage_type :String
@export var knockback_force: float = 0.0
@export var instigator:Node

signal on_hit(area:Area3D)
signal on_hit_body(body:Node3D)

func _init() -> void:
	connect("body_entered",_on_body_entered)
	connect("area_entered",_on_area_entered)

func _ready() -> void:
	set_process(false)
	# collision_layer = CollisionLayers.HIT
	# collision_mask = CollisionLayers.HURT | CollisionLayers.WALLS
	print("[HitComponent] - Instigator : ", instigator)

func get_damage() -> float:
	return damage_amount


func get_knockback_impulse(victim_global_position: Vector3) -> Vector3:
	if knockback_force <= 0.0:
		return Vector3.ZERO

	var source_pos := _get_knockback_source_position()
	var direction := victim_global_position - source_pos
	if direction.length_squared() <= 0.0001:
		direction = Vector3.RIGHT
	return direction.normalized() * knockback_force


func _get_knockback_source_position() -> Vector3:
	if instigator is Node3D:
		return (instigator as Node3D).global_position
	if owner is Node3D:
		return (owner as Node3D).global_position
	return Vector3.ZERO


func _on_body_entered(body:Node3D) -> void:
	if instigator == body:
		return
	if body == null or body == owner:
		return;
	emit_signal("on_hit_body",body)

func _on_area_entered(area: Area3D) -> void:
	print("[HitComponent] - Area : ", area.owner)
	if instigator == area.owner:
		return
	if area == null:
		pass
	
	emit_signal("on_hit",area)

## Turns the hitbox on and off without touching its layers. Enabling the shapes
## again makes overlapping hurtboxes report area_entered once more.
func set_active(active: bool) -> void:
	set_deferred("monitoring", active)
	set_deferred("monitorable", active)
	for child:Node in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", not active)

func disable_collision() -> void:
	collision_layer = 0
	collision_mask = 0
	for child:Node in get_children():
		if child is CollisionShape3D:
			child.disabled = true
