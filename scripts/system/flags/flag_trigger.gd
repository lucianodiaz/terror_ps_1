class_name FlagTrigger
extends Area3D

## Applies flag actions when the player enters the area, interacts with it,
## or as soon as all its conditions are met.
## ON_ENTER needs the collision mask to include the player layer.
## ON_INTERACT needs the collision layer to match the player's interactables mask.
## ON_CONDITIONS_MET needs no collision shape at all.

signal triggered(trigger: FlagTrigger)

enum Mode {
	ON_ENTER,
	ON_INTERACT,
	ON_CONDITIONS_MET
}

## Unique id inside the room, empty uses the node name
@export var trigger_id: String = ""
@export var mode: Mode = Mode.ON_ENTER
## Fires only once for ever
@export var once: bool = true
## Where the fired state is stored when once is true.
## Empty uses a LOCAL flag "trigger.<trigger_id>.fired" in this room.
## Use a GLOBAL one to place the trigger outside of a room.
@export var fired_flag: FlagRef = null
## All of them must be met for the trigger to fire
@export var conditions: Array[FlagCondition] = []
@export var actions: Array[FlagAction] = []

var _default_fired_flag: FlagRef = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if mode == Mode.ON_CONDITIONS_MET:
		GameStateManager.flag_changed.connect(_on_flag_changed)
		## The conditions may already be met from a previous visit.
		## Deferred so listeners connected on the parent _ready() don't miss it.
		fire.call_deferred()


func interact() -> void:
	if mode == Mode.ON_INTERACT:
		fire()


func get_fired_flag() -> FlagRef:
	if fired_flag:
		return fired_flag
	if _default_fired_flag == null:
		var id: String = trigger_id if trigger_id != "" else String(name)
		_default_fired_flag = FlagRef.create(FlagRef.Scope.LOCAL, "trigger.%s.fired" % id)
	return _default_fired_flag


func has_fired() -> bool:
	var value: Variant = get_fired_flag().get_value(self, false)
	return value is bool and value


func fire() -> bool:
	if once and has_fired():
		return false
	if not FlagCondition.all_met(conditions, self):
		return false
	## Written before the actions so a cascade of flag changes can't re-enter here
	if once:
		get_fired_flag().set_value(true, self)
	FlagAction.apply_all(actions, self)
	triggered.emit(self)
	return true


func _on_body_entered(body: Node3D) -> void:
	if mode == Mode.ON_ENTER and body is Player:
		fire()


func _on_flag_changed(_scope: FlagRef.Scope, _room_id: String, _flag_name: String, _value: Variant) -> void:
	fire()
