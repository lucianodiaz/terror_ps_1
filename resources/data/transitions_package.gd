@tool
class_name TransitionsPackage
extends Resource

const RESOURCE_PATH : String = "res://resources/data/transition_list.tres"

@export var transitions: Dictionary[String, PackedScene] = {}

## Loading the package loads every transition scene, so the inspector hint
## reuses the ids until the .tres changes on disk.
static var _cached_ids: PackedStringArray = PackedStringArray()
static var _cached_ids_mtime: int = -1


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


static func get_cached_transition_ids() -> PackedStringArray:
	var mtime: int = FileAccess.get_modified_time(RESOURCE_PATH)
	if mtime != _cached_ids_mtime:
		_cached_ids = get_transition_ids()
		_cached_ids_mtime = mtime
	return _cached_ids


static func get_editor_enum_hint() -> String:
	var ids : PackedStringArray = get_cached_transition_ids()
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
