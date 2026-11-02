@tool
extends BTAction

## The OneShot needs a frame to report itself active
const START_GRACE_TIME: float = 0.2

@export var target_var: StringName = &"target"


func _generate_name() -> String:
	return "Attack  %s" % LimboUtility.decorate_var(target_var)


func _enter() -> void:
	var enemy: EnemyTest = agent as EnemyTest
	if enemy:
		enemy.play_attack()


func _tick(_delta: float) -> Status:
	var enemy: EnemyTest = agent as EnemyTest
	if enemy == null:
		return FAILURE
	var target: Node3D = blackboard.get_var(target_var, null, false) as Node3D
	if is_instance_valid(target) and not target.is_dead:
		enemy.pursue(target, enemy.attack_move_speed)
	else:
		enemy.halt()
	if elapsed_time < START_GRACE_TIME or enemy.is_attacking():
		return RUNNING
	return SUCCESS
