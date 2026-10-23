@tool
extends BTCondition

@export var alerted_var: StringName = &"alerted"


func _generate_name() -> String:
	return "IsAlerted  %s" % LimboUtility.decorate_var(alerted_var)


func _tick(_delta: float) -> Status:
	return SUCCESS if blackboard.get_var(alerted_var, false, false) else FAILURE
