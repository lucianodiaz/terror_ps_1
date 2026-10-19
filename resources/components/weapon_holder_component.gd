class_name WeaponHolderComponent
extends Node

## Keeps the equipped inventory item in the player's hand. The weapon scene is
## instanced under the skeleton and follows the bone set in its WeaponData.

signal weapon_changed(weapon: Weapon)

@export var skeleton: Skeleton3D
## Damage source for the weapon, its own hurtbox is ignored
@export var instigator: Node

var current_weapon: Weapon = null


func _ready() -> void:
	Inventory.equipment_changed.connect(_on_equipment_changed)
	## The player is rebuilt with every room, the equipment outlives it
	_on_equipment_changed(Inventory.equipped_id)


func has_weapon() -> bool:
	return is_instance_valid(current_weapon)


func get_weapon_data() -> WeaponData:
	return current_weapon.data if has_weapon() else null


func try_attack() -> bool:
	if not has_weapon():
		return false
	return current_weapon.use()


func cancel_attack() -> void:
	if has_weapon() and current_weapon.has_method("cancel"):
		current_weapon.cancel()


func _on_equipment_changed(item_id: String) -> void:
	_clear_weapon()
	var item: ItemData = ItemsPackage.get_item(item_id)
	if item == null or not item.is_weapon() or item.weapon.scene == null:
		weapon_changed.emit(null)
		return
	if skeleton == null:
		push_error("WeaponHolderComponent: skeleton is not set")
		weapon_changed.emit(null)
		return
	var weapon: Weapon = item.weapon.scene.instantiate() as Weapon
	if weapon == null:
		push_error("WeaponHolderComponent: scene of '%s' is not a Weapon" % item_id)
		weapon_changed.emit(null)
		return
	weapon.instigator = instigator
	skeleton.add_child(weapon)
	weapon.setup(skeleton, instigator, item_id, item.weapon)
	current_weapon = weapon
	weapon_changed.emit(current_weapon)


func _clear_weapon() -> void:
	if has_weapon():
		current_weapon.queue_free()
	current_weapon = null
