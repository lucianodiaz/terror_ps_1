@tool
## Heart monitor of the inventory condition box. The trace scrolls from right
## to left and fades out at the old end, the color and pace follow the health.
class_name EcgMonitor
extends Control

@export var trace_color: Color = Color(0.25, 1.0, 0.35)
@export var grid_color: Color = Color(0.1, 0.35, 0.15, 0.6)
@export var beats_per_minute: float = 60.0
## Pixels the trace moves per second
@export var scroll_speed: float = 260.0
@export var line_width: float = 3.0
@export var grid_step: float = 18.0

var _time: float = 0.0


func set_condition(color: Color, bpm: float) -> void:
	trace_color = color
	beats_per_minute = bpm
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_grid()
	var width: float = size.x
	var mid: float = size.y * 0.55
	var amplitude: float = size.y * 0.42
	var beat_length: float = 60.0 / maxf(beats_per_minute, 1.0)
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var step: float = 2.0
	var x: float = 0.0
	while x <= width:
		var sample_time: float = _time - (width - x) / scroll_speed
		var phase: float = fposmod(sample_time, beat_length) / beat_length
		points.append(Vector2(x, mid - _wave(phase) * amplitude))
		var fade: Color = trace_color
		fade.a = clampf(x / width, 0.0, 1.0)
		colors.append(fade)
		x += step
	if points.size() > 1:
		draw_polyline_colors(points, colors, line_width, true)


func _draw_grid() -> void:
	var x: float = 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), grid_color, 1.0)
		x += grid_step
	var y: float = 0.0
	while y <= size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), grid_color, 1.0)
		y += grid_step


## One heartbeat, phase goes from 0 to 1
func _wave(phase: float) -> float:
	return (
		0.12 * _bump(phase, 0.12, 0.025)
		- 0.15 * _bump(phase, 0.30, 0.008)
		+ 1.0 * _bump(phase, 0.33, 0.010)
		- 0.35 * _bump(phase, 0.36, 0.010)
		+ 0.25 * _bump(phase, 0.60, 0.040)
	)


func _bump(phase: float, center: float, width: float) -> float:
	var d: float = (phase - center) / width
	return exp(-d * d)
