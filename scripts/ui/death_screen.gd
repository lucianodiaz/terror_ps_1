## Shown when the player dies, the scene is the autoload. The buttons work
## with the mouse, hovering one selects it and only a click on a button
## presses it. Keys and the pad are handled in _input and never reach the
## game underneath.
extends CanvasLayer

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"
const FONT_SIZE: int = 40
const FONT_COLOR: Color = Color(0.92, 0.94, 1.0)
const BUTTON_HEIGHT: float = 70.0

@export var _buttons: Array[Button] = []
@onready var _animation_player: AnimationPlayer = %AnimationPlayer

var _button_normal: StyleBoxFlat = null
var _button_focused: StyleBoxFlat = null

## Button last focused, by the keys or by hovering it
var _index: int = 0
var _is_open: bool = false


func is_open() -> bool:
	return _is_open


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_styles()
	for i in _buttons.size():
		var button: Button = _buttons[i]
		_style_button(button)
		## Hover moves the focus, so mouse and keys never highlight two buttons
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(func() -> void: _index = i)
		button.pressed.connect(_on_button_pressed.bind(i))
	SaveManager.world_reloading.connect(close)
	visible = false


func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_buttons[0].grab_focus()
	get_tree().paused = true
	Cursor.cursor_visibility = true
	_animation_player.play("open")


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	get_viewport().gui_release_focus()
	get_tree().paused = false
	Cursor.cursor_visibility = false


## There is nothing to go back to, cancel does nothing here
func _input(event: InputEvent) -> void:
	if not _is_open or LoadScreen.is_open():
		return
	if event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_up"):
		_move_focus(-1)
	elif event.is_action_pressed("ui_down"):
		_move_focus(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("action"):
		_on_button_pressed(_index)


func _move_focus(step: int) -> void:
	_buttons[wrapi(_index + step, 0, _buttons.size())].grab_focus()


func _on_button_pressed(index: int) -> void:
	if not _is_open or LoadScreen.is_open():
		return
	match index:
		0:
			SaveManager.continue_game()
		1:
			## The screen stays open under the LoadScreen, cancelling comes back here.
			## Deferred so this same press doesn't reach the LoadScreen and pick a slot
			LoadScreen.open.call_deferred(LoadScreen.Mode.LOAD)
		2:
			close()
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)


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
