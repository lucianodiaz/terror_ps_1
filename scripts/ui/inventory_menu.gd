## Resident Evil 3 style inventory. The scene is the autoload, so this
## script is both the controller and the root of the view.
## Moving up from the top row of the grid reaches ARCHIVO / MAPA, and from
## there SALIDA, like the original menu.
extends CanvasLayer

enum State { CLOSED, BROWSE, COMMANDS, COMBINE_TARGET, CHECK, FILES, READING }
enum Focus { GRID, EXIT, FILES, MAP }
enum Command { USE, COMBINE, CHECK }

const GRID_COLUMNS: int = 2
const GRID_ROWS: int = 4
const SLOT_SIZE : Vector2= Vector2(258, 160)

const FILE_COLUMNS: int = 5
const FILE_ROWS: int = 3
const FILES_PER_PAGE: int = FILE_COLUMNS * FILE_ROWS
const FILE_SLOT_SIZE : Vector2 = Vector2(160, 112)
const EMPTY_FILE_TEXT: String = "VACIO"
const NO_FILES_TEXT: String = "Ningun archivo."
## Distance the reader text slides in from when turning a page
const READER_SLIDE: float = 240.0
const READER_SLIDE_TIME: float = 0.25

const COMMAND_COUNT: int = 3
const USE_LABEL: String = "USAR"
const EQUIP_LABEL: String = "EQUIPAR"
const UNEQUIP_LABEL: String = "QUITAR"
const NO_MAP_TEXT: String = "No hay mapa disponible."

const TEXT_NORMAL : Color = Color(0.92, 0.92, 0.96)
const TEXT_DIMMED : Color= Color(0.5, 0.52, 0.6)
const EMPTY_FILE_COLOR : Color = Color(0.3, 0.3, 0.33)
const AMOUNT_COLOR : Color = Color(0.3, 1.0, 0.4)
const EQUIPPED_COLOR : Color= Color(1.0, 0.85, 0.3)

## Health ratio thresholds, checked from the top, the first one that fits wins
const CONDITIONS: Array[Dictionary] = [
	{ "min": 0.66, "text": "Bien", "color": Color(0.25, 1.0, 0.35), "bpm": 60.0 },
	{ "min": 0.33, "text": "Cuidado", "color": Color(1.0, 0.85, 0.2), "bpm": 85.0 },
	{ "min": 0.15, "text": "Cuidado", "color": Color(1.0, 0.5, 0.1), "bpm": 105.0 },
	{ "min": 0.1, "text": "Peligro", "color": Color(1.0, 0.2, 0.2), "bpm": 135.0 },
]

@onready var _grid: GridContainer = %Grid
@onready var _status_label: Label = %StatusLabel
@onready var _ecg: EcgMonitor = %Ecg
@onready var _equip_icon: TextureRect = %EquipIcon
@onready var _equip_name: Label = %EquipName
@onready var _exit_button: Label = %ExitButton
@onready var _files_button: Label = %FilesButton
@onready var _map_button: Label = %MapButton
@onready var _commands: Panel = %Commands
@onready var _cmd_labels: Array[Label] = [%Use, %Combine, %Check]
@onready var _preview_panel: Panel = %PreviewPanel
@onready var _preview_icon: TextureRect = %PreviewIcon
@onready var _preview_name: Label = %PreviewName
@onready var _files_panel: Panel = %FilesPanel
@onready var _files_grid: GridContainer = %FilesGrid
@onready var _files_prev: Label = %FilesPrev
@onready var _files_next: Label = %FilesNext
@onready var _message_label: Label = %MessageLabel
@onready var _reader: Control = %Reader
@onready var _reader_image: TextureRect = %ReaderImage
@onready var _reader_page_root: Control = %ReaderPage
@onready var _reader_text: Label = %ReaderText
@onready var _reader_prev: Label = %ReaderPrev
@onready var _reader_next: Label = %ReaderNext
@onready var _reader_exit: Label = %ReaderExit

