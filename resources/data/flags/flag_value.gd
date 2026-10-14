@tool
class_name FlagValue
extends Resource

## Base for resources that pair a flag with a typed value.
## Values are split by type because exported properties can't be Variant.

enum ValueType {
	BOOL,
	INT,
	STRING
}

@export var flag: FlagRef = null

@export var value_type: ValueType = ValueType.BOOL:
	set(value):
		value_type = value
		notify_property_list_changed()

@export var bool_value: bool = true
@export var int_value: int = 0
@export var string_value: String = ""


func get_value() -> Variant:
	match value_type:
		ValueType.INT:
			return int_value
		ValueType.STRING:
			return string_value
		_:
			return bool_value


func get_default_value() -> Variant:
	match value_type:
		ValueType.INT:
			return 0
		ValueType.STRING:
			return ""
		_:
			return false


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"bool_value":
			if value_type != ValueType.BOOL:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		"int_value":
			if value_type != ValueType.INT:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		"string_value":
			if value_type != ValueType.STRING:
				property.usage = PROPERTY_USAGE_NO_EDITOR
