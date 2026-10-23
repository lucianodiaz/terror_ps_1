@tool
extends BTCondition


func _generate_name() -> String:
	return "IsStunned"


func _tick(_delta: float) -> Status:
	var enemy: EnemyTest = agent as EnemyTest
	return SUCCESS if enemy and enemy.is_stunned else FAILURE
