extends CanvasLayer

@onready var _continue_button: Label = %ContinueLabel
@onready var _load_button: Label = %LoadLabel
@onready var _quit_button: Label = %QuitLabel

@onready var _animation_player: AnimationPlayer = %AnimationPlayer

const BUTTONS_LENGTH: int = 3

var _button_normal: StyleBoxFlat = null
var _button_focused: StyleBoxFlat = null

var _buttons: Array[Label] = []
var _index: int = 0
var _is_option_selected: bool = false

var _is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_styles()
	_buttons.append(_continue_button)
	_buttons.append(_load_button)
	_buttons.append(_quit_button)
	_refresh_buttons()
	SaveManager.world_reloading.connect(close)

	visible = false

func open() -> void:
	_is_open = true
	visible = true
	_index = 0
	_is_option_selected = false
	_refresh_buttons()
	_animation_player.play("open")
	get_tree().paused = true
	await _animation_player.animation_finished


func close() -> void:
	visible = false
	_index = 0
	_is_option_selected = false
	_is_open = false

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if _is_option_selected or LoadScreen.is_open():
		return
	_move_grid(event)
	_action_button_selected(event)

func _refresh_buttons() -> void:
	for i in range(BUTTONS_LENGTH):
		_set_button_focus(_buttons[i], i == _index)

func _move_grid(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_index = _index - 1
	elif event.is_action_pressed("ui_down"):
		_index = _index + 1
	_index = wrapi(_index, 0, BUTTONS_LENGTH)
	_refresh_buttons()

func _action_button_selected(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("action"):
		select_button_action()

func select_button_action() -> void:
	match _index:
		0:
			_is_option_selected = true
			SaveManager.continue_game()
		1:
			## Deferred so this same press doesn't reach the LoadScreen and pick a slot
			LoadScreen.open.call_deferred(LoadScreen.Mode.LOAD)
		2:
			_is_option_selected = true
			get_tree().quit()

func _set_button_focus(button: Label, focused: bool) -> void:
	button.add_theme_stylebox_override("normal", _button_focused if focused else _button_normal)


func _build_styles() -> void:
	_button_normal = _make_style(Color(0.00, 0.00, 0.00), Color(0.15, 0.15, 0.15), 3)
	_button_focused = _make_style(Color(0.7, 0.12, 0.15), Color(1.0, 0.85, 0.85), 4)

func _make_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	return style
