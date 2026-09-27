extends Node
## Captures any scene to a PNG (windowed run, not headless):
##   Godot --path D:\DynMagic res://tools/scene_capture.tscn -- --scene res://scenes/ui/main_menu.tscn --out menu
## Output: res://build/gauntlet/<out>.png at 1920x1080.


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = args[args.find("--scene") + 1] if args.has("--scene") else "res://scenes/ui/main_menu.tscn"
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "scene"
	add_child((load(scene_path) as PackedScene).instantiate())
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/gauntlet"))
	get_viewport().get_texture().get_image().save_png("res://build/gauntlet/%s.png" % out)
	get_tree().quit()
