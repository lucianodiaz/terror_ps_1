extends Node

const SLOT_COUNT: int = 8
const CANT_USE_MESSAGE: String = "No puedo usar esto ahora."
const CANT_COMBINE_MESSAGE: String = "No se puede combinar."
const FULL_MAGAZINE_MESSAGE: String = "Ya esta cargada."

signal inventory_changed()
signal files_changed()
signal equipment_changed(item_id: String)

## An empty slot is {}. Occupied slots are { "id": String, "amount": int }.
var slots: Array[Dictionary] = []
var files: Array[String] = []
## Empty means nothing equipped
var equipped_id: String = ""


func _ready() -> void:
	_reset_slots()


func _reset_slots() -> void:
	slots.clear()
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = {}


func add_item(item_id: String, amount: int = 1) -> bool:
	if item_id == "" or amount <= 0:
		push_error("Inventory.add_item: invalid item_id '%s' or amount %d" % [item_id, amount])
		return false
	var data: ItemData = ItemsPackage.get_item(item_id)
	if data == null:
		push_error("Inventory.add_item: unknown item '%s'" % item_id)
		return false
	if data.is_file():
		add_file(item_id)
		return true
	if not _can_fit(data, amount):
		return false
	_place(data, amount)
	inventory_changed.emit()
	return true


func remove_item(item_id: String, amount: int = 1) -> bool:
	if not has_item(item_id, amount):
		return false
	var remaining: int = amount
	for i in range(SLOT_COUNT - 1, -1, -1):
		if slots[i].get("id", "") != item_id:
			continue
		var take: int = mini(remaining, slots[i]["amount"])
		slots[i]["amount"] -= take
		remaining -= take
		if slots[i]["amount"] <= 0:
			slots[i] = {}
		if remaining <= 0:
			break
	if item_id == equipped_id and not has_item(item_id):
		unequip()
	inventory_changed.emit()
	return true


## Applies the use effects of the item in that slot.
## Returns { "used": bool, "message": String }, message explains a failed use.
func use_item(slot_index: int) -> Dictionary:
	var slot: Dictionary = get_slot(slot_index)
	if slot.is_empty():
		return _use_result(false, "")
	var item_id: String = slot["id"]
	var data: ItemData = ItemsPackage.get_item(item_id)
	if data == null or not data.is_usable():
		return _use_result(false, CANT_USE_MESSAGE)

	var player: Player = get_tree().get_first_node_in_group("player") as Player
	var ctx: ItemUseContext = ItemUseContext.new(data, player, SceneManager.current_room)
	var applicable: Array[ItemEffect] = []
	var fail_message: String = ""
	for effect in data.use_effects:
		if effect == null:
			continue
		if effect.can_apply(ctx):
			applicable.append(effect)
		elif fail_message == "":
			fail_message = effect.get_fail_message()
	if applicable.is_empty():
		return _use_result(false, fail_message if fail_message != "" else CANT_USE_MESSAGE)

	for effect in applicable:
		effect.apply(ctx)
	if data.consume_on_use:
		_take_from_slot(slot_index)
	return _use_result(true, "")


func _use_result(used: bool, message: String) -> Dictionary:
	return { "used": used, "message": message }


## Like remove_item() but takes from that exact slot, so using an item from
## the menu empties the slot the player picked
func _take_from_slot(slot_index: int) -> void:
	var slot: Dictionary = get_slot(slot_index)
	if slot.is_empty():
		return
	var item_id: String = slot["id"]
	slot["amount"] -= 1
	if slot["amount"] <= 0:
		slots[slot_index] = {}
	if item_id == equipped_id and not has_item(item_id):
		unequip()
	inventory_changed.emit()


## Reloads a ranged weapon when one slot holds it and the other its ammo,
## in any order. Returns { "combined": bool, "message": String }.
func combine(slot_a: int, slot_b: int) -> Dictionary:
	if slot_a == slot_b:
		return _combine_result(false, CANT_COMBINE_MESSAGE)
	var a: Dictionary = get_slot(slot_a)
	var b: Dictionary = get_slot(slot_b)
	if a.is_empty() or b.is_empty():
		return _combine_result(false, CANT_COMBINE_MESSAGE)
	var data_a: ItemData = ItemsPackage.get_item(a["id"])
	var data_b: ItemData = ItemsPackage.get_item(b["id"])
	if data_a == null or data_b == null:
		return _combine_result(false, CANT_COMBINE_MESSAGE)

	var weapon_slot: int = -1
	var ammo_slot: int = -1
	if data_a.is_ranged_weapon() and data_a.weapon.ammo_item_id == b["id"]:
		weapon_slot = slot_a
		ammo_slot = slot_b
	elif data_b.is_ranged_weapon() and data_b.weapon.ammo_item_id == a["id"]:
		weapon_slot = slot_b
		ammo_slot = slot_a
	else:
		return _combine_result(false, CANT_COMBINE_MESSAGE)
	return _reload(weapon_slot, ammo_slot)


