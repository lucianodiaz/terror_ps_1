@tool
class_name ItemData
extends Resource

## Everything the game knows about an item. The Pickup node frees itself the
## moment you take it, so the inventory menu reads from here instead.

## FILE takes no slot in the grid, it goes to the files section
enum Kind { ITEM, FILE }

@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var kind: Kind = Kind.ITEM
@export_range(1, 99) var max_stack: int = 1

@export_group("Use")
## What the item does when used from the menu, empty means it can't be used
@export var use_effects: Array[ItemEffect] = []
## Only removed when at least one effect applied
@export var consume_on_use: bool = false
## Goes to the EQUIPO box instead of being used, weapons for example
@export var equippable: bool = false
## For the 3D viewer that comes later, unused for now
@export var model: PackedScene = null

@export_group("File")
## Pages shown one at a time when reading a FILE, after a title page with the
## display_name. Empty uses the description as the only page.
@export_multiline var pages: PackedStringArray = []
## Shown behind the text while reading, empty uses the icon
@export var file_image: Texture2D = null


func is_file() -> bool:
	return kind == Kind.FILE


func is_usable() -> bool:
	return not use_effects.is_empty()


## Title page first, then the text pages
func get_file_pages() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray([display_name])
	if not pages.is_empty():
		result.append_array(pages)
	elif description != "":
		result.append(description)
	return result


func get_file_image() -> Texture2D:
	return file_image if file_image else icon
