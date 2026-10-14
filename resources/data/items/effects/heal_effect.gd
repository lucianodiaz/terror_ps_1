class_name HealEffect
extends ItemEffect

## Restores health to the player.

@export var amount: float = 20.0
## When true amount is a percent of max_health, otherwise hit points
@export var percent: bool = true
@export var full_health_message: String = "No lo necesito ahora."


func can_apply(ctx: ItemUseContext) -> bool:
	var health: HealthComponent = ctx.get_health()
	return health != null and not health.is_died and not health.is_full()


func apply(ctx: ItemUseContext) -> void:
	var health: HealthComponent = ctx.get_health()
	if health == null:
		return
	health.heal(health.max_health * amount / 100.0 if percent else amount)


func get_fail_message() -> String:
	return full_health_message
