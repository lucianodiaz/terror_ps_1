## On screen messages, Resident Evil style.
## The autoload is named MessageManager, the class_name is only here so other
## scripts can write GameMessages.Mode.EXAMINE with static typing.
class_name GameMessages
extends Node

const VIEW_SCENE : PackedScene = preload("res://scenes/UI/ui_messages.tscn")

## HINT: short notice, does not block, closes on its own.
## EXAMINE: blocks the player until they confirm with the action button.
enum Mode { HINT, EXAMINE }

signal message_shown(text: String, mode: Mode)
signal message_closed()

var _view: MessageView = null
var _layer: CanvasLayer = null
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _hint_time_left: float = 0.0
var _owns_player_block: bool = false


func _ready() -> void:
	## Own canvas with a negative layer so the room fade in world.tscn, which
	## lives on the default canvas, draws over the message instead of under it
	_layer = CanvasLayer.new()
	_layer.name = "MessageLayer"
	_layer.layer = -1
	add_child(_layer)

	_view = VIEW_SCENE.instantiate()
	_layer.add_child(_view)
	set_process(false)


func show_hint(text: String) -> void:
	_enqueue(text, Mode.HINT)


func show_examine(text: String) -> void:
	_enqueue(text, Mode.EXAMINE)


func is_showing() -> bool:
	return not _current.is_empty()


func is_blocking() -> bool:
	return is_showing() #and _current["mode"] == Mode.EXAMINE


## The first press finishes the typing, the next one closes the message
func advance() -> void:
	if not is_showing():
		return
	if not _view.is_fully_revealed():
		_view.reveal_all()
		return
	_show_next()


func clear() -> void:
	_queue.clear()
	if is_showing():
		_show_next()


func _enqueue(text: String, mode: Mode) -> void:
	if text == "":
		return
	_queue.append({ "text": text, "mode": mode })
	if not is_showing():
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_current = {}
		set_process(false)
		_view.hide_message()
		_release_player()
		message_closed.emit()
		return

	_current = _queue.pop_front()
	var text: String = _current["text"]
	var mode: Mode = _current["mode"]

	_view.show_text(text)
	#Block the player for all messages
	# if mode == Mode.EXAMINE or mode == Mode.HINT:
	_block_player()
	set_process(false)
	# else:
	# 	## The notice has to last long enough to finish typing and then be read
	# 	_hint_time_left = _view.get_reveal_time(text) + _view.hint_hold_time
	# 	set_process(true)

	message_shown.emit(text, mode)


func _process(delta: float) -> void:
	_hint_time_left -= delta
	if _hint_time_left <= 0.0:
		_show_next()


func _block_player() -> void:
	if _owns_player_block:
		return
	var player: Player = _get_player()
	if player == null:
		return
	## Already blocked means the block belongs to someone else, a room
	## transition or a puzzle, and it is not ours to release later
	if player.is_in_puzzle:
		return
	_owns_player_block = true
	player.set_in_puzzle(true)


func _release_player() -> void:
	if not _owns_player_block:
		return
	_owns_player_block = false
	var player: Player = _get_player()
	if player:
		player.set_in_puzzle(false)


func _get_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player
