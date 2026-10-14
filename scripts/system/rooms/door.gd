@tool
class_name Door
extends Node3D

## This signal is emitted when the door state changes useful for UI updates
signal door_state_changed(door_name: String, new_state: DoorState)

## This signal is emitted when the player tries a locked door useful for UI updates
## reason is one of the LOCK_REASON_* constants
signal door_locked(door_name: String, reason: String)

## This signal is emitted when the door gets unlocked by the player (key or this side)
signal door_unlocked(door_name: String)

##This emit is listened by the room manager to change the room
signal requested_to_change_room(from_door_name: String,new_room_name: String, target_door_name: String, transition_type: String)


enum DoorState{
	LOCKED,
	UNLOCKED
}

const LOCK_REASON_KEY: String = "key"
const LOCK_REASON_OTHER_SIDE: String = "other_side"
const LOCK_REASON_CONDITION: String = "condition"

const DEFAULT_LOCK_MESSAGES: Dictionary[String, String] = {
	LOCK_REASON_KEY: "Esta cerrada con llave.",
	LOCK_REASON_OTHER_SIDE: "No se abre desde este lado.",
	LOCK_REASON_CONDITION: "Algo la mantiene cerrada.",
}

const DEFAULT_KEY_USED_MESSAGE: String = "Has usado %s."

@export var door_name: String = ""
@export var connected_room_name: String = ""
@export var target_door_name : String = ""
@export var spawn_player_position: Marker3D = null
## Cutscene played while changing rooms, empty changes room instantly
@export var transition_type: String = ""

@export_group("Lock")
@export var locked_by_default: bool = false
## Where the unlocked state of this door is stored.
## Both sides of a door pair must point to the same flag.
## Empty uses a LOCAL flag "door.<door_name>.unlocked" in this room.
@export var unlock_flag: FlagRef = null
## When all conditions are met the door is unlocked
@export var unlock_conditions: Array[FlagCondition] = []
@export var required_key_id: String = ""
@export var consume_key: bool = false
@export var unlockable_from_this_side: bool = false
@export var on_unlock_actions: Array[FlagAction] = []

@export_group("Messages")
## Shown when the player tries the door and it does not give.
## Empty uses the default text for the lock reason.
@export_multiline var locked_message: String = ""
## Shown when the required key unlocks the door, %s is the key name.
## Empty uses "Has usado <display_name>."
@export_multiline var key_used_message: String = ""

var door_state: DoorState = DoorState.UNLOCKED

var _default_unlock_flag: FlagRef = null


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"connected_room_name":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = RoomsPackage.get_editor_enum_hint()
		"transition_type":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = TransitionsPackage.get_editor_enum_hint()
		"required_key_id":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ItemsPackage.get_editor_enum_hint()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	GameStateManager.flag_changed.connect(_on_flag_changed)
	_refresh_state()


func is_unlocked() -> bool:
	if not locked_by_default or is_unlock_flag_set():
		return true
	return not unlock_conditions.is_empty() and FlagCondition.all_met(unlock_conditions, self)


func is_unlock_flag_set() -> bool:
	var flag_value: Variant = get_unlock_flag().get_value(self, false)
	return flag_value is bool and flag_value


func get_unlock_flag() -> FlagRef:
	if unlock_flag:
		return unlock_flag
	if _default_unlock_flag == null:
		_default_unlock_flag = FlagRef.create(FlagRef.Scope.LOCAL, "door.%s.unlocked" % door_name)
	return _default_unlock_flag


func try_open_door() -> void:
	if connected_room_name == "":
		push_error("Door.try_open_door: connected_room_name is empty")
		return

	if not is_unlocked():
		var reason: String = _get_lock_reason()
		if reason != "":
			door_locked.emit(door_name, reason)
			MessageManager.show_hint(get_locked_message(reason))
			return
		await _unlock()
		## Using a key only unlocks the door, the player goes through on a second
		## interaction, so unlock events have room to play
		if required_key_id != "" and not unlockable_from_this_side:
			return
	## The other side of a door pair may be locked even if this side isn't
	elif unlockable_from_this_side and not is_unlock_flag_set():
		_unlock()

	requested_to_change_room.emit(door_name, connected_room_name, target_door_name, transition_type)


func get_locked_message(reason: String) -> String:
	if locked_message != "":
		return locked_message
	return DEFAULT_LOCK_MESSAGES.get(reason, "")


## Returns an empty string when the player can unlock the door right now
func _get_lock_reason() -> String:
	if unlockable_from_this_side:
		return ""
	if required_key_id != "":
		return "" if Inventory.has_item(required_key_id) else LOCK_REASON_KEY
	if not unlock_conditions.is_empty():
		return LOCK_REASON_CONDITION
	return LOCK_REASON_OTHER_SIDE


func _unlock() -> void:
	if required_key_id != "" and not unlockable_from_this_side:
		await _show_key_used_message()
		if consume_key:
			Inventory.remove_item(required_key_id)
	get_unlock_flag().set_value(true, self)
	FlagAction.apply_all(on_unlock_actions, self)
	door_unlocked.emit(door_name)


func _show_key_used_message() -> void:
	var data: ItemData = ItemsPackage.get_item(required_key_id)
	var key_name: String = data.display_name if data and data.display_name != "" else required_key_id
	var template: String = key_used_message if key_used_message != "" else DEFAULT_KEY_USED_MESSAGE
	MessageManager.show_examine(template % key_name if "%s" in template else template)
	await MessageManager.message_closed


func _refresh_state() -> void:
	var new_state: DoorState = DoorState.UNLOCKED if is_unlocked() else DoorState.LOCKED
	if new_state == door_state:
		return
	door_state = new_state
	door_state_changed.emit(door_name, door_state)


func _on_flag_changed(_scope: FlagRef.Scope, _room_id: String, _flag_name: String, _value: Variant) -> void:
	_refresh_state()
