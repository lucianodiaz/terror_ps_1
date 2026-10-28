class_name InfoSaveGame
extends PanelContainer

## One row of the LoadScreen, shows what a save slot holds

const EMPTY_TEXT: String = "<EMPTY FILE>"

@onready var index_label: Label = %IndexLabel
@onready var room_name_label: Label = %RoomNameLabel
@onready var date_label: Label = %DateLabel
@onready var time_label: Label = %TimeLabel

var _style_normal: StyleBoxFlat = null
var _style_selected: StyleBoxFlat = null


func _ready() -> void:
	_style_normal = _make_style(Color(0.00, 0.00, 0.00), Color(0.15, 0.15, 0.15), 3)
	_style_selected = _make_style(Color(0.7, 0.12, 0.15), Color(1.0, 0.85, 0.85), 4)
	set_selected(false)


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


func set_selected(selected: bool) -> void:
	add_theme_stylebox_override("panel", _style_selected if selected else _style_normal)


func _make_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_content_margin_all(12)
	return style
