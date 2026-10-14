class_name DoorTransition
extends Node3D

## Resident Evil style cutscene played while changing rooms.
## It lives under World, with the old room already freed and the new one not
## loaded yet, so its camera only sees the model inside this scene.

@export var camera: Camera3D = null
@export var animation_player: AnimationPlayer = null
@export var animation_name: StringName = &"open"


## Takes over the viewport, the room cameras are gone at this point
func take_camera() -> void:
	if camera == null:
		push_error("DoorTransition.take_camera: camera is not set")
		return
	camera.make_current()


func play() -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		push_error("DoorTransition.play: missing animation '%s'" % animation_name)
		return
	animation_player.play(animation_name)
	await animation_player.animation_finished
