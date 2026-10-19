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

@export_group("Modern Controls")
## How fast the body reorients towards the input direction. Separate from
## turn_speed, which is the rate at which the player steers in tank mode.
@export_range(0.0, 20.0, 0.1) var modern_turn_speed:float = 10.0
## Freezes the camera basis while a direction is held. Without this, crossing a
## CameraTriggerZone flips what "forward" means mid step, and a FixedFollowCamera
## makes the character walk in a curve.
@export var lock_direction_while_moving:bool = true

@export_group("Components")
@export var character_body: CharacterBody3D
@export var velocity_component: VelocityComponent

var current_speed:float = 0.0
var is_aiming:bool = false

var _reference_basis:Basis = Basis.IDENTITY
var _reference_locked:bool = false

func _ready() -> void:
    current_speed = walk_speed

func set_run_speed() -> void:
    current_speed = run_speed

func set_walk_speed() -> void:
    current_speed = walk_speed

func set_backward_speed() -> void:
    current_speed = backward_speed

func set_run_backward_speed() -> void:
    current_speed = run_backward_speed

func set_damaged_backward_speed() -> void:
    current_speed = damaged_backward_speed

func set_damaged_run_backward_speed() -> void:
    current_speed = damaged_run_backward_speed

func set_damaged_run_speed() -> void:
    current_speed = damaged_run_speed

func set_damaged_walk_speed() -> void:
    current_speed = damaged_walk_speed

func reset_speed() -> void:
    current_speed = walk_speed

func is_running() -> bool:
    return current_speed == run_speed or current_speed == damaged_run_speed

func stop_movement() -> void:
    ## Next time the player moves we want a fresh snapshot, the camera may have
    ## changed while they were in a puzzle or a room transition
    _reference_locked = false
    if velocity_component:
        velocity_component.stop()

func movement(delta:float) -> void:
    if SettingsManager.control_scheme == GameSettings.ControlScheme.MODERN:
        _modern_movement(delta)
    else:
        _tank_movement(delta)


## Left/right rotate on the Y axis, forward/backward walk along the facing.
## Rotation works while aiming too, so you can line up a shot standing still.
func _tank_movement(delta:float) -> void:
    _tank_turn(delta)

    if is_aiming:
        stop_movement()
        return

    var move_input : float = Input.get_action_strength("forward") - Input.get_action_strength("backward")
    var desired_velocity : Vector3 = Vector3.ZERO

    if absf(move_input) > 0.01:
        var forward : Vector3 = -character_body.global_transform.basis.z
        forward.y = 0.0
        desired_velocity = forward.normalized() * move_input * current_speed

    _apply_velocity(desired_velocity, delta)


## The four keys are a direction on screen. The body turns to face it and walks,
## which gives 8 way movement on a keyboard and analog magnitude on a stick.
func _modern_movement(delta:float) -> void:
    ## While aiming we fall back to tank turning, so the camera doesn't get to
    ## decide where the character points
    if is_aiming:
        _tank_turn(delta)
        stop_movement()
        return

    var input : Vector2 = Input.get_vector("left", "right", "backward", "forward")
    if input.is_zero_approx():
        _reference_locked = false
        _apply_velocity(Vector3.ZERO, delta)
        return

    var reference : Basis = _get_reference_basis()
    ## reference.z points behind the camera, hence the minus on the forward axis
    var direction : Vector3 = (reference.x * input.x - reference.z * input.y).normalized()

    _face_direction(direction, delta)
    _apply_velocity(direction * current_speed * minf(input.length(), 1.0), delta)


func _tank_turn(delta:float) -> void:
    var turn_input : float = Input.get_action_strength("right") - Input.get_action_strength("left")
    if absf(turn_input) > 0.01:
        character_body.rotation.y -= turn_input * turn_speed * delta


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
