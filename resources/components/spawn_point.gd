@tool
class_name SpawnPoint
extends Area3D

var collision_shape: CollisionShape3D
@export var capsule_color: Color = Color.RED :
	set(value):
		if Engine.is_editor_hint():
			collision_shape = get_node_or_null("CollisionShape3D")
			if collision_shape:
				collision_shape.debug_color = value
			else:
				push_warning("SpawnPoint. color: no collision shape found")
		capsule_color = value