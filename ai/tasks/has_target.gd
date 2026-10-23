@tool
extends BTCondition

@export var target_var: StringName = &"target"


func _generate_name() -> String:
	return "HasTarget  %s" % LimboUtility.decorate_var(target_var)


func _tick(_delta: float) -> Status:
	var target: Variant = blackboard.get_var(target_var, null, false)
	return SUCCESS if is_instance_valid(target) else FAILURE
