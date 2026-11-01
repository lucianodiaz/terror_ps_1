## Save slots list, opened in SAVE mode from a SavePoint and in LOAD mode
## from the main menu and the death screen. The scene is the autoload.
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
## Row last focused, by the keys or by hovering it
var _index: int = 0
var _is_open: bool = false
var _was_paused: bool = false
## Item taken from the inventory when saving, empty saves for free
var _consume_item_id: String = ""
## Given back on close, the main menu keeps its selection this way
var _previous_focus: Control = null
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


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
	_previous_focus = get_viewport().gui_get_focus_owner()
	## The world hides the cursor, the rows can be clicked
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_rows[_index].grab_focus()
	## The death screen keeps the tree paused, closing has to leave it that way
	_was_paused = get_tree().paused
	get_tree().paused = true


func close(saved: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	Input.mouse_mode = _previous_mouse_mode
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null
	get_tree().paused = _was_paused
	closed.emit(saved)


## Keys and pad are handled here and never go further, so for example Space
## doesn't also open the inventory underneath. The mouse is left to the rows:
## hovering one selects it, a click outside them does nothing.
func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouse:
		if event.is_action_pressed("cancel"):
			get_viewport().set_input_as_handled()
			close()
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_up"):
		_move_cursor(-1)
	elif event.is_action_pressed("ui_down"):
		_move_cursor(1)
	elif event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		_confirm(_index)


func _move_cursor(step: int) -> void:
	_rows[wrapi(_index + step, 0, _rows.size())].grab_focus()


func _on_row_focused(index: int) -> void:
	_index = index
	_slot_scroll.ensure_control_visible(_rows[_index])


func _confirm(index: int) -> void:
	if not _is_open:
		return
	match _mode:
		Mode.SAVE:
			if not SaveManager.save_game(index, _consume_item_id):
				return
			_rows[index].set_info(SaveManager.get_slot_info(index))
			close(true)
		Mode.LOAD:
			if not SaveManager.has_save(index):
				return
			SaveManager.load_game(index)


func _build_rows() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
	for i in SaveManager.SLOT_COUNT:
		var row: InfoSaveGame = ROW_SCENE.instantiate()
		_slot_list.add_child(row)
		row.set_index(i)
		row.focus_entered.connect(_on_row_focused.bind(i))
		row.pressed.connect(_confirm.bind(i))
		_rows.append(row)


func _refresh_rows() -> void:
	for i in _rows.size():
		_rows[i].set_info(SaveManager.get_slot_info(i))
