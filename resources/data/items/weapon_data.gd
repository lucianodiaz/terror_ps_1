@tool
class_name WeaponData
extends Resource

## How an equippable item behaves once it is in the player's hand.
## Lives inside ItemData.weapon, the scene only holds the visuals and hitboxes.

enum Type { MELEE, RANGED }

@export var type: Type = Type.MELEE
## Instanced under the player's Skeleton3D, its root must extend Weapon
@export var scene: PackedScene = null

@export_group("Grip")
@export var follow_bone: String = "RightHand"
## Offset in the bone's local space (meters).
@export var grip_position_offset: Vector3 = Vector3.ZERO
## Offset in the bone's local space (degrees).
@export var grip_rotation_offset: Vector3 = Vector3.ZERO

@export_group("Animation")
## Pose held while aiming, from the player's AnimationPlayer library
@export var aim_animation: StringName = &""
## Walk cycle with the weapon raised, played in reverse when walking backwards.
## Empty slides the aim pose instead.
@export var aim_walk_animation: StringName = &""
## Played once per attack standing still, on the whole body. Empty plays nothing
@export var attack_animation: StringName = &""
## Played once per attack while moving, only on the upper body so the legs keep
## the aim walk. Empty falls back to attack_animation
@export var attack_walk_animation: StringName = &""

@export_group("Combat")
@export var damage: float = 10.0
@export var knockback_force: float = 0.0
## Seconds before the weapon can be used again
@export_range(0.0, 5.0, 0.01, "suffix:s") var cooldown: float = 0.8

@export_group("Melee")
## Seconds after the attack starts where the hitbox is active, x = start, y = end
@export var hit_window: Vector2 = Vector2(0.25, 0.55)
## Damage scale of a swing that starts at full aim walking speed, standing still deals full damage
@export_range(0.0, 1.0, 0.01) var moving_damage_multiplier: float = 0.6

@export_group("Ranged")
## Item consumed when combining it with the weapon in the menu
@export var ammo_item_id: String = ""
@export_range(1, 99) var magazine_size: int = 10
## Rounds loaded when the weapon is picked up
@export_range(0, 99) var initial_loaded: int = 0
@export_range(0.0, 100.0, 0.1, "suffix:m") var fire_range: float = 30.0
## Widest yaw deviation of a shot fired at full aim walking speed, standing still shoots straight
@export_range(0.0, 45.0, 0.1, "suffix:°") var moving_spread: float = 10.0


func is_ranged() -> bool:
	return type == Type.RANGED


func get_attack_walk_animation() -> StringName:
	return attack_walk_animation if attack_walk_animation != &"" else attack_animation
