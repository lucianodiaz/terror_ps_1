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
	_spawn_room()

## Spawn the room will check the room state and spawn the room accordingly 
## e.g if an item is already picked up, it will queue free the item
@abstract func _spawn_room() -> void

## Doors and items persist through GameStateManager flags
func save_room_state() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.dead and not room_state.dead_spawn_ids.has(enemy.spawn_id):
			room_state.dead_spawn_ids.append(enemy.spawn_id)
