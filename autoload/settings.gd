## Loads, applies and persists user settings (user://settings.cfg). See docs/specs/06-ui-settings.md.
## M1: in-memory defaults only. Persistence and the settings screens arrive in M6.
extends Node

signal changed(key: StringName)

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
