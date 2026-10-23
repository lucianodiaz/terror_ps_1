@tool
extends BTAction

@export var target_var: StringName = &"target"
@export_range(1.0, 90.0, 1.0, "suffix:deg") var tolerance: float = 10.0
## Gives up turning after this time and succeeds anyway
@export_range(0.1, 5.0, 0.1, "suffix:s") var max_time: float = 1.0


func _generate_name() -> String:
	return "FaceTarget  %s" % LimboUtility.decorate_var(target_var)


func _tick(delta: float) -> Status:
	var enemy: EnemyTest = agent as EnemyTest
	var target: Node3D = blackboard.get_var(target_var, null, false) as Node3D
	if enemy == null or not is_instance_valid(target):
		return FAILURE
	if enemy.face_point(target.global_position, delta, tolerance) or elapsed_time >= max_time:
		return SUCCESS
	return RUNNING
