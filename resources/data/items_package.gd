@tool
class_name ItemsPackage
extends Resource

const RESOURCE_PATH : String = "res://resources/data/item_list.tres"

@export var items: Dictionary[String, ItemData] = {}

## Runtime keeps one copy so USE actions and the menu see the same ItemData.
## The editor reloads every time so the dropdown follows edits to the .tres.
static var _runtime_package: Resource = null
## The inspector hint reuses the ids until the .tres changes on disk.
static var _cached_ids: PackedStringArray = PackedStringArray()
static var _cached_ids_mtime: int = -1


static func load_package() -> Resource:
	if Engine.is_editor_hint():
		return ResourceLoader.load(RESOURCE_PATH)
	if _runtime_package == null:
		_runtime_package = ResourceLoader.load(RESOURCE_PATH)
	return _runtime_package


static func get_item_ids() -> PackedStringArray:
	var package: Resource = load_package()
	if package == null:
		return PackedStringArray()
	var items_dict: Variant = package.get("items")
	if typeof(items_dict) != TYPE_DICTIONARY:
		return PackedStringArray()
	var ids: PackedStringArray = PackedStringArray(items_dict.keys())
	ids.sort()
	return ids


static func get_cached_item_ids() -> PackedStringArray:
	var mtime: int = FileAccess.get_modified_time(RESOURCE_PATH)
	if mtime != _cached_ids_mtime:
		_cached_ids = get_item_ids()
		_cached_ids_mtime = mtime
	return _cached_ids


static func get_editor_enum_hint() -> String:
	var ids: PackedStringArray = get_cached_item_ids()
	if ids.is_empty():
		return ""
	return "," + ",".join(ids)


static func get_item(id: String) -> ItemData:
	if id == "":
		return null
	var package: Resource = load_package()
	if package == null:
		return null
	var items_dict: Variant = package.get("items")
	if typeof(items_dict) != TYPE_DICTIONARY:
		return null
	return items_dict.get(id, null)
