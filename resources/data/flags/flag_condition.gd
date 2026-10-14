@tool
class_name FlagCondition
extends FlagValue

## Compares the current value of a flag against the configured value.
## A flag that was never set is treated as false, 0 or "" depending on value_type.

enum Op {
	EQUAL,
	NOT_EQUAL,
	GREATER,
	GREATER_EQUAL,
	LESS,
	LESS_EQUAL
}

@export var op: Op = Op.EQUAL


static func all_met(conditions: Array[FlagCondition], context: Node) -> bool:
	for condition in conditions:
		if condition == null or not condition.is_met(context):
			return false
	return true


func is_met(context: Node) -> bool:
	if flag == null:
		push_error("FlagCondition.is_met: flag is null")
		return false

	var expected: Variant = get_value()
	var current: Variant = flag.get_value(context, get_default_value())

	if not _are_comparable(current, expected):
		return op == Op.NOT_EQUAL

	match op:
		Op.EQUAL:
			return current == expected
		Op.NOT_EQUAL:
			return current != expected
		Op.GREATER:
			return current > expected
		Op.GREATER_EQUAL:
			return current >= expected
		Op.LESS:
			return current < expected
		Op.LESS_EQUAL:
			return current <= expected
	return false


func _are_comparable(a: Variant, b: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in numeric and typeof(b) in numeric:
		return true
	return typeof(a) == typeof(b)
