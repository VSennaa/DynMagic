## Loads, applies and persists user settings (user://settings.cfg). See docs/specs/06-ui-settings.md.
extends Node

signal changed(key: StringName)

const PATH: String = "user://settings.cfg"

var fov: float = 95.0:
	set(value):
		fov = clampf(value, 80.0, 110.0)
		changed.emit(&"fov")

## Radians of camera rotation per pixel of mouse motion.
var mouse_sensitivity: float = 0.0025:
	set(value):
		mouse_sensitivity = maxf(value, 0.0001)
		changed.emit(&"mouse_sensitivity")

var invert_y: bool = false:
	set(value):
		invert_y = value
		changed.emit(&"invert_y")

var player_name: String = "Mago":
	set(value):
		player_name = value.strip_edges().left(24) if value.strip_edges() != "" else "Mago"
		Net.player_name = player_name
		changed.emit(&"player_name")

var fullscreen: bool = false:
	set(value):
		fullscreen = value
		_apply_window()
		changed.emit(&"fullscreen")

var vsync: bool = true:
	set(value):
		vsync = value
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
		changed.emit(&"vsync")

## 0 = unlimited.
var max_fps: int = 144:
	set(value):
		max_fps = value
		Engine.max_fps = value
		changed.emit(&"max_fps")

var show_damage_numbers: bool = true:
	set(value):
		show_damage_numbers = value
		changed.emit(&"show_damage_numbers")

## 0 default, 1 deuteranopia, 2 protanopia, 3 tritanopia (spec 06 §3 accessibility).
var colorblind_mode: int = 0:
	set(value):
		colorblind_mode = clampi(value, 0, 3)
		SpellDB.apply_palette(colorblind_mode)
		changed.emit(&"colorblind_mode")

var show_fps: bool = false:
	set(value):
		show_fps = value
		changed.emit(&"show_fps")

var sound_captions: bool = false:
	set(value):
		sound_captions = value
		changed.emit(&"sound_captions")

## Bus name -> linear volume 0..1.
var volumes: Dictionary[String, float] = {"Master": 1.0, "Music": 0.8, "SFX": 1.0, "UI": 1.0}


func _ready() -> void:
	load_settings()


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus], 0.0001)))
	changed.emit(&"volume")


func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		_apply_all()
		return
	fov = cfg.get_value("video", "fov", fov)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	vsync = cfg.get_value("video", "vsync", vsync)
	max_fps = cfg.get_value("video", "max_fps", max_fps)
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	invert_y = cfg.get_value("controls", "invert_y", invert_y)
	player_name = cfg.get_value("game", "player_name", player_name)
	show_damage_numbers = cfg.get_value("game", "show_damage_numbers", show_damage_numbers)
	colorblind_mode = cfg.get_value("accessibility", "colorblind_mode", colorblind_mode)
	sound_captions = cfg.get_value("accessibility", "sound_captions", sound_captions)
	show_fps = cfg.get_value("game", "show_fps", show_fps)
	for bus: String in volumes.keys():
		volumes[bus] = cfg.get_value("audio", bus, volumes[bus])
	_load_bindings(cfg)
	_apply_all()


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("game", "player_name", player_name)
	cfg.set_value("game", "show_damage_numbers", show_damage_numbers)
	cfg.set_value("accessibility", "colorblind_mode", colorblind_mode)
	cfg.set_value("accessibility", "sound_captions", sound_captions)
	cfg.set_value("game", "show_fps", show_fps)
	for bus: String in volumes:
		cfg.set_value("audio", bus, volumes[bus])
	for action: StringName in REMAPPABLE:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		if not events.is_empty():
			cfg.set_value("bindings", String(action), events[0])
	cfg.save(PATH)


## Actions the player may rebind (spec 06 §3).
const REMAPPABLE: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"crouch", &"sprint",
	&"slot_1", &"slot_2", &"slot_3", &"compose_cancel", &"cast", &"recast", &"scoreboard", &"net_overlay",
]


## Rebinds `action` to `event`. Returns the action that already used this event (the caller
## asks whether to swap), or empty when there was no conflict.
func rebind(action: StringName, event: InputEvent) -> StringName:
	var conflict: StringName = &""
	for other: StringName in REMAPPABLE:
		if other != action and InputMap.action_has_event(other, event):
			conflict = other
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	return conflict


func restore_default_bindings() -> void:
	InputMap.load_from_project_settings()


func _load_bindings(cfg: ConfigFile) -> void:
	for action: StringName in REMAPPABLE:
		var event: Variant = cfg.get_value("bindings", String(action), null)
		if event is InputEvent:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)


func _apply_all() -> void:
	_apply_window()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	Net.player_name = player_name
	for bus: String in volumes:
		set_volume(bus, volumes[bus])


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
