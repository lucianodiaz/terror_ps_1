## Player preferences that survive between sessions.
## The autoload is named SettingsManager, the class_name is only here so other
## scripts can write GameSettings.Device.GAMEPAD with static typing.
class_name GameSettings
extends Node

const SETTINGS_PATH : String = "user://settings.cfg"

## Which column of the options screen a binding belongs to
enum Device { KEYBOARD_MOUSE, GAMEPAD }

const BUS_MASTER: StringName = &"Master"
const BUS_BGM: StringName = &"BGM"
const BUS_SFX: StringName = &"SFX"
const VOLUME_BUSES: Array[StringName] = [BUS_MASTER, BUS_BGM, BUS_SFX]
## linear_to_db(0.0) is -inf, a silent bus goes here instead
const SILENT_DB: float = -80.0

## FULLSCREEN is the borderless one, EXCLUSIVE takes over the monitor
const WINDOW_MODES: Array[int] = [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const DEVICES: Array[Device] = [Device.KEYBOARD_MOUSE, Device.GAMEPAD]
## Settings file section of each Device
const BINDING_SECTIONS: Array[String] = ["bindings", "joypad_bindings"]
## Keyboard, mouse and gamepad inputs of these can be rebound
const REBINDABLE_ACTIONS: Array[StringName] = [
	&"forward", &"backward", &"left", &"right", &"run", &"aim", &"action", &"shoot", &"cancel", &"inventory",
]
## The stick walks with direction controls and the D-pad with tank controls,
## so the gamepad side of movement stays as the project sets it
const PAD_FIXED_ACTIONS: Array[StringName] = [&"forward", &"backward", &"left", &"right"]
## Pairs that share an input on purpose, rebinding one never takes it from the other
const SHARED_BINDINGS: Array[Array] = [
	[&"action", &"shoot"],
	[&"aim", &"cancel"],
	[&"run", &"cancel"],
]
## Saved bindings from another version are dropped, the defaults changed under them
const BINDINGS_VERSION: int = 2

## The wheel is left out, a scroll is too easy to send by accident
const MOUSE_BUTTON_NAMES: Dictionary[int, String] = {
	MOUSE_BUTTON_LEFT: "LMB",
	MOUSE_BUTTON_RIGHT: "RMB",
	MOUSE_BUTTON_MIDDLE: "MMB",
	MOUSE_BUTTON_XBUTTON1: "MOUSE 4",
	MOUSE_BUTTON_XBUTTON2: "MOUSE 5",
}
## Xbox names, the layout most pads on PC follow
const JOY_BUTTON_NAMES: Dictionary[int, String] = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "VIEW",
	JOY_BUTTON_GUIDE: "XBOX",
	JOY_BUTTON_START: "MENU",
	JOY_BUTTON_LEFT_STICK: "LS",
	JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-PAD UP",
	JOY_BUTTON_DPAD_DOWN: "D-PAD DOWN",
	JOY_BUTTON_DPAD_LEFT: "D-PAD LEFT",
	JOY_BUTTON_DPAD_RIGHT: "D-PAD RIGHT",
	JOY_BUTTON_MISC1: "SHARE",
}

signal bindings_changed

## Linear 0..1 per bus, on top of the volume the bus layout already has
var volumes: Dictionary[StringName, float] = {}
var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
## Window size, only used while windowed
var resolution: Vector2i = Vector2i(1920, 1080)
var vsync: bool = true

var _bus_base_db: Dictionary[StringName, float] = {}
## Codes of every device, as the project sets them
var _default_codes: Dictionary[StringName, PackedStringArray] = {}


func _ready() -> void:
	_cache_defaults()
	load_settings()


# Audio

func get_volume(bus: StringName) -> float:
	return float(volumes.get(bus, 1.0))


