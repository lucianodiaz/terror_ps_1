@tool
extends BTAction

@export var position_var: StringName = &"patrol_point"
@export var run: bool = false
## Fails after this time, so the agent doesn't get stuck against a wall
@export_range(0.5, 30.0, 0.5, "suffix:s") var timeout: float = 8.0


func _generate_name() -> String:
	return "MoveToPosition  %s%s" % [LimboUtility.decorate_var(position_var), "  (run)" if run else ""]


func _enter() -> void:
	var enemy: EnemyTest = agent as EnemyTest
	var point: Variant = blackboard.get_var(position_var, null, false)
	if enemy and point is Vector3:
		enemy.move_to(point, run)


func _tick(_delta: float) -> Status:
	var enemy: EnemyTest = agent as EnemyTest
	if enemy == null or not blackboard.get_var(position_var, null, false) is Vector3:
		return FAILURE
	if elapsed_time >= timeout:
		return FAILURE
	if elapsed_time > 0.0 and enemy.is_navigation_finished():
		return SUCCESS
	return RUNNING


func _exit() -> void:
	var enemy: EnemyTest = agent as EnemyTest
	if enemy:
		enemy.stop_movement()
