class_name VelocityComponent
extends Node


@export var max_speed: float = 100.0

@export var acceleration_coefficient: float = 10.0

@export var velocity_threshold: float = 0.1


var velocity:Vector3
var velocity_override:Vector3
var speed_multiplier:float = 1.0
var speed_percent_multiplier:float = 0.0
var acceleration_coefficient_multiplier:float = 1.0
var direction:Vector3
var calculated_max_speed:float :
    get:
        return max_speed * (1.0 + speed_percent_multiplier) * speed_multiplier

var speed_percent:float :
    get:
        if calculated_max_speed <= 0 : return 0.0
        return min(velocity.length() / calculated_max_speed,1.0)

var speed_percent_modifiers:Dictionary[String,float]


func _ready() -> void:
    set_process(false)


func accelerate_to_velocity(target_vel: Vector3) -> void:
    var t : float = 1.0 - exp(-acceleration_coefficient * 0.1)
    velocity = velocity.lerp(target_vel, clamp(t, 0.0, 1.0))

func accelerate_in_direction(dir:Vector3) -> void:
    direction = dir
    accelerate_to_velocity(direction * calculated_max_speed)

func get_max_velocity(dir:Vector3) -> Vector3:
    return dir * calculated_max_speed


func maximize_velocity(dir:Vector3) -> void:
    velocity = get_max_velocity(dir)

func decelerate() -> void:
    accelerate_to_velocity(Vector3.ZERO)


func move(character_body:CharacterBody3D, delta:float = -1.0, apply_movement:bool = true) -> void:
    if delta < 0.0:
        delta = get_physics_process_delta_time()
    
    var movement : Vector3 = velocity if apply_movement else Vector3.ZERO

    character_body.velocity = movement
    character_body.move_and_slide()

func set_max_speed(new_speed:float) -> void:
    max_speed = new_speed


func add_speed_percent_modifier(modifier_name:String, change:float) -> void:
    if !speed_percent_modifiers.has(modifier_name):
        return
    var current_value:float
    current_value = speed_percent_modifiers[modifier_name] + change
    speed_percent_modifiers[modifier_name] = current_value


func set_percent_modifier(modifier_name:String, val:float) -> void:
    speed_percent_modifiers[modifier_name] = val

func get_speed_percet_modifier(modifier_name:String) -> float:
    if !speed_percent_modifiers.has(modifier_name):
        return 0.0
    return speed_percent_modifiers[modifier_name]

func stop_movement() -> void:
    velocity = Vector3.ZERO

func stop() -> void:
    stop_movement()