@tool
class_name ArrowComponent
extends MeshInstance3D

enum ArrowDirection {
	FORWARD = 0,  # -Z (Godot forward)
	BACKWARD = 1, # +Z
	RIGHT = 2,    # +X
	LEFT = 3,     # -X
	UP = 4,       # +Y
	DOWN = 5,     # -Y
}

@export_group("Arrow")
@export var direction: ArrowDirection = ArrowDirection.FORWARD:
	set(value):
		direction = value
		_update_mesh()

@export_range(0.05, 100.0, 0.05, "or_greater") var arrow_length: float = 1.0:
	set(value):
		arrow_length = max(value, 0.05)
		_update_mesh()

@export_range(0.01, 2.0, 0.01, "or_greater") var shaft_radius: float = 0.03:
	set(value):
		shaft_radius = max(value, 0.01)
		_update_mesh()

@export_range(0.05, 2.0, 0.05, "or_greater") var head_length: float = 0.2:
	set(value):
		head_length = max(value, 0.05)
		_update_mesh()

@export_range(0.05, 2.0, 0.05, "or_greater") var head_radius: float = 0.1:
	set(value):
		head_radius = max(value, 0.05)
		_update_mesh()

@export var arrow_color: Color = Color(0.2, 0.75, 1.0, 1.0):
	set(value):
		arrow_color = value
		_update_mesh()

@export_group("Visibility")
@export var hidden_in_game: bool = true:
	set(value):
		hidden_in_game = value
		_apply_visibility()

@export var editor_only: bool = true:
	set(value):
		editor_only = value
		_apply_visibility()


var _immediate_mesh: ImmediateMesh


func _enter_tree() -> void:
	_ensure_resources()
	_apply_visibility()
	_update_mesh()


func _ready() -> void:
	_apply_visibility()
	_update_mesh()


func _ensure_resources() -> void:
	if mesh == null or not mesh is ImmediateMesh:
		_immediate_mesh = ImmediateMesh.new()
		mesh = _immediate_mesh
	else:
		_immediate_mesh = mesh as ImmediateMesh

	if material_override == null:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color.WHITE
		material_override = material


func _apply_visibility() -> void:
	if Engine.is_editor_hint():
		visible = true
		return

	if editor_only or hidden_in_game:
		visible = false
	else:
		visible = true


func _get_direction_vector() -> Vector3:
	match direction:
		ArrowDirection.FORWARD:
			return Vector3.FORWARD
		ArrowDirection.BACKWARD:
			return Vector3.BACK
		ArrowDirection.RIGHT:
			return Vector3.RIGHT
		ArrowDirection.LEFT:
			return Vector3.LEFT
		ArrowDirection.UP:
			return Vector3.UP
		ArrowDirection.DOWN:
			return Vector3.DOWN
		_:
			return Vector3.FORWARD


func _update_mesh() -> void:
	if not is_inside_tree() and not Engine.is_editor_hint():
		return

	_ensure_resources()
	_immediate_mesh.clear_surfaces()

	var dir := _get_direction_vector().normalized()
	var start := Vector3.ZERO
	var end := dir * arrow_length

	var clamped_head_length: float = minf(head_length, arrow_length * 0.75)
	var shaft_end: Vector3 = end - dir * clamped_head_length

	_add_shaft_prism(start, shaft_end, shaft_radius)
	_add_arrow_head(end, dir, clamped_head_length, head_radius)


func _add_shaft_prism(start: Vector3, end: Vector3, radius: float) -> void:
	var axis := end - start
	if axis.length_squared() < 0.0001:
		return

	var dir := axis.normalized()
	var ortho := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := dir.cross(ortho).normalized() * radius
	var up := dir.cross(right).normalized() * radius

	var p0 := start + right
	var p1 := start - right
	var p2 := start + up
	var p3 := start - up
	var p4 := end + right
	var p5 := end - right
	var p6 := end + up
	var p7 := end - up

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_immediate_mesh.surface_set_color(arrow_color)

	_add_quad(p0, p4, p6, p2)
	_add_quad(p1, p3, p7, p5)
	_add_quad(p2, p6, p7, p3)
	_add_quad(p0, p1, p5, p4)
	_add_quad(p0, p2, p3, p1)
	_add_quad(p4, p5, p7, p6)

	_immediate_mesh.surface_end()


func _add_arrow_head(tip: Vector3, dir: Vector3, length: float, radius: float) -> void:
	var ortho := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := dir.cross(ortho).normalized() * radius
	var up := dir.cross(right).normalized() * radius
	var base_center := tip - dir * length

	var p1 := base_center + right
	var p2 := base_center + up
	var p3 := base_center - right
	var p4 := base_center - up

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_immediate_mesh.surface_set_color(arrow_color)

	_add_triangle(tip, p1, p2)
	_add_triangle(tip, p2, p3)
	_add_triangle(tip, p3, p4)
	_add_triangle(tip, p4, p1)
	_add_quad(p1, p2, p3, p4)

	_immediate_mesh.surface_end()


func _add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_triangle(a, b, c)
	_add_triangle(a, c, d)


func _add_triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	_immediate_mesh.surface_add_vertex(a)
	_immediate_mesh.surface_add_vertex(b)
	_immediate_mesh.surface_add_vertex(c)
