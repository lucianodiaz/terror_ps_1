## Controls, audio and display options. The scene is the autoload, opened from
## the main menu. Every change is applied and saved by SettingsManager right away.
extends CanvasLayer

signal closed

enum Kind { HEADER, BINDING_TITLES, BINDING, RESET_BINDINGS, VOLUME, WINDOW_MODE, RESOLUTION, VSYNC, BACK }

const ROWS: Array[Dictionary] = [
	{ "kind": Kind.HEADER, "text": "CONTROLS" },
	{ "kind": Kind.BINDING_TITLES },
	{ "kind": Kind.BINDING, "text": "Forward", "action": &"forward" },
	{ "kind": Kind.BINDING, "text": "Backward", "action": &"backward" },
	{ "kind": Kind.BINDING, "text": "Left", "action": &"left" },
	{ "kind": Kind.BINDING, "text": "Right", "action": &"right" },
	{ "kind": Kind.BINDING, "text": "Run", "action": &"run" },
	{ "kind": Kind.BINDING, "text": "Aim", "action": &"aim" },
	{ "kind": Kind.BINDING, "text": "Action", "action": &"action" },
	{ "kind": Kind.BINDING, "text": "Shoot", "action": &"shoot" },
	{ "kind": Kind.BINDING, "text": "Back / Cancel", "action": &"cancel" },
	{ "kind": Kind.BINDING, "text": "Inventory", "action": &"inventory" },
	{ "kind": Kind.RESET_BINDINGS, "text": "Reset Controls" },
	{ "kind": Kind.HEADER, "text": "AUDIO" },
	{ "kind": Kind.VOLUME, "text": "Master", "bus": GameSettings.BUS_MASTER },
	{ "kind": Kind.VOLUME, "text": "Music", "bus": GameSettings.BUS_BGM },
	{ "kind": Kind.VOLUME, "text": "Effects", "bus": GameSettings.BUS_SFX },
	{ "kind": Kind.HEADER, "text": "DISPLAY" },
	{ "kind": Kind.WINDOW_MODE, "text": "Window Mode" },
	{ "kind": Kind.RESOLUTION, "text": "Resolution" },
	{ "kind": Kind.VSYNC, "text": "VSync" },
	{ "kind": Kind.BACK, "text": "Back" },
]

## Same order as GameSettings.WINDOW_MODES
const WINDOW_MODE_NAMES: Array[String] = ["WINDOWED", "FULLSCREEN"]
const VOLUME_STEP: float = 0.1
const ROW_HEIGHT: float = 62.0
const VALUE_WIDTH: float = 340.0
## Binding rows split the value into a keyboard and a gamepad column
const KEY_WIDTH: float = 240.0
const PAD_WIDTH: float = 380.0
const COLUMN_SEPARATION: int = 24
const BAR_SIZE: Vector2 = Vector2(300, 26)
const TEXT_DIMMED: Color = Color(0.5, 0.52, 0.6)
const HEADER_COLOR: Color = Color(0.85, 0.2, 0.22)
const WAITING_KEY_TEXT: String = "PRESS A KEY..."
const WAITING_PAD_TEXT: String = "PRESS A BUTTON..."
## How far a stick or trigger has to go to be taken as the new binding
const PAD_AXIS_THRESHOLD: float = 0.6

@onready var _scroll: ScrollContainer = %RowScroll
@onready var _row_list: VBoxContainer = %RowList
@onready var _hint_label: Label = %HintLabel

var _row_settings: LabelSettings = preload("res://assets/theme/label_settings.tres").duplicate() as LabelSettings

## Index in ROWS of every row the cursor can stop on
var _selectable: Array[int] = []
## Per row in ROWS, null where the row has no such node
var _panels: Array[PanelContainer] = []
var _value_labels: Array[Label] = []
var _pad_labels: Array[Label] = []
var _bars: Array[ProgressBar] = []

var _index: int = 0
var _is_open: bool = false
var _was_paused: bool = false
## Column the cursor is on in binding rows, LEFT / RIGHT switch it
var _column: GameSettings.Device = GameSettings.Device.KEYBOARD_MOUSE
## Action waiting for its new input, empty when not rebinding
var _waiting_action: StringName = &""
var _waiting_device: GameSettings.Device = GameSettings.Device.KEYBOARD_MOUSE
## Stick or trigger just bound, ignored until it goes back to rest so it
## doesn't also move the cursor. -1 when none
var _held_axis: int = -1

var _row_normal: StyleBoxFlat = null
var _row_focused: StyleBoxFlat = null
var _bar_background: StyleBoxFlat = null
var _bar_fill: StyleBoxFlat = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_row_settings.font_size = 32
	_build_styles()
	_build_rows()
	visible = false


func is_open() -> bool:
	return _is_open


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_index = 0
	_column = GameSettings.Device.KEYBOARD_MOUSE
	_waiting_action = &""
	_held_axis = -1
	visible = true
	## Opened over a paused tree, closing has to leave it paused
	_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh()
	_scroll.scroll_vertical = 0


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_waiting_action = &""
	visible = false
	get_tree().paused = _was_paused
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion and motion.axis == _held_axis:
		if absf(motion.axis_value) < PAD_AXIS_THRESHOLD:
			_held_axis = -1
		return
	if _waiting_action != &"":
		if _waiting_device == GameSettings.Device.KEYBOARD_MOUSE:
			_capture_keyboard_mouse(event)
		else:
			_capture_pad(event)
		return
	if event.is_action_pressed("ui_up", true):
		_move_cursor(-1)
	elif event.is_action_pressed("ui_down", true):
		_move_cursor(1)
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		## Holding only repeats on volumes, a held choice would flicker between values
		if event.is_echo() and _current_kind() != Kind.VOLUME:
			return
		_change_value(1 if event.is_action_pressed("ui_right", true) else -1)
	elif event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		_confirm()


