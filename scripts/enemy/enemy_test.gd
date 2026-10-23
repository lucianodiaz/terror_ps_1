class_name EnemyTest

extends CharacterBody3D
const HIT_REQUEST : StringName = &"parameters/Hit/request"
const HIT_ACTIVE : StringName = &"parameters/Hit/active"

## Transition node: "alive" feeds locomotion + hit, "dead" holds the last frame of dying
const LIFE_STATE_REQUEST : StringName = &"parameters/LifeState/transition_request"
const LIFE_STATE_DEAD : StringName = &"dead"

@export var health_component: HealthComponent
@export var animation_tree: AnimationTree
@export var vision_cone: VisionCone3D
@export var velocity_component: VelocityComponent

@export_range(0.0, 0.3, 0.01, "suffix:s") var hit_blend_time: float = 0.05


var is_dead: bool = false
var _hit_requested: bool = false
var is_moving: bool = false

func _ready() -> void:
	if vision_cone:
		vision_cone.body_sighted.connect(_on_body_sighted)
		vision_cone.body_hidden.connect(_on_body_hidden)
	if health_component:
		health_component.on_entity_died.connect(_on_died)

func _on_body_sighted(body: Node3D) -> void:
	print("[EnemyTest] - Body sighted: ", body.name)

func _on_body_hidden(body: Node3D) -> void:
	print("[EnemyTest] - Body hidden: ", body.name)

func _on_died(dead:bool) -> void:
	print("[EnemyTest] - Died")
	if not dead or is_dead:
		return
	is_dead = dead
	_hit_requested = false
	is_moving = false
	velocity_component.stop_movement()
	if animation_tree:
		animation_tree.set(HIT_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		animation_tree.set(LIFE_STATE_REQUEST, LIFE_STATE_DEAD)



func _update_locomotion_state() -> void:
	if velocity_component == null:
		return
	var horizontal_velocity: Vector3 = velocity_component.velocity
	horizontal_velocity.y = 0.0
	is_moving = velocity_component.velocity.length() > velocity_component.velocity_threshold

func _on_hurt(area: Area3D) -> void:
	print("[EnemyTest] - Hurt by ", area.owner if area else null)
	animation_tree.set(HIT_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_hit_requested = true



func _on_end_attack() -> void:
	print("[EnemyTest] - End attack")