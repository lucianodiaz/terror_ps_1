@tool
class_name RoomsPackage
extends Resource

const RESOURCE_PATH : String = "res://resources/data/room_list.tres"

@export var rooms: Dictionary[String, PackedScene] = {}


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


static func get_editor_enum_hint() -> String:
	var ids : PackedStringArray= get_room_ids()
	if ids.is_empty():
		return ""
	return "," + ",".join(ids)
