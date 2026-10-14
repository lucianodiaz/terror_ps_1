class_name ItemUseContext
extends RefCounted

## Everything an ItemEffect may need when an item is used, so effects
## don't have to look nodes up by themselves.

var item: ItemData = null
var player: Player = null
## Null while no room is loaded
var room: Room = null


func _init(new_item: ItemData, new_player: Player, new_room: Room) -> void:
	item = new_item
	player = new_player
	room = new_room


func get_health() -> HealthComponent:
	return player.health_component if player else null
