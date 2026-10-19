
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

## Its locomotion StateMachine reads is_moving, is_running and is_moving_backward
## through advance expressions, so advance_expression_base_node points at this node
@export var animation_tree: AnimationTree

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

## Covers the frame between the hit request and the OneShot reporting itself active
var _hit_requested: bool = false

var is_hurt: bool:
	get:
		return _hit_requested or (animation_tree != null and animation_tree.get(HIT_ACTIVE))

var is_aiming_weapon: bool:
	get:
		return movement_player_component != null and movement_player_component.is_aiming \
			and weapon_holder != null and weapon_holder.has_weapon()

var _aim_state: StringName = AIM_STATE_NORMAL

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

func _on_body_sighted(body: Node3D) -> void:
	print("body sighted: ", body.name)

func _on_body_hidden(body: Node3D) -> void:
	print("body hidden: ", body.name)

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
	## Releasing aim while the inventory is open never reaches _input
	if movement_player_component.is_aiming and not Input.is_action_pressed("aim"):
		movement_player_component.is_aiming = false

	if is_hurt:
		movement_player_component.stop_movement()
	elif not is_in_puzzle and movement_player_component:
		movement_player_component.movement(delta)
	_update_locomotion_state()
	_update_aim_state()


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
	if animation_tree == null or dmg_received <= 0.0 or health_component.is_died:
		return
	animation_tree.set(HIT_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_hit_requested = true
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
	var data: WeaponData = weapon_holder.get_weapon_data()
	if animation_tree and data and data.attack_animation != &"":
		animation_tree.set(ATTACK_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


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
