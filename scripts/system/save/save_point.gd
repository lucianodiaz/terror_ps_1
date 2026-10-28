@tool
class_name SavePoint
extends Area3D

## Typewriter style save point, interacting opens the LoadScreen in SAVE mode.
## The collision layer must match the player's interactables mask, layer 7.

## Taken from the inventory on every save, like the ink ribbon. Empty saves for free.
@export var required_item_id: String = ""
@export_multiline var missing_item_text: String = "Necesitas una cinta de tinta para guardar."


func _validate_property(property: Dictionary) -> void:
	if property.name != "required_item_id":
		return
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ItemsPackage.get_editor_enum_hint()


func interact() -> void:
	if required_item_id != "" and not Inventory.has_item(required_item_id):
		MessageManager.show_hint(missing_item_text)
		return
	## The player gets the action press before the autoloads, opening right
	## away would let that same press pick the first slot
	LoadScreen.open.call_deferred(LoadScreen.Mode.SAVE, required_item_id)
