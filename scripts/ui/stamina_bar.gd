## HUD bar of the StaminaComponent. Drawn by hand so the fill, the trail of the
## stamina just spent and the punch, shake and flash effects share one transform.
## Fades out a moment after filling up, the HUD stays clean while exploring.
class_name StaminaBar
extends Control

@export var stamina_component: StaminaComponent

@export_group("Colors")
@export var background_color: Color = Color(0.02, 0.02, 0.02, 0.75)
@export var border_color: Color = Color(0.78, 0.76, 0.7, 0.9)
@export var full_color: Color = Color(0.55, 0.85, 0.35)
@export var low_color: Color = Color(0.95, 0.6, 0.15)
@export var exhausted_color: Color = Color(0.7, 0.06, 0.04)
@export var trail_color: Color = Color(1.0, 0.9, 0.7, 0.85)
@export var flash_color: Color = Color(1.0, 1.0, 1.0)
## Below this ratio the fill turns low_color and starts pulsing
@export_range(0.0, 1.0, 0.01) var low_ratio: float = 0.3

@export_group("Feel")
@export var fill_smoothing: float = 14.0
## Seconds the trail waits on a big spend before draining
@export var trail_hold_time: float = 0.35
## Ratio per second
@export var trail_drain_speed: float = 0.6
## Ratio lost in a single change that counts as a hit (a melee swing) and punches the bar
@export_range(0.0, 1.0, 0.01) var punch_threshold: float = 0.08
@export var punch_scale: float = 0.25
@export var shake_strength: float = 7.0
@export var fade_speed: float = 4.0
## Seconds the bar stays on screen after filling up
@export var hide_delay: float = 1.5

@export_group("Look")
@export var border_width: float = 2.0
@export var segments: int = 4
## Empty hides the label
@export var label_text: String = "STAMINA"
@export var label_font_size: int = 14

var _target: float = 1.0
var _display: float = 1.0
var _trail: float = 1.0
var _trail_hold: float = 0.0
var _shake: float = 0.0
var _punch: float = 0.0
var _flash: float = 0.0
var _deny: float = 0.0
## Stays above 0 for a moment after each increase, the regen shimmer reads it
var _regen: float = 0.0
var _full_time: float = 0.0
var _time: float = 0.0
var _exhausted: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	if stamina_component == null:
		push_warning("StaminaBar: stamina_component is not set")
		return
	stamina_component.on_stamina_changed.connect(_on_stamina_changed)
	stamina_component.on_exhausted_changed.connect(_on_exhausted_changed)
	stamina_component.on_action_denied.connect(_on_action_denied)
	_target = stamina_component.get_ratio_stamina()
	_display = _target
	_trail = _target
	_exhausted = stamina_component.is_exhausted


func _on_stamina_changed(current: float, maximum: float) -> void:
	var ratio: float = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	if ratio < _target:
		if _target - ratio >= punch_threshold:
			_trail_hold = trail_hold_time
			_punch = 1.0
			_shake = maxf(_shake, 0.45)
	elif ratio > _target:
		_regen = 0.15
		if ratio >= 1.0:
			_flash = 0.7
	_target = ratio


func _on_exhausted_changed(exhausted: bool) -> void:
	_exhausted = exhausted
	if exhausted:
		_shake = 1.0
		_punch = 1.0
	else:
		_flash = 1.0


func _on_action_denied() -> void:
	_shake = maxf(_shake, 0.7)
	_deny = 1.0


func _process(delta: float) -> void:
	_time += delta
	_display = lerpf(_display, _target, 1.0 - exp(-fill_smoothing * delta))
	if _trail_hold > 0.0:
		_trail_hold -= delta
	else:
		_trail = move_toward(_trail, _display, trail_drain_speed * delta)
	_trail = maxf(_trail, _display)

	_shake = move_toward(_shake, 0.0, 3.0 * delta)
	_punch = move_toward(_punch, 0.0, 4.0 * delta)
	_flash = move_toward(_flash, 0.0, 3.0 * delta)
	_deny = move_toward(_deny, 0.0, 2.5 * delta)
	_regen = maxf(_regen - delta, 0.0)

	var needed: bool = _target < 0.999 or _exhausted
	_full_time = 0.0 if needed else _full_time + delta
	var target_alpha: float = 1.0 if needed or _full_time < hide_delay else 0.0
	modulate.a = move_toward(modulate.a, target_alpha, fade_speed * delta)
	if modulate.a > 0.0:
		queue_redraw()


