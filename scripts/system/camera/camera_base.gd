@abstract 
class_name CameraBase
extends Camera3D

@export var is_active:bool = false

func _ready() -> void:
	if is_active:
		CameraManager.switch_to_camera(self)


@abstract func activate() -> void
