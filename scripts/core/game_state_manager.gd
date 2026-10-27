extends Node

## Single source of truth for runtime flags.
## Local flags are keyed by room_id, so any room can read or write the flags
## of another room even when that room isn't loaded.

signal flag_changed(scope: FlagRef.Scope, room_id: String, flag_name: String, value: Variant)

const DEAD_SPAWN_PREFIX: String = "dead:"

var global_flags: Dictionary[String, Variant] = {}
var room_flags: Dictionary[String, Dictionary] = {}


func set_global_flag(flag_name: String, value: Variant) -> void:
	if global_flags.has(flag_name) and _is_same_value(global_flags[flag_name], value):
		return
	global_flags[flag_name] = value
	flag_changed.emit(FlagRef.Scope.GLOBAL, "", flag_name, value)


func get_global_flag(flag_name: String, default: Variant = null) -> Variant:
	return global_flags.get(flag_name, default)


func has_global_flag(flag_name: String) -> bool:
	return global_flags.has(flag_name)


func set_room_flag(room_id: String, flag_name: String, value: Variant) -> void:
	if room_id == "":
		push_error("GameStateManager.set_room_flag: room_id is empty")
		return
	if not room_flags.has(room_id):
		room_flags[room_id] = {}
	var flags: Dictionary = room_flags[room_id]
	if flags.has(flag_name) and _is_same_value(flags[flag_name], value):
		return
	flags[flag_name] = value
	flag_changed.emit(FlagRef.Scope.LOCAL, room_id, flag_name, value)


func get_room_flag(room_id: String, flag_name: String, default: Variant = null) -> Variant:
	if not room_flags.has(room_id):
		return default
	return room_flags[room_id].get(flag_name, default)


func has_room_flag(room_id: String, flag_name: String) -> bool:
	return room_flags.has(room_id) and room_flags[room_id].has(flag_name)


## Seeds the local flags of a room the first time it is visited.
func initialize_room_flags(room_id: String, initial_flags: Dictionary) -> void:
	if room_id == "" or room_flags.has(room_id):
		return
	room_flags[room_id] = initial_flags.duplicate(true)


## Dead enemies are stored as local room flags, so they are saved and reset with the rest of the state
func mark_spawn_dead(room_id: String, spawn_id: String) -> void:
	set_room_flag(room_id, DEAD_SPAWN_PREFIX + spawn_id, true)


func is_spawn_dead(room_id: String, spawn_id: String) -> bool:
	return get_room_flag(room_id, DEAD_SPAWN_PREFIX + spawn_id, false) == true


func get_room_state() -> RoomState:
	return SceneManager.current_room.room_state


## Clears every runtime flag, for a new game or a retry after game over
func reset() -> void:
	global_flags.clear()
	room_flags.clear()


func export_state() -> Dictionary:
	return {
		"global_flags": global_flags.duplicate(true),
		"room_flags": room_flags.duplicate(true),
	}


func import_state(data: Dictionary) -> void:
	global_flags.assign(data.get("global_flags", {}))
	room_flags.assign(data.get("room_flags", {}))


func _is_same_value(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b
