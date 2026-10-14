@tool
class_name Lever
extends Node3D

enum State {
	DOWN,
	UP
}

const ANIMATIONS: Dictionary[State, StringName] = {
	State.DOWN: &"down",
	State.UP: &"up",
}

@export var state: State = State.UP:
	set(value):
		state = value
		if is_node_ready() and not _is_animating:
			_apply_pose()

@export var config: LeverConfig:
	set(value):
		if config and config.changed.is_connected(_apply_config):
			config.changed.disconnect(_apply_config)
		config = value
		if config:
			config.changed.connect(_apply_config)
		if is_node_ready():
			_apply_config()

@onready var mesh: MeshInstance3D = $Mesh
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _is_animating: bool = false


func _ready() -> void:
	_apply_config()
	_apply_pose()


func toggle() -> void:
	_is_animating = true
	state = State.DOWN if state == State.UP else State.UP
	animation_player.play(ANIMATIONS[state])
	await animation_player.animation_finished
	_is_animating = false


func is_animating() -> bool:
	return _is_animating


func _apply_pose() -> void:
	animation_player.play(ANIMATIONS[state])
	animation_player.seek(animation_player.current_animation_length, true)
	animation_player.stop(true)


func _apply_config() -> void:
	if config == null:
		mesh.material_override = null
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = config.color
	mesh.material_override = material
