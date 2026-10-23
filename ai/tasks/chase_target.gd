@tool
extends BTAction

@export var target_var: StringName = &"target"


func _generate_name() -> String:
	return "ChaseTarget  %s" % LimboUtility.decorate_var(target_var)


func _tick(_delta: float) -> Status:
	var enemy: EnemyTest = agent as EnemyTest
	var target: Node3D = blackboard.get_var(target_var, null, false) as Node3D
	if enemy == null or not is_instance_valid(target):
		return FAILURE
	var offset: Vector3 = target.global_position - enemy.global_position
	offset.y = 0.0
	if offset.length() <= enemy.attack_range:
		enemy.stop_movement()
		return SUCCESS
	enemy.move_to(target.global_position, true)
	return RUNNING


func _exit() -> void:
	var enemy: EnemyTest = agent as EnemyTest
	if enemy:
		enemy.is_running = false
