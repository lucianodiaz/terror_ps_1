@tool
class_name FlagRef
extends Resource

## Points to where a flag lives: the global scope or the local scope of a room.

enum Scope {
	GLOBAL,
	LOCAL
}

@export var scope: Scope = Scope.LOCAL:
	set(value):
		scope = value
		notify_property_list_changed()

## Room that owns the flag when scope is LOCAL.
## Empty means the room that contains the context node.
@export var room_id: String = ""

@export var flag_name: String = ""


static func create(new_scope: Scope, new_flag_name: String, new_room_id: String = "") -> FlagRef:
	var flag_ref := FlagRef.new()
	flag_ref.scope = new_scope
	flag_ref.flag_name = new_flag_name
	flag_ref.room_id = new_room_id
	return flag_ref


func _validate_property(property: Dictionary) -> void:
	if property.name != "room_id":
		return
	if scope == Scope.GLOBAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR
		return
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = RoomsPackage.get_editor_enum_hint()


func resolve_room_id(context: Node) -> String:
	if room_id != "":
		return room_id
	var node: Node = context
	while node != null:
		if node is Room:
			var room: Room = node
			return room.room_state.room_id if room.room_state else ""
		node = node.get_parent()
	return ""


func get_value(context: Node, default: Variant = null) -> Variant:
	if flag_name == "":
		push_error("FlagRef.get_value: flag_name is empty")
		return default
	if scope == Scope.GLOBAL:
		return GameStateManager.get_global_flag(flag_name, default)

	var resolved_room_id := resolve_room_id(context)
	if resolved_room_id == "":
		push_error("FlagRef.get_value: could not resolve room_id for flag '%s'" % flag_name)
		return default
	return GameStateManager.get_room_flag(resolved_room_id, flag_name, default)


func set_value(value: Variant, context: Node) -> void:
	if flag_name == "":
		push_error("FlagRef.set_value: flag_name is empty")
		return
	if scope == Scope.GLOBAL:
		GameStateManager.set_global_flag(flag_name, value)
		return

	var resolved_room_id := resolve_room_id(context)
	if resolved_room_id == "":
		push_error("FlagRef.set_value: could not resolve room_id for flag '%s'" % flag_name)
		return
	GameStateManager.set_room_flag(resolved_room_id, flag_name, value)
