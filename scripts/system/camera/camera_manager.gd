extends Node

var last_camera: CameraBase = null
var current_camera: CameraBase

signal camera_changed(new_camera:CameraBase)

func switch_to_camera(new_camera:CameraBase) -> void:
	if current_camera == new_camera:
		return
	
	if new_camera == null:
		return
	
	_clear_if_valid(current_camera)
	
	new_camera.make_current()
	current_camera = new_camera
	camera_changed.emit(current_camera)


func switch_to_puzzle_camera(new_camera: CameraBase) -> void:
	if current_camera == new_camera:
		return
	
	if new_camera == null:
		return
	
	_clear_if_valid(current_camera)
	
	last_camera = current_camera

	new_camera.make_current()
	current_camera = new_camera
	camera_changed.emit(current_camera)

func switch_to_last_camera() -> void:
	if not is_instance_valid(last_camera):
		last_camera = null
		return
	
	_clear_if_valid(current_camera)
	
	last_camera.make_current()
	current_camera = last_camera
	camera_changed.emit(current_camera)


## Drops the references without touching the cameras, for when the room they
## belong to is being freed and something else takes over the viewport
func clear_current_camera() -> void:
	current_camera = null
	last_camera = null


func get_current_camera() -> CameraBase:
	return current_camera


## Left untyped on purpose: the camera dies with its room, and a CameraBase
## parameter would reject the dangling reference before we get to check it
func _clear_if_valid(camera: Variant) -> void:
	if is_instance_valid(camera):
		camera.clear_current()
