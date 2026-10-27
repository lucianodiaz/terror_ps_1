@tool
class_name RoomState
extends Resource

## Design data only. This resource is shared by every instance of the room scene,
## so never write to it at runtime: game progress lives in GameStateManager.

@export var room_id: String = ""

## Misc room name use for UI display
@export var room_name: String = ""

## Local flags copied to GameStateManager the first time the room is visited
@export var initial_flags: Dictionary[String, Variant] = {}

@export var spawn_player_position: Vector3 = Vector3.ZERO

## Assign spawn position from a node in the scene
@export var assign_from_node : NodePath:
	set(value):
		assign_from_node = value
		if Engine.is_editor_hint() and value != null:
			var scene_root = EditorInterface.get_edited_scene_root()
			if scene_root:
				var target_node = scene_root.get_node_or_null(value) as Node3D
				if target_node:
					spawn_player_position = target_node.global_position



func _validate_property(property: Dictionary) -> void:
	if property.name != "room_id":
		return
	
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = RoomsPackage.get_editor_enum_hint()