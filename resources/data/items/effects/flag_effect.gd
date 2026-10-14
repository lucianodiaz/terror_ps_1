class_name FlagEffect
extends ItemEffect

## Writes flags when the item is used. LOCAL flags without a room_id resolve
## to the room the player is in.

@export var actions: Array[FlagAction] = []


func apply(ctx: ItemUseContext) -> void:
	if ctx.room == null:
		push_error("FlagEffect.apply: no room loaded")
		return
	FlagAction.apply_all(actions, ctx.room)