func _draw() -> void:
	## Squared so the shake snaps hard at first and settles softly
	var shake_offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
		* shake_strength * _shake * _shake
	## Overshoots once and comes back, stretching more in height than in width
	var punch: float = sin(_punch * PI) * _punch
	var scale_factor: Vector2 = Vector2(1.0 + punch_scale * 0.3 * punch, 1.0 + punch_scale * punch)
	var pivot: Vector2 = size * 0.5
	draw_set_transform(pivot - pivot * scale_factor + shake_offset, 0.0, scale_factor)

	_draw_label()
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	var inner: Rect2 = Rect2(Vector2.ONE * border_width, size - Vector2.ONE * border_width * 2.0)
	var trail_rect: Rect2 = Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y))
	draw_rect(trail_rect, trail_color)

	var fill_rect: Rect2 = Rect2(inner.position, Vector2(inner.size.x * _display, inner.size.y))
	var fill_color: Color = _get_fill_color()
	draw_rect(fill_rect, fill_color)
	draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, fill_rect.size.y * 0.35)),
		fill_color.lightened(0.3))
	_draw_regen(fill_rect)
	_draw_segments(inner)
	_draw_damage_marker(inner)

	var frame_color: Color = border_color
	if _exhausted:
		frame_color = border_color.lerp(exhausted_color, 0.5 + 0.5 * sin(_time * 12.0))
	frame_color = frame_color.lerp(exhausted_color.lightened(0.3), _deny)
	draw_rect(Rect2(Vector2.ZERO, size), frame_color, false, border_width)


func _get_fill_color() -> Color:
	var color: Color
	if _exhausted:
		color = exhausted_color.lerp(exhausted_color.lightened(0.35), 0.5 + 0.5 * sin(_time * 10.0))
	else:
		color = low_color.lerp(full_color, smoothstep(low_ratio * 0.5, low_ratio * 1.6, _display))
		if _display < low_ratio:
			color = color.lightened(0.25 * (0.5 + 0.5 * sin(_time * 8.0)))
	return color.lerp(flash_color, _flash)


## A bright band sweeps the fill and the tip glows while stamina comes back
func _draw_regen(fill_rect: Rect2) -> void:
	if _regen <= 0.0 or fill_rect.size.x <= 0.0:
		return
	var band_width: float = 18.0
	var band_x: float = fposmod(_time * 1.4, 1.0) * (fill_rect.size.x + band_width) - band_width
	var band: Rect2 = Rect2(fill_rect.position + Vector2(maxf(band_x, 0.0), 0.0),
		Vector2(band_width, fill_rect.size.y)).intersection(fill_rect)
	if band.size.x > 0.0:
		draw_rect(band, Color(1.0, 1.0, 1.0, 0.22))
	var tip: Rect2 = Rect2(fill_rect.end.x - 3.0, fill_rect.position.y, 3.0, fill_rect.size.y)
	draw_rect(tip.intersection(fill_rect), Color(1.0, 1.0, 1.0, 0.45 + 0.35 * sin(_time * 18.0)))


func _draw_segments(inner: Rect2) -> void:
	if segments <= 1:
		return
	var tick_color: Color = Color(background_color, 0.8)
	for i in range(1, segments):
		var x: float = inner.position.x + inner.size.x * float(i) / float(segments)
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), tick_color, 2.0)


## Notch under the bar where melee stops hitting at 100%
func _draw_damage_marker(inner: Rect2) -> void:
	if stamina_component == null or stamina_component.full_damage_ratio <= 0.0:
		return
	var x: float = inner.position.x + inner.size.x * stamina_component.full_damage_ratio
	var y: float = size.y + 2.0
	var color: Color = border_color if _display >= stamina_component.full_damage_ratio \
		else exhausted_color.lightened(0.3)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, y), Vector2(x - 5.0, y + 6.0), Vector2(x + 5.0, y + 6.0)
	]), color)


func _draw_label() -> void:
	if label_text.is_empty():
		return
	var font: Font = get_theme_default_font()
	draw_string(font, Vector2(0.0, -6.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		label_font_size, border_color)
