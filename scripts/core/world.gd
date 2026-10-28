@tool
class_name World
extends Node3D

@export var initial_scene: String = ""
@export var animation_player: AnimationPlayer = null

var player: Player = null

signal on_animation_actioned
func _validate_property(property: Dictionary) -> void:
	if property.name != "initial_scene":
		return
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = RoomsPackage.get_editor_enum_hint()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if initial_scene:
		SceneManager.world = self
		# AudioManager.play_bgm("dark_room")
		if SaveManager.is_continuing():
			SaveManager.resume_world()
		else:
			SceneManager.load_room(initial_scene)
		
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("World._ready: player is null")
		return
	
	player.on_player_died.connect(_on_player_died)

func _on_player_died() -> void:
	DeathScreen.open()

func play_transition_animation(animation_name: String) -> AnimationPlayer:
	if animation_player == null or animation_name == "" or not animation_player.has_animation(animation_name):
		push_error("World.play_transition_animation: animation_player is null or animation_name is empty or animation_player does not have animation: ", animation_name)
		return
	animation_player.play(animation_name)
	return animation_player