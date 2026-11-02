class_name MovementPlayerComponent
extends Node

@export_group("Gameplay")
@export_range(0.0, 10.0, 0.1) var walk_speed:float = 3.5
@export_range(0.0, 10.0, 0.1) var backward_speed:float = 2.5
@export_range(0.0, 10.0, 0.1) var run_speed:float = 6.0
@export_range(0.0, 10.0, 0.1) var run_backward_speed:float = 3.0
@export_range(0.0, 10.0, 0.1) var aim_speed:float = 4.0

@export_range(0.0, 10.0, 0.1) var damaged_walk_speed:float = 1.5
@export_range(0.0, 10.0, 0.1) var damaged_backward_speed:float = 1.5
@export_range(0.0, 10.0, 0.1) var damaged_run_speed:float = 2.0
@export_range(0.0, 10.0, 0.1) var damaged_run_backward_speed:float = 1.5
@export_range(0.0, 10.0, 0.1) var turn_speed:float = 4.5

@export_group("Quick Turn")
## Seconds the 180 takes, back + run on the keys or the D-pad
@export_range(0.05, 1.0, 0.01) var quick_turn_duration:float = 0.35

@export_group("Modern Controls")
## How fast the body reorients towards the input direction. Separate from
## turn_speed, which is the rate at which the player steers in tank mode.
@export_range(0.0, 30.0, 0.1) var modern_turn_speed:float = 12.0
## Freezes the camera basis while a direction is held. Without this, crossing a
## CameraTriggerZone flips what "forward" means mid step, and a FixedFollowCamera
## makes the character walk in a curve.
@export var lock_direction_while_moving:bool = true

@export_group("Components")
@export var character_body: CharacterBody3D
@export var velocity_component: VelocityComponent

var current_speed:float = 0.0
var is_aiming:bool = false
## Picks the damaged_* speed set instead of the normal one
var is_injured:bool = false:
	set(value):
		if is_injured == value:
			return
		is_injured = value
		_apply_speed()

var _running:bool = false
var _backward:bool = false

var _reference_basis:Basis = Basis.IDENTITY
var _reference_locked:bool = false
## Radians the quick turn still has to rotate, 0 when not turning
var _quick_turn_left:float = 0.0
## Set by the quick turn, the backward input is ignored until it is released
## so the body doesn't walk back towards what it just turned away from
var _backward_blocked:bool = false

func _ready() -> void:
	_apply_speed()

func set_run_speed() -> void:
	_set_gait(true, false)

func set_walk_speed() -> void:
	_set_gait(false, false)

func set_backward_speed() -> void:
	_set_gait(false, true)

func set_run_backward_speed() -> void:
	_set_gait(true, true)

func reset_speed() -> void:
	_set_gait(false, false)

## Keeps the backward flag, so it can be called every frame without
## cutting short the backward walk while the body slows down
func set_running(running:bool) -> void:
	if _running == running:
		return
	_set_gait(running, _backward)

func is_running() -> bool:
	return _running

## Only tank controls walk backwards, direction controls always walk where the body faces
func is_moving_backward() -> bool:
	return _backward

func _set_gait(running:bool, backward:bool) -> void:
	_running = running
	_backward = backward
	_apply_speed()

func _apply_speed() -> void:
	if is_injured:
		if _backward:
			current_speed = damaged_run_backward_speed if _running else damaged_backward_speed
		else:
			current_speed = damaged_run_speed if _running else damaged_walk_speed
	else:
		if _backward:
			current_speed = run_backward_speed if _running else backward_speed
		else:
			current_speed = run_speed if _running else walk_speed

func stop_movement() -> void:
	## Next time the player moves we want a fresh snapshot, the camera may have
	## changed while they were in a puzzle or a room transition
	_reference_locked = false
	_quick_turn_left = 0.0
	if velocity_component:
		velocity_component.stop()

## The stick walks with direction controls, keys and the D-pad with tank
## controls. Using both at once the stick wins.
func movement(delta:float) -> void:
	if _backward_blocked and _digital_strength(&"backward") == 0.0:
		_backward_blocked = false
	if _quick_turn_left > 0.0:
		_quick_turn_step(delta)
		return
	var stick : Vector2 = _stick_vector()
	if stick.is_zero_approx():
		_tank_movement(delta)
	else:
		_modern_movement(stick, delta)


## Tank controls only: holding back and pressing run spins the body around.
## Returns whether the turn started.
func try_quick_turn() -> bool:
	##if is_aiming or _quick_turn_left > 0.0 or _backward_blocked:
	if _quick_turn_left > 0.0 or _backward_blocked:
		return false
	if not _stick_vector().is_zero_approx():
		return false
	if _digital_axis(&"backward", &"forward") >= 0.0:
		return false
	_quick_turn_left = PI
	_backward_blocked = true
	_set_gait(_running, false)
	return true


func _quick_turn_step(delta:float) -> void:
	var step : float = minf(PI / maxf(quick_turn_duration, 0.01) * delta, _quick_turn_left)
	character_body.rotation.y += step
	_quick_turn_left -= step
	_apply_velocity(Vector3.ZERO, delta)