var _state: State = State.CLOSED
var _focus: Focus = Focus.GRID
var _cursor: int = 0
var _command: Command = Command.USE
var _file_cursor: int = 0
var _combine_from: int = -1
var _status: String = ""
var _slots: Array[Panel] = []
var _file_slots: Array[Panel] = []
var _reader_pages: PackedStringArray = PackedStringArray()
var _reader_page: int = 0
var _reader_tween: Tween = null

var _slot_normal: StyleBoxFlat = null
var _slot_selected: StyleBoxFlat = null
var _slot_combine: StyleBoxFlat = null
var _button_normal: StyleBoxFlat = null
var _button_focused: StyleBoxFlat = null
var _amount_settings: LabelSettings = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_styles()
	_build_slots()
	_build_file_slots()
	Inventory.inventory_changed.connect(_on_inventory_changed)
	Inventory.files_changed.connect(_on_inventory_changed)
	Inventory.equipment_changed.connect(_on_equipment_changed)
	visible = false


func is_open() -> bool:
	return _state != State.CLOSED


func try_open() -> void:
	if is_open():
		return
	if MessageManager.is_blocking():
		return
	var player: Player = _get_player()
	if player != null and player.is_in_puzzle:
		return
	open()


func open() -> void:
	_cursor = 0
	_focus = Focus.GRID
	_command = Command.USE
	_file_cursor = 0
	_combine_from = -1
	_status = ""
	_set_state(State.BROWSE)
	visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	if not is_open():
		return
	_state = State.CLOSED
	_reader.visible = false
	visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if is_open():
			close()
		else:
			try_open()
		get_viewport().set_input_as_handled()
		return
	if not is_open():
		return
	_handle_open_input(event)


func _handle_open_input(event: InputEvent) -> void:
	match _state:
		State.BROWSE:
			_handle_browse(event)
		State.COMMANDS:
			_handle_commands(event)
		State.COMBINE_TARGET:
			_handle_combine_target(event)
		State.CHECK:
			_handle_check(event)
		State.FILES:
			_handle_files(event)
		State.READING:
			_handle_reading(event)
	get_viewport().set_input_as_handled()


func _handle_browse(event: InputEvent) -> void:
	if event.is_action_pressed("run"):
		close()
		return
	if event.is_action_pressed("aim"):
		_open_files()
		return
	if _move_focus(event):
		_status = ""
		_refresh()
		return
	if not event.is_action_pressed("action"):
		return
	match _focus:
		Focus.GRID:
			if Inventory.get_slot(_cursor).is_empty():
				return
			_command = Command.USE
			_set_state(State.COMMANDS)
		Focus.EXIT:
			close()
			return
		Focus.FILES:
			_open_files()
			return
		Focus.MAP:
			_status = NO_MAP_TEXT
	_refresh()


