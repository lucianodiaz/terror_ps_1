class_name CameraTriggerZone
extends Area3D

@export var target_camera:CameraBase

@export var look_at_target:bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		target_camera.activate()
