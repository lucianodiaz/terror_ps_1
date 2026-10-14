@tool
class_name LeverConfig
extends Resource

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		emit_changed()
