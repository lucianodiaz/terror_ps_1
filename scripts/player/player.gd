
class_name Player
extends CharacterBody3D

const HIT_REQUEST := &"parameters/HitShot/request"
const HIT_ACTIVE := &"parameters/HitShot/active"

## Its locomotion StateMachine reads is_moving, is_running and is_moving_backward
## through advance expressions, so advance_expression_base_node points at this node
@export var animation_tree: AnimationTree

@export_group("Components")
@export var movement_player_component: MovementPlayerComponent
@export var health_component: HealthComponent
@export var velocity_component: VelocityComponent



## Door or any node with an interact() method (Pickup, FlagTrigger, ...)
var current_interactable: Node = null

var is_in_puzzle: bool = false

var is_moving: bool = false
var is_running: bool = false
var is_moving_backward: bool = false

## Covers the frame between the hit request and the OneShot reporting itself active
var _hit_requested: bool = false

var is_hurt: bool:
	get:
		return _hit_requested or (animation_tree != null and animation_tree.get(HIT_ACTIVE))

func _ready() -> void:
	if animation_tree:
		animation_tree.active = true
	if health_component:
		health_component.on_health_changed.connect(_on_health_changed)


func _input(event: InputEvent) -> void:
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
	if _hit_requested and animation_tree.get(HIT_ACTIVE):
		_hit_requested = false

	if is_hurt:
		movement_player_component.stop_movement()
	elif not is_in_puzzle and movement_player_component:
		movement_player_component.movement(delta)
	_update_locomotion_state()


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
	movement_player_component.stop_movement()


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
