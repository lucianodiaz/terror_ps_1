extends Node

var rooms_list: RoomsPackage = preload("res://resources/data/room_list.tres")
var current_room: Room = null
var world : World = null

func _save_room_state(room: Room) -> void:
	print("SceneManager._save_room_state: saving room state for room: ", room.room_state.room_id)
	pass


## This method is called by the World script to load a new room 
func load_room(new_room_name: String) -> void:
	_load_room(new_room_name)


func _on_door_requested_to_change_room(_door_name: String, new_room_name: String, target_door_name: String = "", transition_type: String = "") -> void:
	var transition_scene: PackedScene = TransitionsPackage.get_transition(transition_type)
	if transition_scene == null:
		_load_room(new_room_name, target_door_name)
		return
	_change_room_with_transition(transition_scene, new_room_name, target_door_name)


## Resident Evil style room change: fade out, play the door cutscene on an empty
## world, then fade into the new room
func _change_room_with_transition(transition_scene: PackedScene, new_room_name: String, target_door_name: String) -> void:
	var player : Player = get_tree().get_first_node_in_group("player")
	_set_player_busy(player, true)

	await world.play_transition_animation("out").animation_finished
	_free_current_room()

	var transition: DoorTransition = transition_scene.instantiate()
	world.add_child(transition)
	transition.take_camera()

	await world.play_transition_animation("in").animation_finished
	await transition.play()
	await world.play_transition_animation("out").animation_finished

	transition.queue_free()
	## The room cameras are gone, let the new room activate its own
	CameraManager.clear_current_camera()

	_spawn_room(new_room_name, target_door_name)
	await world.play_transition_animation("in").animation_finished
	_set_player_busy(player, false)


func _load_room(new_room_name: String, target_door_name: String = "") -> void:
	_free_current_room()
	if not _spawn_room(new_room_name, target_door_name):
		return
	world.play_transition_animation("in")


func _free_current_room() -> void:
	if current_room == null:
		return
	## We need to save state room and then queue free the current room
	_save_room_state(current_room)
	for door : Door in current_room.get_tree().get_nodes_in_group("doors"):
		if door:
			door.requested_to_change_room.disconnect(_on_door_requested_to_change_room)
	current_room.queue_free()
	current_room = null


## Instances the room and places the player, without any fade
func _spawn_room(new_room_name: String, target_door_name: String = "") -> bool:
	if new_room_name == "":
		push_error("SceneManager.load_room: new_room_name is empty")
		return false

	var room_scene: PackedScene = rooms_list.rooms[new_room_name]
	if room_scene == null:
		push_error("SceneManager.load_room: room_scene is null")
		return false

	var instance : Node = room_scene.instantiate()
	if not instance is Room:
		push_error(
			"SceneManager.load_room: scene '%s' root must use a script that extends Room."
			% room_scene.resource_path
		)
		instance.queue_free()
		return false

	var new_room: Room = instance
	current_room = new_room
	var father = get_tree().current_scene
	father.add_child(new_room)

	for door : Door in current_room.get_tree().get_nodes_in_group("doors"):
		if door:
			door.requested_to_change_room.connect(_on_door_requested_to_change_room)

	_place_player(current_room, target_door_name)
	return true


func _set_player_busy(player: Player, busy: bool) -> void:
	if player == null:
		return
	player.set_in_puzzle(busy)
	player.visible = not busy


func _place_player(room:Room, target_door_name:String) -> void:
	var player : Player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("SceneManager.load_room: player is null")
		return

	var spawn : Vector3 = current_room.room_state.spawn_player_position
	var spawn_basis : Basis = Basis.IDENTITY
	var spawn_rotation : Vector3 = Vector3.ZERO

	if target_door_name != "":
		for door in room.get_tree().get_nodes_in_group("doors"):
			if door is Door and door.door_name == target_door_name:
				if door.spawn_player_position:
					spawn = door.spawn_player_position.global_position
					spawn_basis = door.spawn_player_position.global_basis
					spawn_rotation = door.spawn_player_position.global_rotation
				break


	player.global_position = spawn
	player.global_basis = spawn_basis
	player.rotation = spawn_rotation
	player.movement_player_component.velocity_component.stop()
