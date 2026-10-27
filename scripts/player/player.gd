
class_name Player
extends CharacterBody3D

const HIT_REQUEST : StringName = &"parameters/HitShot/request"
const HIT_ACTIVE : StringName = &"parameters/HitShot/active"

## Transition node: "alive" feeds locomotion + hit, "dead" holds the last frame of dying
const LIFE_STATE_REQUEST : StringName = &"parameters/LifeState/transition_request"
const LIFE_STATE_DEAD : StringName = &"dead"

## Transition node between locomotion ("normal") and the weapon's aim pose ("aim")
const AIM_STATE_REQUEST : StringName = &"parameters/AimState/transition_request"
const AIM_STATE_NORMAL : StringName = &"normal"
const AIM_STATE_AIM : StringName = &"aim"
const ATTACK_REQUEST : StringName = &"parameters/AttackShot/request"
const ATTACK_ACTIVE : StringName = &"parameters/AttackShot/active"
## AnimationNodeAnimation nodes whose clip comes from the equipped WeaponData
const AIM_ANIM_NODE : StringName = &"AimAnim"
const ATTACK_ANIM_NODE : StringName = &"AttackAnim"

## Transition node between then locomotion and Injured locomotion
## when HP is lower 0.15 ratio
const HEALTH_STATE_REQUEST : StringName = &"parameters/HealthState/transition_request"
const HEALTH_STATE_INJURED : StringName = &"injured"
const HEALTH_STATE_NORMAL : StringName = &"normal"


## Its locomotion StateMachine reads is_moving, is_running and is_moving_backward
## through advance expressions, so advance_expression_base_node points at this node
@export var animation_tree: AnimationTree

@export_group("Gameplay")
@export var skeleton:Skeleton3D
@export var head_bone_name: StringName = "Head"
## Radians per second while turning towards current_enemy during aim
@export var aim_turn_speed: float = 10.0
## Axis of the head bone that points out of the face, depends on the rig
@export var head_forward_axis: SkeletonModifier3D.BoneAxis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
@export_range(0.0, 180.0, 0.1, "radians_as_degrees") var head_look_limit_angle: float = deg_to_rad(70.0)
## Influence per second while the head blends in and out of looking at observable_object
@export var head_look_blend_speed: float = 4.0

@export_group("Components")
@export var movement_player_component: MovementPlayerComponent
@export var health_component: HealthComponent
@export var velocity_component: VelocityComponent
@export var weapon_holder: WeaponHolderComponent
@export var sigth_cone: VisionCone3D


## Door or any node with an interact() method (Pickup, FlagTrigger, ...)
var current_interactable: Node = null

var is_in_puzzle: bool = false

var is_moving: bool = false
var is_running: bool = false
var is_moving_backward: bool = false
var is_dead: bool = false

var current_enemy: Node3D = null
var observable_object: Node3D = null

## Covers the frame between the hit request and the OneShot reporting itself active
var _hit_requested: bool = false
var is_attacking: bool = false
## Released by the _on_end_hurt key of the hit clip, not by the OneShot ending
var is_hurt: bool = false

var is_aiming_weapon: bool:
	get:
		return movement_player_component != null and movement_player_component.is_aiming \
			and weapon_holder != null and weapon_holder.has_weapon()

var _aim_state: StringName = AIM_STATE_NORMAL
var _head_look: LookAtModifier3D = null

func _ready() -> void:
	if animation_tree:
		animation_tree.active = true
	if health_component:
		health_component.on_health_changed.connect(_on_health_changed)
		health_component.on_entity_died.connect(_on_entity_died)
	if weapon_holder:
		weapon_holder.weapon_changed.connect(_on_weapon_changed)
		## The holder is a child, so it equipped before this signal was connected
		_on_weapon_changed(weapon_holder.current_weapon)
	
	if sigth_cone:
		sigth_cone.body_sighted.connect(_on_body_sighted)
		sigth_cone.body_hidden.connect(_on_body_hidden)
	_setup_head_look()

## Skeleton modifiers run after the AnimationTree, so the head pose isn't overwritten
func _setup_head_look() -> void:
	if skeleton == null:
		return
	_head_look = LookAtModifier3D.new()
	_head_look.bone_name = head_bone_name
	_head_look.forward_axis = head_forward_axis
	_head_look.use_angle_limitation = true
	_head_look.symmetry_limitation = true
	_head_look.primary_limit_angle = head_look_limit_angle
	_head_look.secondary_limit_angle = head_look_limit_angle
	_head_look.duration = 0.3
	_head_look.influence = 0.0
	skeleton.add_child(_head_look)

func _on_body_sighted(body: Node3D) -> void:
	print("body sighted: ", body.name)
	observable_object = body

func _on_body_hidden(body: Node3D) -> void:
	print("body hidden: ", body.name)

	if body == observable_object:
		observable_object = null

func _input(event: InputEvent) -> void:
	if is_dead:
		return
	if InventoryMenu.is_open():
		return
	## Handled here and not inside MessageManager because autoloads sit earlier
	## in the tree, and _input travels in reverse order: the player would get
	## the action first and interact with the door all over again
	if MessageManager.is_blocking():
		if event.is_action_pressed("action"):
			MessageManager.advance()
		elif event.is_action_pressed("run"):
			MessageManager.clear()
		return

	if event.is_action("aim"):
		movement_player_component.is_aiming = event.is_pressed()
	if event.is_action_pressed("action"):
		if is_aiming_weapon:
			_try_attack()
		else:
			_interact()

	if event.is_action_pressed("run"):
		movement_player_component.set_run_speed()

	if event.is_action_released("run"):
		movement_player_component.set_walk_speed()

	## Debug shortcut until there is an options screen
	if event.is_action_pressed("toggle_controls"):
		SettingsManager.toggle_control_scheme()
		print("control scheme: ", GameSettings.ControlScheme.keys()[SettingsManager.control_scheme])

func set_in_puzzle(value: bool) -> void:
	is_in_puzzle = value
	movement_player_component.stop_movement()

func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _hit_requested and animation_tree.get(HIT_ACTIVE):
		_hit_requested = false
	## The OneShot can end without reaching the key, aborted for example
	elif is_hurt and not _hit_requested and not animation_tree.get(HIT_ACTIVE):
		is_hurt = false
	## Releasing aim while the inventory is open never reaches _input
	if movement_player_component.is_aiming and not Input.is_action_pressed("aim"):
		movement_player_component.is_aiming = false

	if is_hurt:
		movement_player_component.stop_movement()
	elif not is_in_puzzle and movement_player_component:
		movement_player_component.movement(delta)
	_update_locomotion_state()
	_update_aim_state()
	
	#look for a closest enemy
	_find_closest_enemy()

	if current_enemy and movement_player_component.is_aiming:
		_face_enemy(delta)
	
	if observable_object and not movement_player_component.is_aiming:
		_face_head_to_observable_object(delta)
	else:
		_blend_head_look(0.0, delta)

func _find_closest_enemy() -> void:
	#clear the current enemy
	if current_enemy and current_enemy.is_dead:
		current_enemy = null
	var closest_enemy: Node3D = null
	var closest_distance: float = 10000
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead:
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	if closest_enemy:
		current_enemy = closest_enemy

func _face_head_to_observable_object(delta: float) -> void:
	if _head_look == null:
		return
	if not is_instance_valid(observable_object):
		observable_object = null
		_blend_head_look(0.0, delta)
		return
	_head_look.target_node = _head_look.get_path_to(observable_object)
	## Fade out instead of snapping to the limit when the object ends up behind the player
	var target_influence: float = 1.0 if _head_look.is_target_within_limitation() else 0.0
	_blend_head_look(target_influence, delta)

func _blend_head_look(target_influence: float, delta: float) -> void:
	if _head_look == null:
		return
	_head_look.influence = move_toward(_head_look.influence, target_influence, head_look_blend_speed * delta)

## The body looks down -Z, so the yaw aiming it at dir is atan2(-x, -z)
func _face_enemy(delta: float) -> void:
	var direction: Vector3 = current_enemy.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = rotate_toward(rotation.y, target_yaw, aim_turn_speed * delta)


func _update_locomotion_state() -> void:
	if velocity_component == null or movement_player_component == null:
		return
	var horizontal_velocity: Vector3 = velocity_component.velocity
	horizontal_velocity.y = 0.0

	is_moving = not is_in_puzzle and not is_hurt \
		and horizontal_velocity.length() > velocity_component.velocity_threshold
	is_running = is_moving and movement_player_component.is_running()
	is_moving_backward = is_moving and horizontal_velocity.dot(-global_basis.z) < 0.0


