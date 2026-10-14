class_name FixedCamera
extends CameraBase



func activate() -> void:
    CameraManager.switch_to_camera(self)