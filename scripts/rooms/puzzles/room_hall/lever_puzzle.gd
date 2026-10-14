class_name LeverPuzzle
extends Puzzle

@export var levers: Array[Lever] = []
## Target state for each lever, in the same order as `levers`
@export var condition: Array[Lever.State] = []
## Levers toggled when selecting lever i, as offsets from i (wrapping around), in toggle order
## eg: [0, 1] move itself and the next neighbor 
## eg: [-1, 0, 1] move itself, the previous neighbor and the next neighbor
## eg: [0, 2] move itself and the 2nd neighbor
@export var affected_offsets: Array[int] = [0, 1]
@export var puzzle_gui: LeverPuzzleGUI
@export var puzzle_camera: CameraBase
@export var puzzle_solved_camera: CameraBase

var player:Player = null
var _is_moving_levers: bool = false


func _ready() -> void:
	if levers.is_empty():
		push_warning("LeverPuzzle.levers is empty")
		return
	if condition.size() != levers.size():
		push_warning("LeverPuzzle.condition must have one state per lever")
		return
	if puzzle_gui == null:
		push_warning("LeverPuzzle.puzzle_gui is not set")
		return
	if puzzle_gui.indicators.size() != levers.size():
		push_warning("LeverPuzzle.puzzle_gui must have one indicator per lever")
		return

	puzzle_gui.visible = false
	puzzle_gui.lever_selected.connect(on_lever_selected)
	puzzle_gui.exit_puzzle.connect(_on_exit_puzzle)
	super._ready()


func _restore_solved() -> void:
	for i in levers.size():
		levers[i].state = condition[i]


func on_lever_selected(indicator: int) -> void:
	if solved or _is_moving_levers:
		return
	_is_moving_levers = true
	for offset in affected_offsets:
		await levers[posmod(indicator + offset, levers.size())].toggle()
	_is_moving_levers = false
	check_if_puzzle_is_complete()

func check_if_puzzle_is_complete() -> void:
	for i in levers.size():
		if levers[i].state != condition[i]:
			return
	complete_puzzle()

func _on_exit_puzzle() -> void:
	puzzle_gui.player = null
	puzzle_gui.visible = false
	CameraManager.switch_to_last_camera()
	player.visible = true
	player.set_in_puzzle(false)

func complete_puzzle() -> void:
	print("Puzzle complete")
	mark_as_solved()
	puzzle_gui.player = null
	puzzle_gui.visible = false
	#Change To Solve Place state
	await get_tree().create_timer(0.7).timeout
	CameraManager.switch_to_camera(puzzle_solved_camera)
	await get_tree().create_timer(3).timeout
	CameraManager.switch_to_last_camera()
	player.visible = true
	player.set_in_puzzle(false)


func interact() -> void:
	if solved:
		return
	puzzle_gui.visible = true
	player.set_in_puzzle(true)
	player.visible = false
	CameraManager.switch_to_puzzle_camera(puzzle_camera)
	puzzle_gui.player = player


func _on_area_3d_area_entered(area: Area3D) -> void:
	if solved:
		return
	if area.owner.is_in_group("player"):
		player = area.owner as Player
		

func _on_area_3d_area_exited(area: Area3D) -> void:
	if area == null or area.owner == null:
		return
	if area.owner.is_in_group("player"):
		player = null
		puzzle_gui.player = null
