class_name EnemyTest

extends CharacterBody3D
const HIT_REQUEST : StringName = &"parameters/Hit/request"
const HIT_ACTIVE : StringName = &"parameters/Hit/active"
const SCREAM_REQUEST : StringName = &"parameters/Scream/request"
const SCREAM_ACTIVE : StringName = &"parameters/Scream/active"
const ATTACK_REQUEST : StringName = &"parameters/Attack/request"
const ATTACK_ACTIVE : StringName = &"parameters/Attack/active"

## Transition node: "alive" feeds locomotion + hit, "dead" holds the last frame of dying
const LIFE_STATE_REQUEST : StringName = &"parameters/LifeState/transition_request"
const LIFE_STATE_DEAD : StringName = &"dead"

const BB_TARGET : StringName = &"target"
const BB_ALERTED : StringName = &"alerted"

@export var health_component: HealthComponent
@export var animation_tree: AnimationTree
@export var vision_cone: VisionCone3D
@export var velocity_component: VelocityComponent
@export var nav_agent: NavigationAgent3D
@export var bt_player: BTPlayer

@export_range(0.0, 0.3, 0.01, "suffix:s") var hit_blend_time: float = 0.05

@export_group("AI")
@export var walk_speed: float = 1.5
@export var run_speed: float = 4.5
@export var attack_range: float = 1.6
@export var turn_speed: float = 8.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var hit_stun_time: float = 0.6
@export_range(0.0, 10.0, 0.1, "suffix:s") var lose_target_time: float = 3.0

var spawn_id: String = ""
var is_dead: bool = false
var _hit_requested: bool = false
var is_moving: bool = false
var is_running: bool = false
var is_stunned: bool = false
var target: Node3D

var _has_destination: bool = false
var _stun_left: float = 0.0
var _lose_target_left: float = -1.0

signal on_die


func _ready() -> void:
	if vision_cone:
		vision_cone.body_sighted.connect(_on_body_sighted)
		vision_cone.body_hidden.connect(_on_body_hidden)
	if health_component:
		health_component.on_entity_died.connect(_on_died)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	if velocity_component == null:
		return

	if not is_dead and not is_stunned and _has_destination and nav_agent:
		if nav_agent.is_navigation_finished():
			_has_destination = false
			velocity_component.decelerate()
		else:
			var direction: Vector3 = nav_agent.get_next_path_position() - global_position
			direction.y = 0.0
			if direction.length_squared() > 0.0001:
				velocity_component.accelerate_in_direction(direction.normalized())
	else:
		velocity_component.decelerate()

	velocity_component.move(self, delta)
	_face_velocity(delta)
	_update_locomotion_state()
	if target and target.is_dead:
		_clear_target()
		_lose_target_left = 3.0

func _update_timers(delta: float) -> void:
	if is_stunned:
		_stun_left -= delta
		if _stun_left <= 0.0:
			is_stunned = false
	if _lose_target_left >= 0.0:
		_lose_target_left -= delta
		if _lose_target_left < 0.0:
			_clear_target()

#region Movement API (used by the behavior tree tasks)

func move_to(point: Vector3, run: bool) -> void:
	if nav_agent == null or is_dead:
		return
	is_running = run
	velocity_component.set_max_speed(run_speed if run else walk_speed)
	if not _has_destination or nav_agent.target_position.distance_squared_to(point) > 0.0625:
		nav_agent.target_position = point
	_has_destination = true

func stop_movement() -> void:
	_has_destination = false
	is_running = false
	if velocity_component:
		velocity_component.stop_movement()

func is_navigation_finished() -> bool:
	return not _has_destination or nav_agent == null or nav_agent.is_navigation_finished()

## Returns true once the enemy is looking at the point
func face_point(point: Vector3, delta: float, tolerance_deg: float = 10.0) -> bool:
	var to_point: Vector3 = point - global_position
	to_point.y = 0.0
	if to_point.length_squared() <= 0.0001:
		return true
	var target_yaw: float = atan2(-to_point.x, -to_point.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))
	return absf(angle_difference(rotation.y, target_yaw)) <= deg_to_rad(tolerance_deg)

func _face_velocity(delta: float) -> void:
	var horizontal_velocity: Vector3 = velocity_component.velocity
	horizontal_velocity.y = 0.0
	if horizontal_velocity.length() <= velocity_component.velocity_threshold:
		return
	var target_yaw: float = atan2(-horizontal_velocity.x, -horizontal_velocity.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))

#endregion

#region Animation API (used by the behavior tree tasks)

func play_scream() -> void:
	if animation_tree:
		animation_tree.set(SCREAM_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func is_screaming() -> bool:
	return animation_tree != null and animation_tree.get(SCREAM_ACTIVE)

func play_attack() -> void:
	if animation_tree:
		animation_tree.set(ATTACK_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func is_attacking() -> bool:
	return animation_tree != null and animation_tree.get(ATTACK_ACTIVE)

#endregion

func _on_body_sighted(body: Node3D) -> void:
	print("[EnemyTest] - Body sighted: ", body.name)
	if is_dead or not body.is_in_group("player"):
		_clear_target()
		_lose_target_left = -1.0
		return
	_lose_target_left = -1.0
	target = body
	_set_blackboard_var(BB_TARGET, body)

func _on_body_hidden(body: Node3D) -> void:
	print("[EnemyTest] - Body hidden: ", body.name)
	if body == target:
		_lose_target_left = lose_target_time

func _clear_target() -> void:
	target = null
	_set_blackboard_var(BB_TARGET, null)
	_set_blackboard_var(BB_ALERTED, false)

func _set_blackboard_var(var_name: StringName, value: Variant) -> void:
	if bt_player and bt_player.blackboard:
		bt_player.blackboard.set_var(var_name, value)

func _on_died(dead:bool) -> void:
	print("[EnemyTest] - Died")
	if not dead or is_dead:
		return
	is_dead = dead
	_hit_requested = false
	is_moving = false
	stop_movement()
	if bt_player:
		bt_player.active = false
	if nav_agent:
		nav_agent.process_mode = Node.PROCESS_MODE_DISABLED
	if animation_tree:
		animation_tree.set(HIT_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		animation_tree.set(SCREAM_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		animation_tree.set(ATTACK_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		animation_tree.set(LIFE_STATE_REQUEST, LIFE_STATE_DEAD)
	on_die.emit(self)



func _update_locomotion_state() -> void:
	if velocity_component == null:
		return
	var horizontal_velocity: Vector3 = velocity_component.velocity
	horizontal_velocity.y = 0.0
	is_moving = horizontal_velocity.length() > velocity_component.velocity_threshold

func _on_hurt(area: Area3D) -> void:
	print("[EnemyTest] - Hurt by ", area.owner if area else null)
	if is_dead:
		return
	stop_movement()
	is_stunned = true
	_stun_left = hit_stun_time
	animation_tree.set(SCREAM_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	animation_tree.set(ATTACK_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	animation_tree.set(HIT_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_hit_requested = true



func _on_end_attack() -> void:
	print("[EnemyTest] - End attack")