func set_volume(bus: StringName, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(get_volume(bus), value):
		return
	volumes[bus] = value
	_apply_volume(bus)
	save_settings()


func _apply_volume(bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var value: float = get_volume(bus)
	var db: float = SILENT_DB if value <= 0.0 else float(_bus_base_db.get(bus, 0.0)) + linear_to_db(value)
	AudioServer.set_bus_volume_db(index, db)


# Display

func set_window_mode(mode: DisplayServer.WindowMode) -> void:
	if window_mode == mode:
		return
	window_mode = mode
	_apply_display()
	save_settings()


func set_resolution(size: Vector2i) -> void:
	if resolution == size:
		return
	resolution = size
	_apply_display()
	save_settings()


func set_vsync(enabled: bool) -> void:
	if vsync == enabled:
		return
	vsync = enabled
	_apply_display()
	save_settings()


## The sizes from RESOLUTIONS that fit on the screen the window is on
func get_available_resolutions() -> Array[Vector2i]:
	var screen_size: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var available: Array[Vector2i] = []
	for size in RESOLUTIONS:
		if size.x <= screen_size.x and size.y <= screen_size.y:
			available.append(size)
	if available.is_empty():
		available.append(RESOLUTIONS[0])
	return available


func _apply_display() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if DisplayServer.window_get_mode() != window_mode:
		DisplayServer.window_set_mode(window_mode)
	if window_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		## Leaving fullscreen, the OS has to restore the window before it takes a new size
		_apply_window_size.call_deferred()


func _apply_window_size() -> void:
	var window: Window = get_window()
	window.size = resolution
	window.move_to_center()


# Bindings

## Codes of the action's inputs on one device (see _input_code). The first one
## is the primary, the one rebinding replaces
func get_action_codes(action: StringName, device: Device) -> PackedStringArray:
	var codes: PackedStringArray = PackedStringArray()
	for event in InputMap.action_get_events(action):
		var code: String = _input_code(event)
		if not code.is_empty() and get_code_device(code) == device:
			codes.append(code)
	return codes


## Every input of the action on the device, as "LT / LB"
func get_binding_label(action: StringName, device: Device) -> String:
	var labels: PackedStringArray = PackedStringArray()
	for code in get_action_codes(action, device):
		labels.append(get_code_label(code))
	return " / ".join(labels) if not labels.is_empty() else "---"


func get_primary_label(action: StringName, device: Device) -> String:
	var codes: PackedStringArray = get_action_codes(action, device)
	return get_code_label(codes[0]) if not codes.is_empty() else "---"


func can_rebind(action: StringName, device: Device) -> bool:
	if action not in REBINDABLE_ACTIONS:
		return false
	return device != Device.GAMEPAD or action not in PAD_FIXED_ACTIONS


## Replaces the action's primary input on the event's device. Another action
## that already uses the input gets this action's old one, so nothing is left
## unbound. An input held by a fixed binding can't be taken.
func rebind(action: StringName, event: InputEvent) -> void:
	var code: String = _input_code(event)
	if code.is_empty():
		return
	var device: Device = get_code_device(code)
	if not can_rebind(action, device):
		return
	var codes: PackedStringArray = get_action_codes(action, device)
	var old_code: String = codes[0] if not codes.is_empty() else ""
	if code == old_code:
		return
	for other in REBINDABLE_ACTIONS:
		if other != action and not can_rebind(other, device) and code in get_action_codes(other, device):
			return
	for other in REBINDABLE_ACTIONS:
		if other == action or _shares_binding(action, other):
			continue
		var other_codes: PackedStringArray = get_action_codes(other, device)
		var index: int = other_codes.find(code)
		if index < 0:
			continue
		if index == 0 and not old_code.is_empty():
			other_codes[0] = old_code
		else:
			other_codes.remove_at(index)
		_set_action_codes(other, device, other_codes)
	if codes.is_empty():
		codes.append(code)
	else:
		codes[0] = code
	_set_action_codes(action, device, codes)
	bindings_changed.emit()
	save_settings()


func reset_bindings() -> void:
	for action in _default_codes:
		for device in DEVICES:
			_set_action_codes(action, device, _default_codes[action])
	bindings_changed.emit()
	save_settings()


static func get_code_device(code: String) -> Device:
	if code.begins_with("button:") or code.begins_with("axis:"):
		return Device.GAMEPAD
	return Device.KEYBOARD_MOUSE


## Keys are named after the player's keyboard layout
static func get_code_label(code: String) -> String:
	var parts: PackedStringArray = code.split(":")
	if parts.size() < 2:
		return "---"
	var index: int = parts[1].to_int()
	match parts[0]:
		"key":
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(index as Key)).to_upper()
		"mouse":
			return MOUSE_BUTTON_NAMES.get(index, "MOUSE %d" % index)
		"button":
			return JOY_BUTTON_NAMES.get(index, "BUTTON %d" % index)
		"axis":
			if parts.size() == 3:
				return _get_axis_label(index as JoyAxis, parts[2].to_int() < 0)
	return "---"


static func _get_axis_label(axis: JoyAxis, negative: bool) -> String:
	match axis:
		JOY_AXIS_LEFT_X:
			return "LS LEFT" if negative else "LS RIGHT"
		JOY_AXIS_LEFT_Y:
			return "LS UP" if negative else "LS DOWN"
		JOY_AXIS_RIGHT_X:
			return "RS LEFT" if negative else "RS RIGHT"
		JOY_AXIS_RIGHT_Y:
			return "RS UP" if negative else "RS DOWN"
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
	return "AXIS %d" % axis


func _shares_binding(action: StringName, other: StringName) -> bool:
	for pair in SHARED_BINDINGS:
		if action in pair and other in pair:
			return true
	return false


## Codes from another device are skipped, so a list with every device can be passed
func _set_action_codes(action: StringName, device: Device, codes: PackedStringArray) -> void:
	for event in InputMap.action_get_events(action):
		var code: String = _input_code(event)
		if not code.is_empty() and get_code_device(code) == device:
			InputMap.action_erase_event(action, event)
	var added: PackedStringArray = PackedStringArray()
	for code in codes:
		if code in added or get_code_device(code) != device:
			continue
		var event: InputEvent = _event_from_code(code)
		if event == null:
			continue
		added.append(code)
		InputMap.action_add_event(action, event)


## "key:<physical keycode>", "mouse:<button>", "button:<joypad button>" or
## "axis:<joypad axis>:<-1 or 1>", empty for anything that can't be bound.
## Saved as text, the settings file can't hold InputEvents
static func _input_code(event: InputEvent) -> String:
	var key: InputEventKey = event as InputEventKey
	if key:
		var keycode: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "key:%d" % keycode if keycode != KEY_NONE else ""
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse:
		return "mouse:%d" % mouse.button_index if MOUSE_BUTTON_NAMES.has(mouse.button_index) else ""
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button:
		return "button:%d" % button.button_index
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion and not is_zero_approx(motion.axis_value):
		return "axis:%d:%d" % [motion.axis, 1 if motion.axis_value > 0.0 else -1]
	return ""


static func _event_from_code(code: String) -> InputEvent:
	var parts: PackedStringArray = code.split(":")
	if parts.size() < 2:
		return null
	var index: int = parts[1].to_int()
	var event: InputEvent = null
	match parts[0]:
		"key":
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = index as Key
			event = key
		"mouse":
			var mouse: InputEventMouseButton = InputEventMouseButton.new()
			mouse.button_index = index as MouseButton
			event = mouse
		"button":
			var button: InputEventJoypadButton = InputEventJoypadButton.new()
			button.button_index = index as JoyButton
			event = button
		"axis":
			if parts.size() == 3:
				var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
				motion.axis = index as JoyAxis
				motion.axis_value = -1.0 if parts[2].to_int() < 0 else 1.0
				event = motion
	if event:
		## Any keyboard or pad, a new event only listens to the first one
		event.device = -1
	return event


# Persistence

## Values from the project, before anything the player saved is applied
func _cache_defaults() -> void:
	for bus in VOLUME_BUSES:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0:
			_bus_base_db[bus] = AudioServer.get_bus_volume_db(index)
	for action in REBINDABLE_ACTIONS:
		if InputMap.has_action(action):
			_default_codes[action] = get_action_codes(action, Device.KEYBOARD_MOUSE) \
				+ get_action_codes(action, Device.GAMEPAD)
	var project_mode: int = ProjectSettings.get_setting("display/window/size/mode", DisplayServer.WINDOW_MODE_WINDOWED)
	window_mode = (project_mode if project_mode in WINDOW_MODES else DisplayServer.WINDOW_MODE_WINDOWED) as DisplayServer.WindowMode
	var width: int = ProjectSettings.get_setting("display/window/size/window_width_override", 0)
	var height: int = ProjectSettings.get_setting("display/window/size/window_height_override", 0)
	if width <= 0:
		width = ProjectSettings.get_setting("display/window/size/viewport_width", 1920)
	if height <= 0:
		height = ProjectSettings.get_setting("display/window/size/viewport_height", 1080)
	resolution = Vector2i(width, height)
	vsync = ProjectSettings.get_setting("display/window/vsync/vsync_mode", 1) != DisplayServer.VSYNC_DISABLED


## Assigns the fields directly, going through the setters would save back the
## very values we just read
func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	if int(config.get_value("controls", "bindings_version", 0)) == BINDINGS_VERSION:
		_load_bindings(config)

	for bus in VOLUME_BUSES:
		volumes[bus] = clampf(float(config.get_value("audio", bus, 1.0)), 0.0, 1.0)
		_apply_volume(bus)

	## Without a saved display section the window stays as the project opened it
	if not config.has_section("display"):
		return
	var mode: int = config.get_value("display", "window_mode", window_mode)
	if mode in WINDOW_MODES:
		window_mode = mode as DisplayServer.WindowMode
	var size: Variant = config.get_value("display", "resolution", resolution)
	if size is Vector2i:
		resolution = size
	vsync = bool(config.get_value("display", "vsync", vsync))
	_apply_display()


func _load_bindings(config: ConfigFile) -> void:
	for device in DEVICES:
		var section: String = BINDING_SECTIONS[device]
		for action in REBINDABLE_ACTIONS:
			if not can_rebind(action, device) or not config.has_section_key(section, action):
				continue
			var codes: Variant = config.get_value(section, action)
			if codes is PackedStringArray or codes is Array:
				_set_action_codes(action, device, PackedStringArray(codes))


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	## Keep whatever other sections are already there
	config.load(SETTINGS_PATH)
	## Left by the control type option, the input used now picks the controls
	if config.has_section_key("controls", "scheme"):
		config.erase_section_key("controls", "scheme")
	config.set_value("controls", "bindings_version", BINDINGS_VERSION)
	for device in DEVICES:
		for action in REBINDABLE_ACTIONS:
			config.set_value(BINDING_SECTIONS[device], action, get_action_codes(action, device))
	for bus in VOLUME_BUSES:
		config.set_value("audio", bus, get_volume(bus))
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "resolution", resolution)
	config.set_value("display", "vsync", vsync)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_error("GameSettings.save_settings: could not write %s (%d)" % [SETTINGS_PATH, error])
