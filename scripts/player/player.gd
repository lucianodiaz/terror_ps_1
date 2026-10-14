
class_name Player
extends CharacterBody3D

@export var animation_player: AnimationPlayer

@export_group("Components")
@export var movement_player_component: MovementPlayerComponent
@export var health_component: HealthComponent


## Door or any node with an interact() method (Pickup, FlagTrigger, ...)
var current_interactable: Node = null

var is_in_puzzle: bool = false

func _ready() -> void:
	pass


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
	if is_in_puzzle:
		return
	if movement_player_component:
		movement_player_component.movement(delta)
		if movement_player_component.get_velocity().length() > 0.1 && !is_in_puzzle:
			if movement_player_component.run_speed == movement_player_component.current_speed:
				animation_player.play("run")
			else:
				animation_player.play("walk")
		else:
			animation_player.play("idle")


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
