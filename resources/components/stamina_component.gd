class_name StaminaComponent
extends Node

signal on_stamina_changed(current: float, maximum: float)
## true cuando la stamina llega a 0, false al recuperar recover_ratio
signal on_exhausted_changed(exhausted: bool)
## El jugador intentó correr o atacar sin stamina, para feedback en la UI
signal on_action_denied

@export_group("Stamina")
@export_range(0.0, 100.0) var max_stamina: float = 100.0
@export_range(0.0, 100.0) var stamina: float = 100.0

@export_group("Costs")
## Stamina por segundo mientras corre (solo si realmente se mueve)
@export_range(0.0, 100.0, 0.1) var run_cost_per_second: float = 12.0
## Stamina por cada ataque con arma melee
@export_range(0.0, 100.0, 0.1) var melee_attack_cost: float = 20.0
## Stamina por cada esquive de un ataque enemigo
@export_range(0.0, 100.0, 0.1) var dodge_cost: float = 15.0

@export_group("Regeneration")
## Segundos sin gastar stamina antes de recuperar estando quieto
@export_range(0.0, 10.0, 0.1) var idle_regen_delay: float = 2.0
## Segundos sin gastar stamina antes de recuperar mientras camina
@export_range(0.0, 10.0, 0.1) var walk_regen_delay: float = 5.0
@export_range(0.0, 100.0, 0.1) var idle_regen_rate: float = 25.0
@export_range(0.0, 100.0, 0.1) var walk_regen_rate: float = 8.0

@export_group("Exhaustion")
## Al llegar a 0 no se puede correr ni atacar hasta recuperar este ratio.
## Evita que el jugador parpadee entre correr y no correr con 1 punto de stamina.
@export_range(0.0, 1.0, 0.01) var recover_ratio: float = 0.2

@export_group("Melee Damage")
## Con este ratio de stamina o más, el melee hace el 100% del daño
@export_range(0.0, 1.0, 0.01) var full_damage_ratio: float = 0.5
## Multiplicador con stamina 0, sube linealmente hasta 1.0 en full_damage_ratio
@export_range(0.0, 1.0, 0.01) var min_damage_multiplier: float = 0.4

var is_exhausted: bool = false

## Tiempo transcurrido desde el último gasto (correr o atacar)
var _time_since_spent: float = 0.0


func _ready() -> void:
	stamina = max_stamina


## Llamar una vez por physics frame desde el Player
func process_stamina(delta: float, running: bool, moving: bool) -> void:
	if running:
		_spend(run_cost_per_second * delta)
		return

	_time_since_spent += delta
	if moving:
		if _time_since_spent >= walk_regen_delay:
			_set_stamina(stamina + walk_regen_rate * delta)
	elif _time_since_spent >= idle_regen_delay:
		_set_stamina(stamina + idle_regen_rate * delta)


func can_run() -> bool:
	return not is_exhausted and stamina > 0.0


func can_attack() -> bool:
	return not is_exhausted and stamina > 0.0


func deny() -> void:
	on_action_denied.emit()


## Descontar después de confirmar que el ataque salió (weapon.use() == true)
func spend_attack() -> void:
	_spend(melee_attack_cost)


## Calcular ANTES de spend_attack(), así el golpe usa la stamina con la que arrancó
func get_damage_multiplier() -> float:
	if full_damage_ratio <= 0.0:
		return 1.0
	var t: float = clampf(get_ratio_stamina() / full_damage_ratio, 0.0, 1.0)
	return lerpf(min_damage_multiplier, 1.0, t)


func get_ratio_stamina() -> float:
	if max_stamina <= 0.0:
		return 0.0
	return clampf(stamina / max_stamina, 0.0, 1.0)


func _spend(amount: float) -> void:
	if amount <= 0.0:
		return
	_time_since_spent = 0.0
	_set_stamina(stamina - amount)


func _set_stamina(value: float) -> void:
	value = clampf(value, 0.0, max_stamina)
	if is_equal_approx(value, stamina):
		return
	stamina = value
	on_stamina_changed.emit(stamina, max_stamina)
	_update_exhausted()


func _update_exhausted() -> void:
	if not is_exhausted and stamina <= 0.0:
		is_exhausted = true
		on_exhausted_changed.emit(true)
	elif is_exhausted and get_ratio_stamina() >= recover_ratio:
		is_exhausted = false
		on_exhausted_changed.emit(false)