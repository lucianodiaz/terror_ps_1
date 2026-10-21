class_name EnemyTest

extends CharacterBody3D

const ANIM_IDLE := &"Idle_Watchful"
const ANIM_HIT_REACTION := &"hit_reaction"

@export var health_component: HealthComponent
@export var animation_player: AnimationPlayer
@export_range(0.0, 0.3, 0.01, "suffix:s") var hit_blend_time: float = 0.05


var is_dead: bool = false

func _ready() -> void:
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
	
	if health_component:
		health_component.on_entity_died.connect(_on_died)


func _on_died(dead:bool) -> void:
	print("[EnemyTest] - Died")
	animation_player.play("dying")
	is_dead = dead


func _on_hurt(area: Area3D) -> void:
	print("[EnemyTest] - Hurt by ", area.owner if area else null)
	play_hit_reaction()


func play_hit_reaction() -> void:
	if animation_player == null or health_component and health_component.is_died:
		return
	if animation_player.current_animation == ANIM_HIT_REACTION:
		animation_player.seek(0.0, true)
	else:
		animation_player.play(ANIM_HIT_REACTION, hit_blend_time)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_HIT_REACTION:
		animation_player.play(ANIM_IDLE, 0.2)
