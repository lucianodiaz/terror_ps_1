## Save slots list, opened in SAVE mode from a SavePoint and in LOAD mode
## from the death screen. The scene is the autoload.
extends CanvasLayer

enum Mode { SAVE, LOAD }

signal closed(saved: bool)

const ROW_SCENE: PackedScene = preload("res://scenes/UI/info_save_game.tscn")
const SAVE_TITLE: String = "SAVE GAME"
const LOAD_TITLE: String = "LOAD GAME"

@onready var _title_label: Label = %TitleLabel
@onready var _slot_scroll: ScrollContainer = %SlotScroll
@onready var _slot_list: VBoxContainer = %SlotList

var _rows: Array[InfoSaveGame] = []
var _mode: Mode = Mode.LOAD
var _index: int = 0
var _is_open: bool = false
var _was_paused: bool = false
## Item taken from the inventory when saving, empty saves for free
var _consume_item_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_rows()
	SaveManager.world_reloading.connect(close)
	visible = false


func is_open() -> bool:
	return _is_open


func open(mode: Mode, consume_item_id: String = "") -> void:
	if _is_open:
		return
	_mode = mode
	_consume_item_id = consume_item_id
	_index = 0
	_is_open = true
	_title_label.text = SAVE_TITLE if mode == Mode.SAVE else LOAD_TITLE
	_refresh_rows()
	_slot_scroll.scroll_vertical = 0
	visible = true
	## The death screen keeps the tree paused, closing has to leave it that way
	_was_paused = get_tree().paused
	get_tree().paused = true


func close(saved: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	get_tree().paused = _was_paused
	closed.emit(saved)


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_up"):
		_move_cursor(-1)
	elif event.is_action_pressed("ui_down"):
		_move_cursor(1)
	elif event.is_action_pressed("run") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		_confirm()


func _move_cursor(step: int) -> void:
	_index = wrapi(_index + step, 0, _rows.size())
	_refresh_selection()
	_slot_scroll.ensure_control_visible(_rows[_index])


func _confirm() -> void:
	match _mode:
		Mode.SAVE:
			if not SaveManager.save_game(_index, _consume_item_id):
				return
			_rows[_index].set_info(SaveManager.get_slot_info(_index))
			close(true)
		Mode.LOAD:
			if not SaveManager.has_save(_index):
				return
			SaveManager.load_game(_index)


func _build_rows() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
	for i in SaveManager.SLOT_COUNT:
		var row: InfoSaveGame = ROW_SCENE.instantiate()
		_slot_list.add_child(row)
		row.set_index(i)
		_rows.append(row)


func _refresh_rows() -> void:
	for i in _rows.size():
		_rows[i].set_info(SaveManager.get_slot_info(i))
	_refresh_selection()


func _refresh_selection() -> void:
	for i in _rows.size():
		_rows[i].set_selected(i == _index)
