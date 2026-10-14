@tool
class_name FlagAction
extends FlagValue

## Modifies a flag. INCREMENT uses int_value, TOGGLE ignores the configured value.

enum Op {
	SET,
	INCREMENT,
	TOGGLE
}

@export var op: Op = Op.SET:
	set(value):
		op = value
		notify_property_list_changed()


static func apply_all(actions: Array[FlagAction], context: Node) -> void:
	for action in actions:
		if action:
			action.apply(context)


func apply(context: Node) -> void:
	if flag == null:
		push_error("FlagAction.apply: flag is null")
		return

	match op:
		Op.SET:
			flag.set_value(get_value(), context)
		Op.INCREMENT:
			var current: Variant = flag.get_value(context, 0)
			if typeof(current) != TYPE_INT and typeof(current) != TYPE_FLOAT:
				current = 0
			flag.set_value(current + int_value, context)
		Op.TOGGLE:
			var current: Variant = flag.get_value(context, false)
			flag.set_value(not (current is bool and current), context)


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	match op:
		Op.TOGGLE:
			if property.name in ["value_type", "bool_value", "int_value", "string_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		Op.INCREMENT:
			if property.name in ["value_type", "bool_value", "string_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "int_value":
				property.usage = PROPERTY_USAGE_DEFAULT