func _handle_commands(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_command = wrapi(_command - 1, 0, COMMAND_COUNT) as Command
		_refresh()
	elif event.is_action_pressed("ui_down"):
		_command = wrapi(_command + 1, 0, COMMAND_COUNT) as Command
		_refresh()
	elif event.is_action_pressed("run"):
		_set_state(State.BROWSE)
		_refresh()
	elif event.is_action_pressed("action"):
		_run_command()


func _handle_combine_target(event: InputEvent) -> void:
	if _move_grid(event):
		_status = "Combinar con que?"
		_refresh()
		return
	if event.is_action_pressed("run"):
		_combine_from = -1
		_status = ""
		_set_state(State.BROWSE)
		_refresh()
	elif event.is_action_pressed("action"):
		_finish_combine()


func _handle_check(event: InputEvent) -> void:
	if event.is_action_pressed("action") or event.is_action_pressed("run"):
		_set_state(State.COMMANDS)
		_refresh()


func _handle_files(event: InputEvent) -> void:
	if event.is_action_pressed("aim") or event.is_action_pressed("run"):
		_status = ""
		_focus = Focus.FILES
		_set_state(State.BROWSE)
		_refresh()
		return
	if Inventory.files.is_empty():
		return
	if _move_file_cursor(event):
		_refresh()
	elif event.is_action_pressed("action"):
		_open_reader(_file_cursor)


## Moves inside the page, going past the left or right edge turns the page
func _move_file_cursor(event: InputEvent) -> bool:
	var count: int = Inventory.files.size()
	var page: int = floori(_file_cursor / float(FILES_PER_PAGE))
	var local: int = _file_cursor % FILES_PER_PAGE
	var col: int = local % FILE_COLUMNS
	var row: int = floori(local / float(FILE_COLUMNS))
	var target: int = _file_cursor
	if event.is_action_pressed("left"):
		if col > 0:
			target -= 1
		elif page > 0:
			target = (page - 1) * FILES_PER_PAGE + row * FILE_COLUMNS + FILE_COLUMNS - 1
	elif event.is_action_pressed("right"):
		if col < FILE_COLUMNS - 1:
			target += 1
		elif (page + 1) * FILES_PER_PAGE < count:
			target = mini((page + 1) * FILES_PER_PAGE + row * FILE_COLUMNS, count - 1)
	elif event.is_action_pressed("forward"):
		if row > 0:
			target -= FILE_COLUMNS
	elif event.is_action_pressed("backward"):
		if row < FILE_ROWS - 1:
			target += FILE_COLUMNS
	else:
		return false
	## Empty slots can't be selected
	if target == _file_cursor or target >= count:
		return false
	_file_cursor = target
	return true


func _handle_reading(event: InputEvent) -> void:
	var last: bool = _reader_page >= _reader_pages.size() - 1
	if event.is_action_pressed("run"):
		_close_reader()
	elif event.is_action_pressed("right") or event.is_action_pressed("action"):
		if last:
			_close_reader()
		else:
			_show_reader_page(_reader_page + 1, 1)
	elif event.is_action_pressed("left") and _reader_page > 0:
		_show_reader_page(_reader_page - 1, -1)


func _open_reader(index: int) -> void:
	if index < 0 or index >= Inventory.files.size():
		return
	var data: ItemData = ItemsPackage.get_item(Inventory.files[index])
	if data == null:
		return
	_reader_pages = data.get_file_pages()
	_reader_image.texture = data.get_file_image()
	_set_state(State.READING)
	_show_reader_page(0, 0)


func _close_reader() -> void:
	if _reader_tween:
		_reader_tween.kill()
	_set_state(State.FILES)
	_refresh()


## direction is 1 when going forward, -1 backward and 0 when opening the file,
## the text comes in from the side the player is moving to
func _show_reader_page(page: int, direction: int) -> void:
	_reader_page = clampi(page, 0, _reader_pages.size() - 1)
	var title: bool = _reader_page == 0
	_reader_text.text = _reader_pages[_reader_page]
	_reader_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if title else HORIZONTAL_ALIGNMENT_LEFT
	_reader_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if title else VERTICAL_ALIGNMENT_TOP
	var last: bool = _reader_page >= _reader_pages.size() - 1
	_reader_prev.visible = _reader_page > 0
	_reader_next.visible = not last
	_reader_exit.visible = last

	if _reader_tween:
		_reader_tween.kill()
	_reader_page_root.position.x = READER_SLIDE * direction
	_reader_page_root.modulate.a = 0.0
	_reader_tween = create_tween().set_parallel(true)
	_reader_tween.tween_property(_reader_page_root, "position:x", 0.0, READER_SLIDE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reader_tween.tween_property(_reader_page_root, "modulate:a", 1.0, READER_SLIDE_TIME)


func _open_files() -> void:
	_status = ""
	_set_state(State.FILES)
	_refresh()


## Browse navigation, the grid and the buttons above it are one layout
func _move_focus(event: InputEvent) -> bool:
	match _focus:
		Focus.GRID:
			var row: int = floori(_cursor / float(GRID_COLUMNS))
			if event.is_action_pressed("ui_up") and row == 0:
				_focus = Focus.FILES if _cursor % GRID_COLUMNS == 0 else Focus.MAP
				return true
			return _move_grid(event, false)
		Focus.EXIT:
			if event.is_action_pressed("ui_down"):
				_focus = Focus.FILES
				return true
		Focus.FILES, Focus.MAP:
			if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
				_focus = Focus.MAP if _focus == Focus.FILES else Focus.FILES
				return true
			if event.is_action_pressed("ui_up"):
				_focus = Focus.EXIT
				return true
			if event.is_action_pressed("ui_down"):
				_cursor = 0 if _focus == Focus.FILES else 1
				_focus = Focus.GRID
				return true
	return false


func _move_grid(event: InputEvent, wrap_rows: bool = true) -> bool:
	var dx: int = 0
	var dy: int = 0
	if event.is_action_pressed("ui_left"):
		dx = -1
	elif event.is_action_pressed("ui_right"):
		dx = 1
	elif event.is_action_pressed("ui_up"):
		dy = -1
	elif event.is_action_pressed("ui_down"):
		dy = 1
	else:
		return false
	var col: int = _cursor % GRID_COLUMNS
	var row: int = floori(_cursor / float(GRID_COLUMNS))
	col = wrapi(col + dx, 0, GRID_COLUMNS)
	row = wrapi(row + dy, 0, GRID_ROWS) if wrap_rows else clampi(row + dy, 0, GRID_ROWS - 1)
	_cursor = row * GRID_COLUMNS + col
	return true


func _run_command() -> void:
	match _command:
		Command.USE:
			_apply_use()
		Command.COMBINE:
			_combine_from = _cursor
			_status = "Combinar con que?"
			_set_state(State.COMBINE_TARGET)
			_refresh()
		Command.CHECK:
			_status = ""
			_set_state(State.CHECK)
			_refresh()


func _apply_use() -> void:
	var slot: Dictionary = Inventory.get_slot(_cursor)
	if slot.is_empty():
		_set_state(State.BROWSE)
		_refresh()
		return
	var item_id: String = slot["id"]
	var data: ItemData = ItemsPackage.get_item(item_id)
	if data != null and data.equippable:
		if Inventory.is_equipped(item_id):
			Inventory.unequip()
		else:
			Inventory.equip(item_id)
		_set_state(State.BROWSE)
		_refresh()
		return
	var result: Dictionary = Inventory.use_item(_cursor)
	_status = result["message"]
	_set_state(State.BROWSE)
	_refresh()


func _finish_combine() -> void:
	var result: Dictionary = Inventory.combine(_combine_from, _cursor)
	_status = result["message"]
	_combine_from = -1
	_set_state(State.BROWSE)
	_refresh()


func _set_state(new_state: State) -> void:
	_state = new_state
	if _state == State.COMMANDS or _state == State.CHECK or _state == State.COMBINE_TARGET:
		_focus = Focus.GRID
	_commands.visible = _state == State.COMMANDS
	_preview_panel.visible = _state == State.CHECK
	_files_panel.visible = _state == State.FILES
	_reader.visible = _state == State.READING
	if _file_cursor >= Inventory.files.size():
		_file_cursor = maxi(Inventory.files.size() - 1, 0)


func _refresh() -> void:
	_refresh_condition()
	_refresh_equipment()
	_refresh_buttons()
	_refresh_slots()
	_refresh_commands()
	_refresh_preview()
	if _state == State.FILES:
		_refresh_files()
	_refresh_message()


func _refresh_condition() -> void:
	var ratio: float = _get_health_ratio()
	for condition in CONDITIONS:
		if ratio >= condition["min"]:
			_status_label.text = condition["text"]
			_status_label.add_theme_color_override("font_color", condition["color"])
			_ecg.set_condition(condition["color"], condition["bpm"])
			return


func _refresh_equipment() -> void:
	var data: ItemData = ItemsPackage.get_item(Inventory.equipped_id) if Inventory.equipped_id != "" else null
	_equip_icon.texture = data.icon if data else null
	## Without an icon the name is the only way to tell what is equipped
	_equip_name.text = data.display_name if data and data.icon == null else ""


func _refresh_buttons() -> void:
	var browsing: bool = _state == State.BROWSE
	_set_button_focus(_exit_button, browsing and _focus == Focus.EXIT)
	var in_files: bool = _state == State.FILES or _state == State.READING
	_set_button_focus(_files_button, (browsing and _focus == Focus.FILES) or in_files)
	_set_button_focus(_map_button, browsing and _focus == Focus.MAP)


func _set_button_focus(button: Label, focused: bool) -> void:
	button.add_theme_stylebox_override("normal", _button_focused if focused else _button_normal)


func _refresh_slots() -> void:
	var grid_focused: bool = _focus == Focus.GRID and _state != State.FILES and _state != State.READING
	for i in _slots.size():
		var panel: Panel = _slots[i]
		var slot: Dictionary = Inventory.get_slot(i)
		var icon: TextureRect = panel.get_node("Icon")
		var name_label: Label = panel.get_node("Name")
		var amount_label: Label = panel.get_node("Amount")
		var equipped_label: Label = panel.get_node("Equipped")
		if slot.is_empty():
			icon.texture = null
			name_label.text = ""
			amount_label.text = ""
			equipped_label.visible = false
		else:
			var data: ItemData = ItemsPackage.get_item(slot["id"])
			icon.texture = data.icon if data else null
			name_label.text = "" if icon.texture else _item_name(i)
			if data and data.is_ranged_weapon():
				amount_label.text = str(int(slot.get("loaded", 0)))
			else:
				amount_label.text = str(slot["amount"]) if int(slot["amount"]) > 1 else ""
			equipped_label.visible = Inventory.is_equipped(slot["id"])
		var style: StyleBoxFlat = _slot_normal
		if i == _combine_from and _state == State.COMBINE_TARGET:
			style = _slot_combine
		if i == _cursor and grid_focused:
			style = _slot_selected
		panel.add_theme_stylebox_override("panel", style)


func _refresh_commands() -> void:
	_cmd_labels[Command.USE].text = _use_label()
	for i in _cmd_labels.size():
		var focused: bool = i == _command
		_cmd_labels[i].add_theme_stylebox_override("normal", _button_focused if focused else _button_normal)
		_cmd_labels[i].modulate = Color.WHITE if focused else TEXT_DIMMED


func _use_label() -> String:
	var slot: Dictionary = Inventory.get_slot(_cursor)
	if slot.is_empty():
		return USE_LABEL
	var data: ItemData = ItemsPackage.get_item(slot["id"])
	if data == null or not data.equippable:
		return USE_LABEL
	return UNEQUIP_LABEL if Inventory.is_equipped(slot["id"]) else EQUIP_LABEL


func _refresh_preview() -> void:
	if _state != State.CHECK:
		return
	var slot: Dictionary = Inventory.get_slot(_cursor)
	var data: ItemData = ItemsPackage.get_item(slot["id"]) if not slot.is_empty() else null
	_preview_icon.texture = data.icon if data else null
	_preview_name.text = _item_name(_cursor) if _preview_icon.texture == null else ""


func _refresh_message() -> void:
	if _status != "":
		_message_label.text = _status
		return
	match _state:
		State.CHECK:
			var slot: Dictionary = Inventory.get_slot(_cursor)
			var data: ItemData = ItemsPackage.get_item(slot["id"]) if not slot.is_empty() else null
			_message_label.text = data.description if data else ""
		State.FILES:
			_message_label.text = _file_name(_file_cursor) if not Inventory.files.is_empty() else NO_FILES_TEXT
		_:
			_message_label.text = _item_name(_cursor) if _focus == Focus.GRID else ""


func _refresh_files() -> void:
	var count: int = Inventory.files.size()
	_file_cursor = clampi(_file_cursor, 0, maxi(count - 1, 0))
	var page: int = floori(_file_cursor / float(FILES_PER_PAGE))
	for i in _file_slots.size():
		var index: int = page * FILES_PER_PAGE + i
		var panel: Panel = _file_slots[i]
		var icon: TextureRect = panel.get_node("Icon")
		var name_label: Label = panel.get_node("Name")
		var empty_label: Label = panel.get_node("Empty")
		var data: ItemData = ItemsPackage.get_item(Inventory.files[index]) if index < count else null
		icon.texture = data.icon if data else null
		name_label.text = data.display_name if data and data.icon == null else ""
		empty_label.visible = index >= count
		var selected: bool = index == _file_cursor and index < count
		panel.add_theme_stylebox_override("panel", _slot_selected if selected else _slot_normal)
	_files_prev.visible = page > 0
	_files_next.visible = (page + 1) * FILES_PER_PAGE < count


func _file_name(index: int) -> String:
	if index < 0 or index >= Inventory.files.size():
		return ""
	var data: ItemData = ItemsPackage.get_item(Inventory.files[index])
	return data.display_name if data else Inventory.files[index]


func _item_name(index: int) -> String:
	var slot: Dictionary = Inventory.get_slot(index)
	if slot.is_empty():
		return ""
	var data: ItemData = ItemsPackage.get_item(slot["id"])
	return data.display_name if data else String(slot["id"])


func _get_health_ratio() -> float:
	var player: Player = _get_player()
	var health: HealthComponent = player.health_component if player else null
	if health == null or health.max_health <= 0.0:
		return 1.0
	return health.get_health_ratio()


func _get_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _on_inventory_changed() -> void:
	if is_open():
		_refresh()


func _on_equipment_changed(_item_id: String) -> void:
	if is_open():
		_refresh()


func _build_styles() -> void:
	_slot_normal = _make_style(Color(0.00, 0.00, 0.00), Color(0.15, 0.15, 0.15), 2)
	_slot_selected = _make_style(Color(0.25, 0.25, 0.25), Color(0.9, 0.15, 0.2), 4)
	_slot_combine = _make_style(Color(0.06, 0.16, 0.2), Color(0.3, 0.95, 0.4), 4)
	_button_normal = _make_style(Color(0.00, 0.00, 0.00), Color(0.15, 0.15, 0.15), 3)
	_button_focused = _make_style(Color(0.7, 0.12, 0.15), Color(1.0, 0.85, 0.85), 4)
	_amount_settings = LabelSettings.new()
	_amount_settings.font_size = 34
	_amount_settings.font_color = AMOUNT_COLOR
	_amount_settings.outline_size = 6
	_amount_settings.outline_color = Color.BLACK


func _make_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	return style


func _build_slots() -> void:
	for i in Inventory.SLOT_COUNT:
		var panel: Panel = Panel.new()
		panel.custom_minimum_size = SLOT_SIZE
		panel.add_theme_stylebox_override("panel", _slot_normal)

		var icon: TextureRect = TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)

		## Fallback for items that still have no icon
		var name_label: Label = Label.new()
		name_label.name = "Name"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", TEXT_NORMAL)
		panel.add_child(name_label)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)

		var amount_label: Label = Label.new()
		amount_label.name = "Amount"
		amount_label.label_settings = _amount_settings
		panel.add_child(amount_label)
		amount_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 8)
		amount_label.grow_vertical = Control.GROW_DIRECTION_BEGIN

		var equipped_label: Label = Label.new()
		equipped_label.name = "Equipped"
		equipped_label.text = "E"
		equipped_label.visible = false
		equipped_label.add_theme_font_size_override("font_size", 28)
		equipped_label.add_theme_color_override("font_color", EQUIPPED_COLOR)
		equipped_label.add_theme_constant_override("outline_size", 6)
		equipped_label.add_theme_color_override("font_outline_color", Color.BLACK)
		panel.add_child(equipped_label)
		equipped_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
		equipped_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN

		_grid.add_child(panel)
		_slots.append(panel)


func _build_file_slots() -> void:
	for i in FILES_PER_PAGE:
		var panel: Panel = Panel.new()
		panel.custom_minimum_size = FILE_SLOT_SIZE
		panel.add_theme_stylebox_override("panel", _slot_normal)

		var icon: TextureRect = TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)

		## Fallback for files that still have no icon
		var name_label: Label = Label.new()
		name_label.name = "Name"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", TEXT_NORMAL)
		panel.add_child(name_label)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)

		var empty_label: Label = Label.new()
		empty_label.name = "Empty"
		empty_label.text = EMPTY_FILE_TEXT
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 26)
		empty_label.add_theme_color_override("font_color", EMPTY_FILE_COLOR)
		panel.add_child(empty_label)
		empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		_files_grid.add_child(panel)
		_file_slots.append(panel)
