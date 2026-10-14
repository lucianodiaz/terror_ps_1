## Player preferences that survive between sessions.
## The autoload is named SettingsManager, the class_name is only here so other
## scripts can write GameSettings.ControlScheme.MODERN with static typing.
class_name GameSettings
extends Node

const SETTINGS_PATH : String = "user://settings.cfg"

## TANK: left/right turn the body, forward/backward walk where it looks.
## MODERN: the four keys are a direction on screen, the body turns to face it.
enum ControlScheme { TANK, MODERN }

signal control_scheme_changed(scheme: ControlScheme)

var control_scheme: ControlScheme = ControlScheme.TANK


func _ready() -> void:
	load_settings()


func set_control_scheme(scheme: ControlScheme) -> void:
	if control_scheme == scheme:
		return
	control_scheme = scheme
	control_scheme_changed.emit(control_scheme)
	save_settings()


func toggle_control_scheme() -> void:
	if control_scheme == ControlScheme.TANK:
		set_control_scheme(ControlScheme.MODERN)
	else:
		set_control_scheme(ControlScheme.TANK)


## Assigns the fields directly, going through the setters would save back the
## very values we just read
func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var scheme: int = config.get_value("controls", "scheme", ControlScheme.TANK)
	if scheme in ControlScheme.values():
		control_scheme = scheme as ControlScheme


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	## Keep whatever other sections are already there, audio volumes will live
	## next to this one
	config.load(SETTINGS_PATH)
	config.set_value("controls", "scheme", control_scheme)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_error("GameSettings.save_settings: could not write %s (%d)" % [SETTINGS_PATH, error])
