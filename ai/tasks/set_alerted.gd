@tool
extends BTAction

@export var alerted_var: StringName = &"alerted"
@export var value: bool = true


func _generate_name() -> String:
	return "SetAlerted  %s = %s" % [LimboUtility.decorate_var(alerted_var), value]


func _tick(_delta: float) -> Status:
	blackboard.set_var(alerted_var, value)
	return SUCCESS
