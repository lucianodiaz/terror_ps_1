@tool
class_name Pickup
extends Area3D

## Item the player can pick up by interacting with it.
## The collision layer must match the player's interactables mask.
## Each pickup stores its own LOCAL flag "pickup.<pickup_id>.picked", so a room
## can hold several pickups of the same item.

signal picked_up(item_id: String, amount: int)

@export var item_id: String = "":
	set(value):
		item_id = value
		update_configuration_warnings()
@export var amount: int = 1
## Unique inside the room. Empty uses the node path relative to the room,
## so renaming or moving the node resets its picked state.
@export var pickup_id: String = ""

@export_group("Messages")
## Blocking text shown when the player takes it.
## Empty falls back to a short "Obtuviste <display_name>" notice.
@export_multiline var examine_text: String = ""

var _picked_flag: FlagRef = null


func _validate_property(property: Dictionary) -> void:
	if property.name != "item_id":
		return
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ItemsPackage.get_editor_enum_hint()


func _get_configuration_warnings() -> PackedStringArray:
	if item_id == "":
		return PackedStringArray(["item_id is empty, the pickup gives nothing."])
	return PackedStringArray()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("items")
	_picked_flag = FlagRef.create(FlagRef.Scope.LOCAL, "pickup.%s.picked" % get_pickup_id())
	if is_picked():
		queue_free()


func get_pickup_id() -> String:
	if pickup_id != "":
		return pickup_id
	var room: Room = _find_room()
	return String(room.get_path_to(self)) if room else String(name)


func is_picked() -> bool:
	var value: Variant = _picked_flag.get_value(self, false)
	return value is bool and value


func interact() -> void:
	if item_id == "":
		push_error("Pickup.interact: item_id is empty")
		return
	if is_picked():
		return
	var data: ItemData = ItemsPackage.get_item(item_id)
	if data == null:
		push_error("Pickup.interact: unknown item '%s'" % item_id)
		return
	if data.is_file():
		Inventory.add_file(item_id)
	elif not Inventory.add_item(item_id, amount):
		MessageManager.show_hint("No tienes espacio.")
		return
	_picked_flag.set_value(true, self)
	picked_up.emit(item_id, amount)
	_show_pickup_message(data)
	queue_free()


func _find_room() -> Room:
	var node: Node = get_parent()
	while node != null:
		if node is Room:
			return node
		node = node.get_parent()
	return null


## The view keeps its own copy of the text, so freeing this node right after is fine
func _show_pickup_message(data: ItemData) -> void:
	if examine_text != "":
		MessageManager.show_examine(examine_text)
	elif data.display_name != "":
		MessageManager.show_hint("Obtuviste %s" % data.display_name)
