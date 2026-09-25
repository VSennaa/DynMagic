@tool
class_name VideoSettings
extends RefCounted
## Pure persisted video options; Settings owns their runtime application.

const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
var resolution: Vector2i = Vector2i(1920, 1080)
var render_scale: float = 1.0
## Low / medium / high shadow atlas and filtering quality.
var shadow_quality: int = 2
## Off / FXAA / MSAA 2x / MSAA 4x.
var antialiasing: int = 0


func normalize() -> void:
	if not RESOLUTIONS.has(resolution):
		resolution = RESOLUTIONS[0]
	render_scale = clampf(render_scale, 0.5, 1.0) if is_finite(render_scale) else 1.0
	shadow_quality = clampi(shadow_quality, 0, 2)
	antialiasing = clampi(antialiasing, 0, 3)


func read_config(cfg: ConfigFile) -> void:
	resolution = cfg.get_value("video", "resolution", resolution)
	render_scale = cfg.get_value("video", "render_scale", render_scale)
	shadow_quality = cfg.get_value("video", "shadow_quality", shadow_quality)
	antialiasing = cfg.get_value("video", "antialiasing", antialiasing)
	normalize()


func write_config(cfg: ConfigFile) -> void:
	normalize()
	cfg.set_value("video", "resolution", resolution)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "shadow_quality", shadow_quality)
	cfg.set_value("video", "antialiasing", antialiasing)
