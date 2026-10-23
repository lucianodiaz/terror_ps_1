@tool
extends BTAction

@export var output_var: StringName = &"patrol_point"
@export var patrol_radius: float = 6.0
## Points closer than this to the agent are rerolled
@export var min_distance: float = 1.5
@export var max_attempts: int = 8

var _home: Vector3
var _has_home: bool = false


func _generate_name() -> String:
	return "PickRandomNavPoint  r=%s ➜%s" % [patrol_radius, LimboUtility.decorate_var(output_var)]


func _tick(_delta: float) -> Status:
	var enemy: EnemyTest = agent as EnemyTest
	if enemy == null or enemy.nav_agent == null:
		return FAILURE
	var map: RID = enemy.nav_agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return FAILURE

	if not _has_home:
		_home = enemy.global_position
		_has_home = true

	for i in max_attempts:
		var angle: float = randf() * TAU
		var radius: float = sqrt(randf()) * patrol_radius
		var candidate: Vector3 = _home + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var point: Vector3 = NavigationServer3D.map_get_closest_point(map, candidate)
		if point.distance_to(enemy.global_position) >= min_distance:
			blackboard.set_var(output_var, point)
			return SUCCESS
	return FAILURE
