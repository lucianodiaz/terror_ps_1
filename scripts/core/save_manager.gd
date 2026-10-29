extends Node

## Save slots on disk, written from a SavePoint and read from the LoadScreen.
## Continue on the death screen loads the last slot saved or loaded in this
## session, without one it starts a new game.

signal world_reloading()

const SLOT_COUNT: int = 10
const SAVE_DIR: String = "user://saves/"
const SAVE_FILE: String = "slot_%d.save"
const SAVE_VERSION: int = 1
const WORLD_SCENE: String = "res://scenes/world.tscn"

## Slot data waiting for the World to be reloaded, empty on a new game
var _pending: Dictionary = {}
var _is_continuing: bool = false
var _last_slot: int = -1


func get_slot_path(slot: int) -> String:
	return SAVE_DIR + SAVE_FILE % slot


func has_save(slot: int) -> bool:
	return _is_valid_slot(slot) and FileAccess.file_exists(get_slot_path(slot))


## Empty when the slot has no file or it can't be read
func get_slot_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	return _read_slot(slot)


## consume_item_id is taken before writing, so the file already reflects it
func save_game(slot: int, consume_item_id: String = "") -> bool:
	if not _is_valid_slot(slot):
		push_error("SaveManager.save_game: invalid slot %d" % slot)
		return false
	if consume_item_id != "" and not Inventory.remove_item(consume_item_id):
		return false
	var data: Dictionary = _collect_data()
	if data.is_empty() or not _write_slot(slot, data):
		if consume_item_id != "":
			Inventory.add_item(consume_item_id)
		return false
	_last_slot = slot
	return true


func load_game(slot: int) -> void:
	var data: Dictionary = get_slot_info(slot)
	if data.is_empty():
		push_error("SaveManager.load_game: slot %d has no save" % slot)
		return
	_last_slot = slot
	## Deep copies, otherwise playing after loading would modify the pending data
	GameStateManager.import_state(data.get("game_state", {}).duplicate(true))
	Inventory.import_state(data.get("inventory", {}).duplicate(true))
	_pending = data
	_is_continuing = true
	_restart_world()


func continue_game() -> void:
	if has_save(_last_slot):
		load_game(_last_slot)
	else:
		new_game()


func new_game() -> void:
	GameStateManager.reset()
	Inventory.reset()
	_pending = {}
	_is_continuing = false
	_restart_world()


## True when the World has to start in the saved room instead of its initial one
func is_continuing() -> bool:
	return _is_continuing


## Called by the World on _ready after a load
func resume_world() -> void:
	_is_continuing = false
	var data: Dictionary = _pending
	_pending = {}
	SceneManager.load_room(data.get("room_key", ""))
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var saved_position: Variant = data.get("player_position")
	var saved_rotation: Variant = data.get("player_rotation")
	if saved_position is Vector3:
		player.global_position = saved_position
	if saved_rotation is Vector3:
		player.rotation = saved_rotation
	var health: float = float(data.get("health", -1.0))
	if player.health_component and health > 0.0:
		player.health_component.restore_health(health)


## Frees the room and world references and changes to a fresh world scene, so the
## player, enemies and cameras start clean. Works from the main menu and from the world.
func _restart_world() -> void:
	world_reloading.emit()
	SceneManager.reset()
	CameraManager.clear_current_camera()
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)


func _collect_data() -> Dictionary:
	var room: Room = SceneManager.current_room
	if room == null or SceneManager.current_room_name == "":
		push_error("SaveManager: there is no room loaded to save")
		return {}
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("SaveManager: player is null")
		return {}
	var health: float = -1.0
	if player.health_component:
		health = player.health_component.current_health
	return {
		"version": SAVE_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"room_key": SceneManager.current_room_name,
		"room_display_name": _get_room_display_name(room),
		"player_position": player.global_position,
		"player_rotation": player.rotation,
		"health": health,
		"game_state": GameStateManager.export_state(),
		"inventory": Inventory.export_state(),
	}


func _get_room_display_name(room: Room) -> String:
	if room.room_state == null:
		return SceneManager.current_room_name
	if room.room_state.room_name != "":
		return room.room_state.room_name
	return room.room_state.room_id if room.room_state.room_id != "" else SceneManager.current_room_name


func _write_slot(slot: int, data: Dictionary) -> bool:
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if dir_error != OK:
		push_error("SaveManager: can't create '%s', error %d" % [SAVE_DIR, dir_error])
		return false
	var file: FileAccess = FileAccess.open(get_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: can't write slot %d, error %d" % [slot, FileAccess.get_open_error()])
		return false
	file.store_var(data)
	file.close()
	return true


func _read_slot(slot: int) -> Dictionary:
	var file: FileAccess = FileAccess.open(get_slot_path(slot), FileAccess.READ)
	if file == null:
		push_error("SaveManager: can't read slot %d, error %d" % [slot, FileAccess.get_open_error()])
		return {}
	var data: Variant = file.get_var()
	file.close()
	if not data is Dictionary or not data.has("room_key"):
		push_error("SaveManager: slot %d is corrupted" % slot)
		return {}
	return data


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT
