## Title menu. The buttons work with the mouse, hovering one selects it and
## only a click on a button presses it. Keys and the pad move the focus with
## UP / DOWN and press with ui_accept, the same selection the mouse uses.
extends CanvasLayer

@export var _buttons: Array[Button] = []

const FONT_SIZE: int = 40
const FONT_COLOR: Color = Color(0.92, 0.94, 1.0)
const BUTTON_HEIGHT: float = 70.0

var _button_normal: StyleBoxFlat = null
var _button_focused: StyleBoxFlat = null

var _is_open: bool = true
## Clicking outside the buttons clears the focus, the keys and the pad pick
## up again from this one
var _last_focused: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_styles()
	for i in _buttons.size():
		var button: Button = _buttons[i]
		_style_button(button)
		## Hover moves the focus, so mouse and keys never highlight two buttons
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(func() -> void: _last_focused = button)
		button.focus_exited.connect(_restore_focus.call_deferred)
		button.pressed.connect(_on_button_pressed.bind(i))
		var previous: Button = _buttons[wrapi(i - 1, 0, _buttons.size())]
		var next: Button = _buttons[wrapi(i + 1, 0, _buttons.size())]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_previous = button.focus_neighbor_top
		button.focus_next = button.focus_neighbor_bottom
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)
	_focus_first.call_deferred()


func open() -> void:
	_is_open = true
	visible = true
	_focus_first.call_deferred()
	Cursor.cursor_visibility = true


func close() -> void:
	visible = false
	_is_open = false


## action confirms as well when it is on a key or a pad button. On the mouse
## it is left to the buttons, a click outside them does nothing.
func _unhandled_input(event: InputEvent) -> void:
	if not _is_open or event is InputEventMouseButton:
		return
	if not event.is_action_pressed("action"):
		return
	var focused: Button = get_viewport().gui_get_focus_owner() as Button
	if focused in _buttons:
		get_viewport().set_input_as_handled()
		focused.pressed.emit()


func _focus_first() -> void:
	if _is_open and not _buttons.is_empty():
		_buttons[0].grab_focus()


## Deferred from focus_exited, which also fires while the scene is being freed
func _restore_focus() -> void:
	if not _is_open or not is_inside_tree() or get_viewport().gui_get_focus_owner() != null:
		return
	if _last_focused:
		_last_focused.grab_focus()


func _on_button_pressed(index: int) -> void:
	if not _is_open or LoadScreen.is_open() or OptionScreen.is_open():
		return
	match index:
		0:
			close()
			SaveManager.new_game()

		1:
			## The menu stays open under the LoadScreen, cancelling comes back here.
			## Deferred so this same press doesn't reach the LoadScreen and pick a slot
			LoadScreen.open.call_deferred(LoadScreen.Mode.LOAD)
		2:
			## Deferred for the same reason as the LoadScreen
			OptionScreen.open.call_deferred()
		3:
			close()
			get_tree().quit()


func _style_button(button: Button) -> void:
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	for color_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, FONT_COLOR)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 6)
	## Hover alone keeps the normal look, hovering already moves the focus
	button.add_theme_stylebox_override("normal", _button_normal)
	button.add_theme_stylebox_override("hover", _button_normal)
	button.add_theme_stylebox_override("pressed", _button_focused)
	button.add_theme_stylebox_override("hover_pressed", _button_focused)
	button.add_theme_stylebox_override("focus", _button_focused)


func _build_styles() -> void:
	_button_normal = _make_style(Color(0.00, 0.00, 0.00), Color(0.15, 0.15, 0.15), 3)
	_button_focused = _make_style(Color(0.7, 0.12, 0.15), Color(1.0, 0.85, 0.85), 4)


func _make_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	return style
