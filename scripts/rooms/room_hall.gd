extends Room
class_name RoomHall

## Fires when the west, east and north doors are all unlocked
@export var all_doors_event: FlagTrigger
@export var east_door_event: FlagTrigger
@export var animation_player: AnimationPlayer
@export var camera_animation_all_doors_opened: CameraBase

func _ready() -> void:
	super._ready()
	if all_doors_event:
		all_doors_event.triggered.connect(_on_all_doors_opened)
		if all_doors_event.has_fired():
			_apply_all_doors_opened_pose()
		
	if east_door_event:
		east_door_event.triggered.connect(_on_east_door_opened)

func _on_east_door_opened(_trigger: FlagTrigger) -> void:
	print("[RoomHall] - East door opened")
	animation_player.play("unlock_east_door")


func _spawn_room() -> void:
	print("Spawning room hall")
	pass


func _on_all_doors_opened(_trigger: FlagTrigger) -> void:
	print("Las 3 puertas estan abiertas: aca va la cinematica")
	CameraManager.switch_to_puzzle_camera(camera_animation_all_doors_opened)
	animation_player.play("open_door")
	await animation_player.animation_finished
	CameraManager.switch_to_last_camera()


## Leaves the way to the stairs already open when coming back to the room
func _apply_all_doors_opened_pose() -> void:
	animation_player.play("open_door")
	animation_player.seek(animation_player.current_animation_length, true)
	animation_player.stop(true)
