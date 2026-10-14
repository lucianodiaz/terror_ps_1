class_name Examinable
extends Area3D

## Something the player reads without taking it: signs, notes, paintings.
## The collision layer must match the player's interactables mask, layer 7.
## The read state is stored as a LOCAL flag "examine.<examine_id>.read", so
## other systems can condition on the player having read it.

signal examined(examine_id: String)

@export_multiline var examine_text: String = ""
## Falls back to the node name when empty
@export var examine_id: String = ""
## Reads only the first time, afterwards interacting does nothing
@export var once: bool = false

var _read_flag: FlagRef = null


func _ready() -> void:
	_read_flag = FlagRef.create(FlagRef.Scope.LOCAL, "examine.%s.read" % get_examine_id())


func get_examine_id() -> String:
	return examine_id if examine_id != "" else String(name)


func is_read() -> bool:
	var value: Variant = _read_flag.get_value(self, false)
	return value is bool and value


func interact() -> void:
	if examine_text == "":
		push_error("Examinable.interact: examine_text is empty on '%s'" % name)
		return
	if once and is_read():
		return
	_read_flag.set_value(true, self)
	examined.emit(get_examine_id())
	MessageManager.show_examine(examine_text)
