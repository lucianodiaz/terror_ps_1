class_name HealthComponent
extends Node

@export_range(0.0,500.0,1.0,"suffix:hp") var max_health : float = 100.0
@export var has_hit_invisibility : bool = true

@export_range(0.0,1.0,0.1,"suffix:seg") var hit_cooldown : float = 0.2 :
	set(value):
		hit_cooldown = value
		set_invisibility_cooldown(hit_cooldown)


var timer:Timer = null

signal on_health_changed(actual_health:float,dmg_received:float)
signal on_entity_died(is_dead:bool)

var hit_invisibility := false

var is_died := false
var current_health:float

func _init() -> void:
	timer = Timer.new()
	add_child(timer)
	timer.name = "Timer"
	timer.one_shot = true
	timer.autostart = false
	timer.timeout.connect(_on_timer_timeout)

func set_invisibility_cooldown(value)-> void:
	if not timer:
		return
	timer.wait_time = value

func _ready() -> void:
	if has_hit_invisibility:
		timer.wait_time = hit_cooldown
	
	initialize_health()
	pass


func damage(dmg:float) -> void:
	if is_died:
		return
	if hit_invisibility:
		return
	current_health = clamp(current_health-dmg,0,max_health)
	emit_signal("on_health_changed",current_health,dmg)
	
	if has_hit_invisibility:
		hit_invisibility = true
		timer.start()
	
	is_died = current_health <= 0
	if is_died:
		emit_signal("on_entity_died",is_died)
	

func set_max_health(health:float) -> void:
	max_health = health

## Ignores the hit invisibility, dmg_received is negative for heals
func heal(h:float) -> void:
	if is_died or h <= 0.0:
		return
	var previous: float = current_health
	current_health = minf(current_health + h, max_health)
	if current_health != previous:
		on_health_changed.emit(current_health, previous - current_health)


func is_full() -> bool:
	return current_health >= max_health

func initialize_health() -> void:
	current_health = max_health

## Sets the health without counting it as damage or heal, e.g. when loading a checkpoint
func restore_health(health: float) -> void:
	current_health = clampf(health, 0.0, max_health)
	is_died = current_health <= 0.0
	on_health_changed.emit(current_health, 0.0)

func percent_health() -> float:
	return (current_health * 100) / max_health

func get_health_ratio() -> float:
	return clampf(current_health / max_health, 0.0, 1.0)

func _on_timer_timeout() -> void:
	hit_invisibility = false
