## MUST IMPORTANT: 
## EVERY ROOM MUST IMPLEMENT _ready() with super._ready()

@abstract class_name Room
extends Node3D

@export var room_state : RoomState = null
@export var possible_spawns : Array[EnemySpawnData] = []

var spawn_player_position: Vector3 = Vector3.ZERO


## Runs before the children _ready(), so doors and pickups already see the initial flags
func _enter_tree() -> void:
	if room_state:
		GameStateManager.initialize_room_flags(room_state.room_id, room_state.initial_flags)


func _ready() -> void:
	_spawn_enemies()
	_spawn_room()

## Spawn the room will check the room state and spawn the room accordingly 
## e.g if an item is already picked up, it will queue free the item
@abstract func _spawn_room() -> void


func get_room_id() -> String:
	return room_state.room_id if room_state else ""


func _spawn_enemies() -> void:
	var room_id := get_room_id()
	for spawn_data in possible_spawns:
		if spawn_data == null or spawn_data.enemy_scene == null:
			continue
		if GameStateManager.is_spawn_dead(room_id, spawn_data.spawn_id):
			continue
		if spawn_data.required_flag != "" and not _has_flag(room_id, spawn_data.required_flag):
			continue
		if spawn_data.excluded_flag != "" and _has_flag(room_id, spawn_data.excluded_flag):
			continue
		_spawn_enemy(spawn_data)


func _spawn_enemy(data: EnemySpawnData) -> void:
	var enemy: Node3D = data.enemy_scene.instantiate()
	enemy.spawn_id = data.spawn_id
	enemy.position = data.spawn_position
	enemy.on_die.connect(_on_enemy_died)
	add_child(enemy)


func _on_enemy_died(enemy: Node3D) -> void:
	GameStateManager.mark_spawn_dead(get_room_id(), enemy.spawn_id)


func _has_flag(room_id: String, flag_name: String) -> bool:
	return GameStateManager.has_room_flag(room_id, flag_name) \
		or GameStateManager.has_global_flag(flag_name)