func _reload(weapon_slot: int, ammo_slot: int) -> Dictionary:
	var weapon: Dictionary = slots[weapon_slot]
	var weapon_data: WeaponData = ItemsPackage.get_item(weapon["id"]).weapon
	var loaded: int = int(weapon.get("loaded", 0))
	var missing: int = weapon_data.magazine_size - loaded
	if missing <= 0:
		return _combine_result(false, FULL_MAGAZINE_MESSAGE)
	var taken: int = mini(missing, int(slots[ammo_slot]["amount"]))
	weapon["loaded"] = loaded + taken
	slots[ammo_slot]["amount"] -= taken
	if slots[ammo_slot]["amount"] <= 0:
		slots[ammo_slot] = {}
	inventory_changed.emit()
	return _combine_result(true, "")


func _combine_result(combined: bool, message: String) -> Dictionary:
	return { "combined": combined, "message": message }


## Rounds in the magazine of the first slot holding that weapon
func get_loaded(item_id: String) -> int:
	var index: int = _find_slot(item_id)
	return int(slots[index].get("loaded", 0)) if index != -1 else 0


## Takes one round from the weapon's magazine, false when it is empty
func consume_loaded(item_id: String) -> bool:
	var index: int = _find_slot(item_id)
	if index == -1:
		return false
	var loaded: int = int(slots[index].get("loaded", 0))
	if loaded <= 0:
		return false
	slots[index]["loaded"] = loaded - 1
	inventory_changed.emit()
	return true


func _find_slot(item_id: String) -> int:
	for i in SLOT_COUNT:
		if slots[i].get("id", "") == item_id:
			return i
	return -1


func equip(item_id: String) -> bool:
	var data: ItemData = ItemsPackage.get_item(item_id)
	if data == null or not data.equippable or not has_item(item_id):
		return false
	if equipped_id == item_id:
		return true
	equipped_id = item_id
	equipment_changed.emit(equipped_id)
	return true


func unequip() -> void:
	if equipped_id == "":
		return
	equipped_id = ""
	equipment_changed.emit(equipped_id)


func is_equipped(item_id: String) -> bool:
	return item_id != "" and equipped_id == item_id


func has_item(item_id: String, amount: int = 1) -> bool:
	return get_amount(item_id) >= amount


func get_amount(item_id: String) -> int:
	## Empty slots are {}, so an empty id would match them
	if item_id == "":
		return 0
	var total: int = 0
	for slot in slots:
		if slot.get("id", "") == item_id:
			total += slot["amount"]
	return total


func is_full() -> bool:
	for slot in slots:
		if slot.is_empty():
			return false
	return true


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= SLOT_COUNT:
		return {}
	return slots[index]


func add_file(item_id: String) -> void:
	if item_id == "" or files.has(item_id):
		return
	var data: ItemData = ItemsPackage.get_item(item_id)
	if data == null:
		push_error("Inventory.add_file: unknown item '%s'" % item_id)
		return
	files.append(item_id)
	files_changed.emit()


func has_file(item_id: String) -> bool:
	return files.has(item_id)


func _can_fit(data: ItemData, amount: int) -> bool:
	var leftover: int = amount
	for slot in slots:
		if slot.get("id", "") == data.item_id:
			leftover -= data.max_stack - slot["amount"]
			if leftover <= 0:
				return true
	var empty: int = 0
	for slot in slots:
		if slot.is_empty():
			empty += 1
	if leftover <= 0:
		return true
	var stacks_needed: int = ceili(float(leftover) / float(data.max_stack))
	return stacks_needed <= empty


func _place(data: ItemData, amount: int) -> void:
	var leftover: int = amount
	for i in SLOT_COUNT:
		if slots[i].get("id", "") != data.item_id:
			continue
		var room: int = data.max_stack - slots[i]["amount"]
		var add: int = mini(leftover, room)
		slots[i]["amount"] += add
		leftover -= add
		if leftover <= 0:
			return
	for i in SLOT_COUNT:
		if not slots[i].is_empty():
			continue
		var add: int = mini(leftover, data.max_stack)
		slots[i] = { "id": data.item_id, "amount": add }
		if data.is_ranged_weapon():
			slots[i]["loaded"] = mini(data.weapon.initial_loaded, data.weapon.magazine_size)
		leftover -= add
		if leftover <= 0:
			return


## Empty slots, no files and nothing equipped, for a new game
func reset() -> void:
	import_state({})


func export_state() -> Dictionary:
	return {
		"slots": slots.duplicate(true),
		"files": files.duplicate(),
		"equipped_id": equipped_id,
	}


func import_state(data: Dictionary) -> void:
	_reset_slots()
	files.clear()
	var imported_slots: Variant = data.get("slots", [])
	if imported_slots is Array:
		for i in mini(imported_slots.size(), SLOT_COUNT):
			var slot: Variant = imported_slots[i]
			if slot is Dictionary:
				slots[i] = slot.duplicate()
	var imported_files: Variant = data.get("files", [])
	if imported_files is Array:
		for file_id in imported_files:
			if file_id is String:
				files.append(file_id)
	var imported_equipped: Variant = data.get("equipped_id", "")
	equipped_id = imported_equipped if imported_equipped is String and has_item(imported_equipped) else ""
	inventory_changed.emit()
	files_changed.emit()
	equipment_changed.emit(equipped_id)
