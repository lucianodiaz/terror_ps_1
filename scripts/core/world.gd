@tool
class_name World
extends Node3D

@export var initial_scene: String = ""
@export var animation_player: AnimationPlayer = null

signal on_animation_actioned
func _validate_property(property: Dictionary) -> void:
	if property.name != "initial_scene":
		return
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = RoomsPackage.get_editor_enum_hint()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if initial_scene:
		SceneManager.world = self
		# AudioManager.play_bgm("dark_room")
		SceneManager.load_room(initial_scene)


func play_transition_animation(animation_name: String) -> AnimationPlayer:
	if animation_player == null or animation_name == "" or not animation_player.has_animation(animation_name):
		push_error("World.play_transition_animation: animation_player is null or animation_name is empty or animation_player does not have animation: ", animation_name)
		return
	animation_player.play(animation_name)
	return animation_player