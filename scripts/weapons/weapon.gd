@tool
class_name Weapon
extends Node3D

## Base for anything the player holds. Follows a bone of the skeleton and
## exposes use(), subclasses decide what an attack does in _perform().

signal attacked()

@export var skeleton: Skeleton3D:
	set(value):
		_disconnect_skeleton()
		skeleton = value
		_connect_skeleton()

@export var follow_bone: String = "RightHand":
	set(value):
		follow_bone = value
		_bone_index = -1

@export var follow_rotation: bool = true

@export_group("Grip")
## Offset in the bone's local space (meters).
@export var grip_position_offset: Vector3 = Vector3.ZERO
## Offset in the bone's local space (degrees).
@export var grip_rotation_offset: Vector3 = Vector3.ZERO
@export_group("")

@export var instigator : Node :
	set(value):
		instigator = value
		if hit_component:
			hit_component.instigator = instigator

@export var hit_component: HitComponent

var data: WeaponData = null
## Inventory id of the item this weapon came from
var item_id: String = ""

var _bone_index: int = -1
var _ready_at_msec: int = 0

func _ready() -> void:
	_connect_skeleton()

## Called by WeaponHolderComponent right after instancing the scene
func setup(new_skeleton: Skeleton3D, new_instigator: Node, new_item_id: String, new_data: WeaponData) -> void:
	item_id = new_item_id
	data = new_data
	instigator = new_instigator
	if hit_component:
		hit_component.instigator = instigator
	if data:
		follow_bone = data.follow_bone
		grip_position_offset = data.grip_position_offset
		grip_rotation_offset = data.grip_rotation_offset
	skeleton = new_skeleton

func can_use() -> bool:
	return Time.get_ticks_msec() >= _ready_at_msec

## Returns true when the attack actually happened, the player only plays the
## attack animation in that case
func use() -> bool:
	if not can_use():
		return false
	var cooldown: float = data.cooldown if data else 0.0
	_ready_at_msec = Time.get_ticks_msec() + int(cooldown * 1000.0)
	if not _perform():
		return false
	attacked.emit()
	return true

func _perform() -> bool:
	return true

func _connect_skeleton() -> void:
	_bone_index = -1
	if skeleton and not skeleton.skeleton_updated.is_connected(_follow_bone):
		skeleton.skeleton_updated.connect(_follow_bone)

func _disconnect_skeleton() -> void:
	if skeleton and skeleton.skeleton_updated.is_connected(_follow_bone):
		skeleton.skeleton_updated.disconnect(_follow_bone)

func _follow_bone() -> void:
	if not skeleton:
		return

	if _bone_index == -1:
		_bone_index = skeleton.find_bone(follow_bone)
		if _bone_index == -1:
			return

	var bone_transform := skeleton.global_transform * skeleton.get_bone_global_pose(_bone_index)

	var grip := Transform3D(
		Basis.from_euler(grip_rotation_offset * (PI / 180.0)),
		grip_position_offset
	)

	if follow_rotation:
		global_transform = bone_transform * grip
	else:
		global_position = bone_transform * grip_position_offset
