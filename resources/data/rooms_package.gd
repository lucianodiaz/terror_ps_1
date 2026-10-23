@tool
class_name RoomsPackage
extends Resource

const RESOURCE_PATH : String = "res://resources/data/room_list.tres"

@export var rooms: Dictionary[String, PackedScene] = {}

## Loading the package loads every room scene, so the inspector hint reuses
## the ids until the .tres changes on disk.
static var _cached_ids: PackedStringArray = PackedStringArray()
static var _cached_ids_mtime: int = -1


static func load_package() -> Resource:
	return ResourceLoader.load(RESOURCE_PATH)


static func get_room_ids() -> PackedStringArray:
	var package : Resource= load_package()
	if package == null:
		return PackedStringArray()
	var rooms_dict: Variant = package.get("rooms")
	if typeof(rooms_dict) != TYPE_DICTIONARY:
		return PackedStringArray()
	var ids : PackedStringArray= PackedStringArray(rooms_dict.keys())
	ids.sort()
	return ids


static func get_cached_room_ids() -> PackedStringArray:
	var mtime: int = FileAccess.get_modified_time(RESOURCE_PATH)
	if mtime != _cached_ids_mtime:
		_cached_ids = get_room_ids()
		_cached_ids_mtime = mtime
	return _cached_ids


static func get_editor_enum_hint() -> String:
	var ids : PackedStringArray= get_cached_room_ids()
	if ids.is_empty():
		return ""
	return "," + ",".join(ids)