## Left/right rotate on the Y axis, forward/backward walk along the facing.
## Rotation works while aiming too, so you can line up a shot standing still.
func _tank_movement(delta:float) -> void:
	## Direction controls take a fresh camera snapshot when they come back
	_reference_locked = false
	_tank_turn(delta)

	if is_aiming:
		stop_movement()
		return

	var move_input : float = _digital_axis(&"backward", &"forward")
	if _backward_blocked:
		move_input = maxf(move_input, 0.0)
	var desired_velocity : Vector3 = Vector3.ZERO

	if move_input != 0.0:
		## Not updated at rest, so the backward walk lasts while the body slows down
		_set_gait(_running, move_input < 0.0)
		var forward : Vector3 = -character_body.global_transform.basis.z
		forward.y = 0.0
		desired_velocity = forward.normalized() * move_input * current_speed

	_apply_velocity(desired_velocity, delta)


## The stick is a direction on screen. The body turns to face it and walks
## there, so it never walks backwards.
func _modern_movement(input:Vector2, delta:float) -> void:
	_set_gait(_running, false)
	## While aiming the stick turns the body like tank controls, so the camera
	## doesn't get to decide where the character points
	if is_aiming:
		character_body.rotation.y -= input.x * turn_speed * delta
		stop_movement()
		return

	var reference : Basis = _get_reference_basis()
	## reference.z points behind the camera, hence the minus on the forward axis
	var direction : Vector3 = (reference.x * input.x - reference.z * input.y).normalized()

	_face_direction(direction, delta)

	var facing : Vector3 = -character_body.global_basis.z
	facing.y = 0.0
	facing = facing.normalized()
	## Walking along the facing, and only once it points roughly at the input,
	## turns sharp changes of direction into a pivot instead of a sideways slide
	var walk_factor : float = smoothstep(-0.3, 0.7, facing.dot(direction))
	_apply_velocity(facing * current_speed * minf(input.length(), 1.0) * walk_factor, delta)


func _tank_turn(delta:float) -> void:
	var turn_input : float = _digital_axis(&"left", &"right")
	if turn_input != 0.0:
		character_body.rotation.y -= turn_input * turn_speed * delta


## The movement actions hold keys, D-pad buttons and stick axes together, and
## Input.get_vector would mix them. These read each kind on its own, going
## through the InputMap so rebinding still works.

## x is right, y is forward. Zero inside the forward action's deadzone, and
## stretched past it so a small push still starts slow.
func _stick_vector() -> Vector2:
	var input : Vector2 = Vector2(
		_stick_strength(&"right") - _stick_strength(&"left"),
		_stick_strength(&"forward") - _stick_strength(&"backward"))
	var deadzone : float = InputMap.action_get_deadzone(&"forward")
	var length : float = input.length()
	if length <= deadzone:
		return Vector2.ZERO
	return input / length * minf(inverse_lerp(deadzone, 1.0, length), 1.0)


func _stick_strength(action:StringName) -> float:
	var strength : float = 0.0
	for event in InputMap.action_get_events(action):
		var motion : InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion == null:
			continue
		for pad in Input.get_connected_joypads():
			strength = maxf(strength, Input.get_joy_axis(pad, motion.axis) * signf(motion.axis_value))
	return strength


func _digital_axis(negative:StringName, positive:StringName) -> float:
	return _digital_strength(positive) - _digital_strength(negative)


## 1 while any key, mouse button or pad button of the action is held
func _digital_strength(action:StringName) -> float:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key : InputEventKey = event as InputEventKey
			if key.physical_keycode != KEY_NONE and Input.is_physical_key_pressed(key.physical_keycode):
				return 1.0
			if key.physical_keycode == KEY_NONE and Input.is_key_pressed(key.keycode):
				return 1.0
		elif event is InputEventMouseButton:
			if Input.is_mouse_button_pressed((event as InputEventMouseButton).button_index):
				return 1.0
		elif event is InputEventJoypadButton:
			var button : JoyButton = (event as InputEventJoypadButton).button_index
			for pad in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(pad, button):
					return 1.0
	return 0.0


func _apply_velocity(desired_velocity:Vector3, delta:float) -> void:
	if velocity_component == null:
		return
	if desired_velocity.is_zero_approx():
		velocity_component.decelerate()
	else:
		velocity_component.accelerate_to_velocity(desired_velocity)
	velocity_component.move(character_body, delta)


func _get_reference_basis() -> Basis:
	if lock_direction_while_moving and _reference_locked:
		return _reference_basis

	var camera : Camera3D = CameraManager.get_current_camera()
	if camera == null:
		camera = character_body.get_viewport().get_camera_3d()

	## With no camera at all we lean on the body, which behaves like tank mode
	_reference_basis = _flatten(camera.global_basis) if camera != null \
		else _flatten(character_body.global_basis)
	_reference_locked = true
	return _reference_basis


## Projects a basis onto the floor plane. A camera aimed almost straight down has
## no usable forward once flattened, and there the screen's up is its up vector.
static func _flatten(basis:Basis) -> Basis:
	var forward : Vector3 = -basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = basis.y
		forward.y = 0.0
	if forward.length_squared() < 0.001:
		return Basis.IDENTITY
	forward = forward.normalized()
	return Basis(forward.cross(Vector3.UP), Vector3.UP, -forward)


## The body looks down -Z, so the yaw aiming it at dir is atan2(-x, -z)
func _face_direction(direction:Vector3, delta:float) -> void:
	var target_yaw : float = atan2(-direction.x, -direction.z)
	character_body.rotation.y = rotate_toward(
		character_body.rotation.y, target_yaw, modern_turn_speed * delta
	)

func get_velocity() -> Vector3:
	return velocity_component.velocity
