@tool
extends BTAction

## Keeps returning RUNNING while the agent is stunned
@export var keep_running: bool = false


func _generate_name() -> String:
	return "StopMovement" + ("  (while stunned)" if keep_running else "")


func _tick(_delta: float) -> Status:
	var enemy: EnemyTest = agent as EnemyTest
	if enemy == null:
		return FAILURE
	enemy.stop_movement()
	if keep_running and enemy.is_stunned:
		return RUNNING
	return SUCCESS
