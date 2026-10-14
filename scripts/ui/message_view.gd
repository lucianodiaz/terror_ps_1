## Presentation only, the lifecycle of the messages belongs to MessageManager.
class_name MessageView
extends Control

@export var characters_per_second: float = 45.0
## Extra time a HINT stays up after it finished typing
@export var hint_hold_time: float = 1.8

@onready var _bg: ColorRect = $bg
@onready var _label: Label = $bg/Label


var _revealed: float = 0.0


func _ready() -> void:
	hide_message()


func show_text(text: String) -> void:
	_label.text = text
	_revealed = 0.0
	_label.visible_characters = 0
	_bg.show()
	if characters_per_second <= 0.0:
		reveal_all()
		return
	set_process(true)


func hide_message() -> void:
	_bg.hide()
	set_process(false)


func reveal_all() -> void:
	_revealed = _label.text.length()
	_label.visible_characters = -1
	set_process(false)


func is_fully_revealed() -> bool:
	return _revealed >= _label.text.length()


## How long the typewriter needs for this text
func get_reveal_time(text: String) -> float:
	if characters_per_second <= 0.0:
		return 0.0
	return text.length() / characters_per_second


func _process(delta: float) -> void:
	_revealed += characters_per_second * delta
	if _revealed >= _label.text.length():
		reveal_all()
		return
	_label.visible_characters = int(_revealed)
