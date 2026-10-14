class_name FixedFollowCamera
extends CameraBase

@export var path_3d: Path3D
@export var path_follow_3d: PathFollow3D

@export var camera_distance_behind: float = 3.0
@export var follow_speed: float = 5.0
@export var follow_rotation: bool = true
@export var follow_position: bool = true

var path_curve: Curve3D = null
var player: Player = null


func _ready() -> void:
	if path_3d != null:
		path_curve = path_3d.curve

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player

	if path_curve == null:
		push_warning("%s: path_3d or its curve is missing." % name)
	if path_follow_3d == null:
		push_warning("%s: path_follow_3d is missing." % name)
	if player == null:
		push_warning("%s: player not found in group 'player'." % name)


func _process(delta: float) -> void:

	if follow_position:
		if path_curve == null or path_follow_3d == null or player == null or path_3d == null:
			if player == null:
				player = get_tree().get_first_node_in_group("player") as Player
			return
	
		# Curve3D works in Path3D local space, not world space.
		var local_player_pos: Vector3 = path_3d.to_local(player.global_position)
		var closest_offset: float = path_curve.get_closest_offset(local_player_pos)
	
		var target_progress: float = maxf(0.0, closest_offset - camera_distance_behind)
		var curve_length: float = path_curve.get_baked_length()
		if curve_length > 0.0:
			target_progress = minf(target_progress, curve_length)
	
		path_follow_3d.progress = lerpf(
			path_follow_3d.progress,
			target_progress,
			follow_speed * delta
		)

	if follow_rotation:
		look_at(player.global_position, Vector3.UP)


func activate() -> void:
	CameraManager.switch_to_camera(self)
