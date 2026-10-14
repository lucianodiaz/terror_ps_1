@tool
class_name TransitionsPackage
extends Resource

const RESOURCE_PATH : String = "res://resources/data/transition_list.tres"

@export var transitions: Dictionary[String, PackedScene] = {}


static func load_package() -> Resource:
	return ResourceLoader.load(RESOURCE_PATH)


static func get_transition_ids() -> PackedStringArray:
	var package : Resource = load_package()
	if package == null:
		return PackedStringArray()
	var transitions_dict: Variant = package.get("transitions")
	if typeof(transitions_dict) != TYPE_DICTIONARY:
		return PackedStringArray()
	var ids : PackedStringArray = PackedStringArray(transitions_dict.keys())
	ids.sort()
	return ids


static func get_editor_enum_hint() -> String:
	var ids : PackedStringArray = get_transition_ids()
	if ids.is_empty():
		return ""
	return "," + ",".join(ids)


## Returns null when the id is empty or unknown, so the room change stays instant
static func get_transition(id: String) -> PackedScene:
	if id == "":
		return null
	var package : Resource = load_package()
	if package == null:
		return null
	var transitions_dict: Variant = package.get("transitions")
	if typeof(transitions_dict) != TYPE_DICTIONARY:
		return null
	return transitions_dict.get(id, null)