func _on_health_changed(_current_health: float, dmg_received: float) -> void:
	var health_ratio: float = health_component.get_health_ratio()
	var injured: bool = health_ratio <= 0.15
	movement_player_component.is_injured = injured
	if injured:
		animation_tree.set(HEALTH_STATE_REQUEST, HEALTH_STATE_INJURED)
	else:
		animation_tree.set(HEALTH_STATE_REQUEST, HEALTH_STATE_NORMAL)
	
	
	if animation_tree == null or dmg_received <= 0.0 or health_component.is_died:
		return
	animation_tree.set(HIT_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_hit_requested = true
	is_hurt = true
	movement_player_component.is_aiming = false
	movement_player_component.stop_movement()
	_cancel_attack()




func _update_aim_state() -> void:
	if animation_tree == null:
		return
	var target: StringName = AIM_STATE_AIM if is_aiming_weapon and not is_hurt else AIM_STATE_NORMAL
	if target == _aim_state:
		return
	_aim_state = target
	animation_tree.set(AIM_STATE_REQUEST, _aim_state)


func _try_attack() -> void:
	if is_hurt or is_in_puzzle or weapon_holder == null:
		return
	if not weapon_holder.try_attack():
		return
	if is_attacking:
		return
	var data: WeaponData = weapon_holder.get_weapon_data()
	if animation_tree and data and data.attack_animation != &"":
		animation_tree.set(ATTACK_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	is_attacking = true

func _cancel_attack() -> void:
	if weapon_holder:
		weapon_holder.cancel_attack()
	if animation_tree:
		animation_tree.set(ATTACK_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)


## Each weapon brings its own aim and attack clips, the tree keeps one node for each
func _on_weapon_changed(weapon: Weapon) -> void:
	_cancel_attack()
	if animation_tree == null or weapon == null or weapon.data == null:
		return
	var root: AnimationNodeBlendTree = animation_tree.tree_root as AnimationNodeBlendTree
	if root == null:
		return
	_set_tree_clip(root, AIM_ANIM_NODE, weapon.data.aim_animation)
	_set_tree_clip(root, ATTACK_ANIM_NODE, weapon.data.attack_animation)


func _set_tree_clip(root: AnimationNodeBlendTree, node_name: StringName, clip: StringName) -> void:
	if clip == &"" or not root.has_node(node_name):
		return
	var node: AnimationNodeAnimation = root.get_node(node_name) as AnimationNodeAnimation
	if node:
		node.animation = clip


func _interact() -> void:
	if not is_instance_valid(current_interactable):
		current_interactable = null
		return
	if current_interactable is Door:
		current_interactable.try_open_door()
	elif current_interactable.has_method("interact"):
		current_interactable.interact()


func on_area_trigger_entered(area: Area3D) -> void:
	var interactable : Node = _get_interactable_from_node(area)
	if interactable:
		current_interactable = interactable


func _on_area_trigger_exited(area: Area3D) -> void:
	var interactable : Node = _get_interactable_from_node(area)
	if interactable and interactable == current_interactable:
		current_interactable = null

func on_area_trigger_body_entered(body: Node3D) -> void:
	var interactable : Node = _get_interactable_from_node(body)
	if interactable:
		current_interactable = interactable


func _is_interactable(node: Node) -> bool:
	return node is Door or node.has_method("interact")


func _get_interactable_from_node(node: Node) -> Node:
	if _is_interactable(node):
		return node
	var parent := node.get_parent()
	if parent != null and _is_interactable(parent):
		return parent
	return null



func _on_entity_died(dead:bool) -> void:
	if not dead or is_dead:
		return
	print("[Player] - Entity died")
	is_dead = true
	_hit_requested = false
	is_hurt = false
	is_moving = false
	is_running = false
	is_moving_backward = false
	current_interactable = null
	if movement_player_component:
		movement_player_component.is_aiming = false
		movement_player_component.stop_movement()
	_cancel_attack()
	if animation_tree:
		animation_tree.set(HIT_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		animation_tree.set(LIFE_STATE_REQUEST, LIFE_STATE_DEAD)

func _on_end_attack() -> void:
	print("[Player] - End attack")
	is_attacking = false

func _on_end_hurt() -> void:
	print("[Player] - End hurt")
	_hit_requested = false
	is_hurt = false
	if animation_tree:
		animation_tree.set(HIT_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
