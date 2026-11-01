class_name InfoSaveGame
extends Button

## One row of the LoadScreen, shows what a save slot holds. The focused row is
## the selected one, hovering a row focuses it.

const EMPTY_TEXT: String = "<EMPTY FILE>"

@onready var index_label: Label = %IndexLabel
@onready var room_name_label: Label = %RoomNameLabel
@onready var date_label: Label = %DateLabel
@onready var time_label: Label = %TimeLabel


func _ready() -> void:
	var style_normal: StyleBoxFlat = _make_style(Color(0.00, 0.00, 0.00), Color(0.15, 0.15, 0.15), 3)
	var style_selected: StyleBoxFlat = _make_style(Color(0.7, 0.12, 0.15), Color(1.0, 0.85, 0.85), 4)
	## Hover alone keeps the normal look, hovering already moves the focus
	add_theme_stylebox_override("normal", style_normal)
	add_theme_stylebox_override("hover", style_normal)
	add_theme_stylebox_override("pressed", style_selected)
	add_theme_stylebox_override("hover_pressed", style_selected)
	add_theme_stylebox_override("focus", style_selected)
	mouse_entered.connect(grab_focus)


## index is 0 based, the label shows it from 1
func set_index(index: int) -> void:
	index_label.text = "%d." % (index + 1)


## info is SaveManager.get_slot_info(), empty for a free slot
func set_info(info: Dictionary) -> void:
	var has_data: bool = not info.is_empty()
	date_label.visible = has_data
	time_label.visible = has_data
	if not has_data:
		room_name_label.text = EMPTY_TEXT
		return
	room_name_label.text = String(info.get("room_display_name", info.get("room_key", "")))
	## The timestamp is UTC, the bias moves it to the player's local time
	var local_time: int = int(info.get("timestamp", 0)) + int(Time.get_time_zone_from_system()["bias"]) * 60
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(local_time)
	date_label.text = "%02d/%02d/%04d" % [datetime["day"], datetime["month"], datetime["year"]]
	time_label.text = "%02d:%02d" % [datetime["hour"], datetime["minute"]]


func _make_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	return style
