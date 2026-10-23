@tool
extends BTAction

## The OneShot needs a frame to report itself active
const START_GRACE_TIME: float = 0.1


func _generate_name() -> String:
	return "Attack"


func _enter() -> void:
	var enemy: EnemyTest = agent as EnemyTest
	if enemy:
		enemy.play_attack()


func _tick(_delta: float) -> Status:
	var enemy: EnemyTest = agent as EnemyTest
	if enemy == null:
		return FAILURE
	if elapsed_time < START_GRACE_TIME or enemy.is_attacking():
		return RUNNING
	return SUCCESS
