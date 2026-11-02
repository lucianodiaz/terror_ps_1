extends CanvasLayer

@export var cursor_sprite: Sprite2D = null
@export var mouse_speed: float = 300.0
@export var edge_margin: float = 12.0
@export var cursor_speed: float = 2000.0  # Speed of the cursor in pixels per second

var _last_tick_usec: int = 0
var _animation_player: AnimationPlayer
var _clamped_viewport_position: Vector2 = Vector2.ZERO
## Posición lógica del cursor; no usar get_mouse_position() para acumular stick (falla en windowed tras warp).
var _cursor_position: Vector2 = Vector2.ZERO
var _stick_active: bool = false


var cursor_visibility: bool = true :
	set(value):
		cursor_visibility = value
		if value:
			visible = true
		else:
			visible = false
	get:
		return cursor_visibility

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _animation_player:
		_animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_animation_player.set_process(false)
		if not _animation_player.is_playing():
			_animation_player.play("idle")

	_last_tick_usec = Time.get_ticks_usec()
	_cursor_position = _clamp_viewport_position(get_viewport().get_mouse_position())
	_clamped_viewport_position = _cursor_position
	cursor_sprite.global_position = _cursor_position


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_stick_active = false
		_cursor_position = _clamp_viewport_position(event.position)


func get_clamped_viewport_position() -> Vector2:
	return _clamped_viewport_position


func get_clamped_world_position(canvas_item: CanvasItem) -> Vector2:
	return canvas_item.get_viewport().get_canvas_transform().affine_inverse() * _clamped_viewport_position


func _clamp_viewport_position(position: Vector2) -> Vector2:
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	var margin_x := minf(edge_margin, viewport_size.x * 0.5)
	var margin_y := minf(edge_margin, viewport_size.y * 0.5)

	return Vector2(
		clampf(position.x, margin_x, viewport_size.x - margin_x),
		clampf(position.y, margin_y, viewport_size.y - margin_y)
	)


func _get_clamped_mouse_position() -> Vector2:
	return _clamp_viewport_position(get_viewport().get_mouse_position())


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := float(now - _last_tick_usec) / 1_000_000.0
	_last_tick_usec = now

	var input_vector := Input.get_vector("cursor_left", "cursor_right", "cursor_up", "cursor_down")
	if input_vector != Vector2.ZERO:
		_stick_active = true
		_cursor_position = _clamp_viewport_position(
			_cursor_position + input_vector * cursor_speed * real_delta
		)
		Input.warp_mouse(_cursor_position)
		cursor_sprite.global_position = _cursor_position
	elif not _stick_active:
		var blend := clampf(mouse_speed * real_delta, 0.0, 1.0)
		cursor_sprite.global_position = lerp(cursor_sprite.global_position, _cursor_position, blend)

	_clamped_viewport_position = _cursor_position

	if _animation_player and _animation_player.is_playing():
		_animation_player.advance(real_delta)
	