## Title screen background. The menu itself is the MainMenuScreen child,
## New Game and Load leave this scene through SaveManager.
extends Node3D

@export var camera: Camera3D = null
@export var tv_light: OmniLight3D = null

@export_group("Camera sway")
## Radians around Y and X
@export var sway_amount: Vector2 = Vector2(0.025, 0.012)
@export var sway_speed: float = 0.12

@export_group("TV flicker")
@export_range(0.0, 1.0) var flicker_strength: float = 0.35
## How fast the light follows each new random value
@export var flicker_smoothing: float = 18.0

var _camera_rotation: Vector3 = Vector3.ZERO
var _tv_energy: float = 0.0
var _flicker: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if camera:
		_camera_rotation = camera.rotation
	if tv_light:
		_tv_energy = tv_light.light_energy


func _process(delta: float) -> void:
	_time += delta
	if camera:
		camera.rotation.y = _camera_rotation.y + sin(_time * sway_speed * TAU) * sway_amount.x
		camera.rotation.x = _camera_rotation.x + sin(_time * sway_speed * 0.7 * TAU) * sway_amount.y
	if tv_light:
		_flicker = lerpf(_flicker, randf(), minf(flicker_smoothing * delta, 1.0))
		tv_light.light_energy = _tv_energy * (1.0 - flicker_strength * _flicker)
