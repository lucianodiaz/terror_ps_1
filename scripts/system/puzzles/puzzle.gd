## MUST IMPORTANT:
## EVERY PUZZLE MUST IMPLEMENT _ready() with super._ready()

@abstract
class_name Puzzle
extends Node3D

var solved: bool = false

signal puzzle_solved(puzzle_id: String)

@export var puzzle_id: String = ""
## Where the solved state is stored, so the puzzle stays solved when coming back.
## Doors read this same flag to unlock themselves.
## Empty uses a LOCAL flag "puzzle.<puzzle_id>.solved" in this room.
@export var solved_flag: FlagRef = null
## Extra flags changed when the puzzle is solved
@export var on_solved_actions: Array[FlagAction] = []

var _default_solved_flag: FlagRef = null


func _ready() -> void:
	var flag_value: Variant = get_solved_flag().get_value(self, false)
	if flag_value is bool and flag_value:
		solved = true
		_restore_solved()


func get_solved_flag() -> FlagRef:
	if solved_flag:
		return solved_flag
	if _default_solved_flag == null:
		var id: String = puzzle_id if puzzle_id != "" else String(name)
		_default_solved_flag = FlagRef.create(FlagRef.Scope.LOCAL, "puzzle.%s.solved" % id)
	return _default_solved_flag


## Writes the flags so doors and other rooms can see it, call it from complete_puzzle()
func mark_as_solved() -> void:
	solved = true
	get_solved_flag().set_value(true, self)
	FlagAction.apply_all(on_solved_actions, self)
	puzzle_solved.emit(puzzle_id)


## Called on _ready() when the puzzle was already solved on a previous visit
## e.g to leave the pieces in their final pose
func _restore_solved() -> void:
	pass


@abstract func complete_puzzle() -> void


@abstract func interact() -> void
