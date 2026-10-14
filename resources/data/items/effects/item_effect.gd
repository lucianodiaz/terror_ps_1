@abstract class_name ItemEffect
extends Resource

## What an item does when the player uses it. ItemData keeps a list of these,
## and Inventory.use_item() only applies the ones that can apply right now.


func can_apply(_ctx: ItemUseContext) -> bool:
	return true


@abstract func apply(ctx: ItemUseContext) -> void


## Shown when no effect of the item can apply
func get_fail_message() -> String:
	return "No puedo usar esto ahora."
