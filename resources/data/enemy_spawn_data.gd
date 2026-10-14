@tool
class_name EnemySpawnData
extends Resource

## Unique identifier e.g. "hall_entity_01"
@export var spawn_id: String = ""

@export var enemy_scene: PackedScene = null

@export var spawn_position: Vector3

## Assign spawn position from a node in the scene
@export var assign_from_node : NodePath:
    set(value):
        assign_from_node = value
        if Engine.is_editor_hint() and value != null:
            var scene_root = EditorInterface.get_edited_scene_root()
            if scene_root:
                var target_node = scene_root.get_node_or_null(value) as Node3D
                if target_node:
                    spawn_position = target_node.global_position

@export var required_flag : String = ""

@export var excluded_flag : String = ""