## ESC is kept for cancelling, it is also the pause key
func _capture_keyboard_mouse(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"):
		_stop_waiting()
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event:
		if mouse_event.pressed and GameSettings.MOUSE_BUTTON_NAMES.has(mouse_event.button_index):
			SettingsManager.rebind(_waiting_action, mouse_event)
			_stop_waiting()
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_ESCAPE:
		_stop_waiting()
		return
	if key_event.physical_keycode == KEY_NONE:
		return
	SettingsManager.rebind(_waiting_action, key_event)
	_stop_waiting()


## MENU is kept for cancelling, it is also the pause button
func _capture_pad(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event:
		if key_event.pressed and key_event.physical_keycode == KEY_ESCAPE:
			_stop_waiting()
		return
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button:
		if not button.pressed:
			return
		if button.button_index != JOY_BUTTON_START:
			SettingsManager.rebind(_waiting_action, button)
		_stop_waiting()
		return
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion and absf(motion.axis_value) >= PAD_AXIS_THRESHOLD:
		SettingsManager.rebind(_waiting_action, motion)
		_held_axis = motion.axis
		_stop_waiting()


func _stop_waiting() -> void:
	_waiting_action = &""
	_refresh()


func _move_cursor(step: int) -> void:
	_index = wrapi(_index + step, 0, _selectable.size())
	_refresh()
	## The first row would hide the CONTROLS header above it
	if _index == 0:
		_scroll.scroll_vertical = 0
	else:
		_scroll.ensure_control_visible(_panels[_selectable[_index]])


func _current_row() -> Dictionary:
	return ROWS[_selectable[_index]]


func _current_kind() -> Kind:
	return _current_row()["kind"]


func _change_value(step: int) -> void:
	var row: Dictionary = _current_row()
	match row["kind"]:
		Kind.BINDING:
			_column = wrapi(_column + step, 0, GameSettings.Device.size()) as GameSettings.Device
		Kind.VOLUME:
			var bus: StringName = row["bus"]
			var value: float = snappedf(SettingsManager.get_volume(bus) + VOLUME_STEP * step, VOLUME_STEP)
			SettingsManager.set_volume(bus, value)
		Kind.WINDOW_MODE:
			var modes: Array[int] = GameSettings.WINDOW_MODES
			var current: int = maxi(modes.find(SettingsManager.window_mode), 0)
			SettingsManager.set_window_mode(modes[wrapi(current + step, 0, modes.size())] as DisplayServer.WindowMode)

		Kind.RESOLUTION:
			if not _is_windowed():
				return
			var sizes: Array[Vector2i] = SettingsManager.get_available_resolutions()
			var current: int = sizes.find(SettingsManager.resolution)
			## A saved size that is not in the list starts from the closest end
			if current < 0:
				current = sizes.size() if step < 0 else -1
			SettingsManager.set_resolution(sizes[wrapi(current + step, 0, sizes.size())])
		Kind.VSYNC:
			SettingsManager.set_vsync(not SettingsManager.vsync)
		_:
			return
	_refresh()


func _confirm() -> void:
	var row: Dictionary = _current_row()
	match row["kind"]:
		Kind.WINDOW_MODE, Kind.RESOLUTION, Kind.VSYNC:
			_change_value(1)
		Kind.BINDING:
			_waiting_action = row["action"]
			_waiting_device = _selected_device(_waiting_action)
			_refresh()
		Kind.RESET_BINDINGS:
			SettingsManager.reset_bindings()
			_refresh()
		Kind.BACK:
			close()


func _is_windowed() -> bool:
	return SettingsManager.window_mode == DisplayServer.WINDOW_MODE_WINDOWED


## The gamepad side of movement can't be rebound, there the cursor stays on the keyboard
func _selected_device(action: StringName) -> GameSettings.Device:
	if SettingsManager.can_rebind(action, _column):
		return _column
	return GameSettings.Device.KEYBOARD_MOUSE


func _refresh() -> void:
	for i in ROWS.size():
		var panel: PanelContainer = _panels[i]
		if panel == null:
			continue
		var focused: bool = _selectable[_index] == i
		panel.add_theme_stylebox_override("panel", _row_focused if focused else _row_normal)
		_refresh_value(i, focused)
	_refresh_hint()


func _refresh_value(row_index: int, focused: bool) -> void:
	var row: Dictionary = ROWS[row_index]
	var value_label: Label = _value_labels[row_index]
	var panel: PanelContainer = _panels[row_index]
	panel.modulate = Color.WHITE
	match row["kind"]:
		Kind.BINDING:
			var action: StringName = row["action"]
			var waiting: bool = _waiting_action == action
			var device: GameSettings.Device = _waiting_device if waiting else _selected_device(action)
			var keyboard: GameSettings.Device = GameSettings.Device.KEYBOARD_MOUSE
			var gamepad: GameSettings.Device = GameSettings.Device.GAMEPAD
			var pad_label: Label = _pad_labels[row_index]
			value_label.text = _cell_text(SettingsManager.get_binding_label(action, keyboard),
				WAITING_KEY_TEXT, waiting, focused and device == keyboard)
			pad_label.text = _cell_text(SettingsManager.get_binding_label(action, gamepad),
				WAITING_PAD_TEXT, waiting, focused and device == gamepad)
			pad_label.modulate = Color.WHITE if SettingsManager.can_rebind(action, gamepad) else TEXT_DIMMED
		Kind.VOLUME:
			var value: float = SettingsManager.get_volume(row["bus"])
			_bars[row_index].value = value
			value_label.text = "%d%%" % roundi(value * 100.0)
		Kind.WINDOW_MODE:
			var mode_index: int = GameSettings.WINDOW_MODES.find(SettingsManager.window_mode)
			value_label.text = _choice_text(WINDOW_MODE_NAMES[mode_index] if mode_index >= 0 else "?", focused)
		Kind.RESOLUTION:
			var size: Vector2i = SettingsManager.resolution
			value_label.text = _choice_text("%d x %d" % [size.x, size.y], focused and _is_windowed())
			## Fullscreen always uses the monitor's size
			if not _is_windowed():
				panel.modulate = TEXT_DIMMED
		Kind.VSYNC:
			value_label.text = _choice_text("ON" if SettingsManager.vsync else "OFF", focused)


func _choice_text(value: String, focused: bool) -> String:
	return "<  %s  >" % value if focused else value


## The column under the cursor shows its value in brackets, or the waiting text
func _cell_text(value: String, waiting_text: String, waiting: bool, selected: bool) -> String:
	if not selected:
		return value
	return waiting_text if waiting else "[ %s ]" % value


func _refresh_hint() -> void:
	if _waiting_action != &"":
		if _waiting_device == GameSettings.Device.KEYBOARD_MOUSE:
			_hint_label.text = "Press a new key or mouse button.   ESC: Cancel"
		else:
			_hint_label.text = "Press a new button, trigger or stick direction.   ESC / MENU: Cancel"
		return
	var confirm: String = _binding_text(&"action")
	var back: String = _binding_text(&"cancel")
	_hint_label.text = "UP / DOWN: Select     LEFT / RIGHT: Change     %s: Confirm     %s: Back" % [confirm, back]


## Primary input of the action on each device, as "LMB / A"
func _binding_text(action: StringName) -> String:
	return "%s / %s" % [
		SettingsManager.get_primary_label(action, GameSettings.Device.KEYBOARD_MOUSE),
		SettingsManager.get_primary_label(action, GameSettings.Device.GAMEPAD),
	]


func _build_rows() -> void:
	for child in _row_list.get_children():
		child.queue_free()
	for i in ROWS.size():
		var row: Dictionary = ROWS[i]
		var kind: Kind = row["kind"]
		if kind == Kind.HEADER or kind == Kind.BINDING_TITLES:
			if kind == Kind.HEADER:
				_row_list.add_child(_make_header(row["text"]))
			else:
				_row_list.add_child(_make_binding_titles())
			_panels.append(null)
			_value_labels.append(null)
			_pad_labels.append(null)
			_bars.append(null)
			continue

		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size.y = ROW_HEIGHT
		panel.add_theme_stylebox_override("panel", _row_normal)
		var box: HBoxContainer = HBoxContainer.new()
		box.add_theme_constant_override("separation", COLUMN_SEPARATION)
		panel.add_child(box)

		var name_label: Label = _make_label(row["text"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(name_label)

		var bar: ProgressBar = null
		if kind == Kind.VOLUME:
			bar = ProgressBar.new()
			bar.min_value = 0.0
			bar.max_value = 1.0
			bar.step = 0.0
			bar.show_percentage = false
			bar.custom_minimum_size = BAR_SIZE
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.add_theme_stylebox_override("background", _bar_background)
			bar.add_theme_stylebox_override("fill", _bar_fill)
			box.add_child(bar)

		var value_label: Label = _make_label("")
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		## Volumes share the width with their bar
		value_label.custom_minimum_size.x = 120.0 if bar else VALUE_WIDTH
		box.add_child(value_label)

		var pad_label: Label = null
		if kind == Kind.BINDING:
			value_label.custom_minimum_size.x = KEY_WIDTH
			pad_label = _make_label("")
			pad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pad_label.custom_minimum_size.x = PAD_WIDTH
			box.add_child(pad_label)

		_row_list.add_child(panel)
		_panels.append(panel)
		_value_labels.append(value_label)
		_pad_labels.append(pad_label)
		_bars.append(bar)
		_selectable.append(i)


func _make_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.label_settings = _row_settings
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_header(text: String) -> Label:
	var header: Label = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", HEADER_COLOR)
	header.add_theme_constant_override("outline_size", 6)
	header.add_theme_color_override("font_outline_color", Color.BLACK)
	return header


## Column titles over the binding rows, with the rows' side margins so each
## title sits over its column
func _make_binding_titles() -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(_row_normal.content_margin_left))
	margin.add_theme_constant_override("margin_right", int(_row_normal.content_margin_right))
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", COLUMN_SEPARATION)
	margin.add_child(box)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_make_column_title("KEYBOARD / MOUSE", KEY_WIDTH))
	box.add_child(_make_column_title("GAMEPAD", PAD_WIDTH))
	return margin


func _make_column_title(text: String, width: float) -> Label:
	var title: Label = Label.new()
	title.text = text
	title.custom_minimum_size.x = width
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TEXT_DIMMED)
	return title


func _build_styles() -> void:
	_row_normal = _make_style(Color(0.00, 0.00, 0.00), Color(0.15, 0.15, 0.15), 3)
	_row_focused = _make_style(Color(0.7, 0.12, 0.15), Color(1.0, 0.85, 0.85), 4)
	_bar_background = _make_style(Color(0.08, 0.08, 0.1), Color(0.62, 0.64, 0.68), 2)
	_bar_fill = _make_style(Color(0.92, 0.94, 1.0), Color(0.92, 0.94, 1.0), 0)
	_bar_background.set_content_margin_all(0)
	_bar_fill.set_content_margin_all(0)


func _make_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
