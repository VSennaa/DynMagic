extends Node
## Gauntlet captures (ROADMAP M13): fixed viewpoints of each arena saved as PNG so a blind
## critic can put them next to the reference. Run windowed (not headless):
##   Godot --path D:\DynMagic res://tools/gauntlet_capture.tscn -- --tag r0
## Output: res://build/gauntlet/<tag>_<arena>_<view>.png at the window size (use 1920x1080).

const ARENAS: Array[String] = ["a", "b", "c"]
const EYE: float = 1.7


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var tag: String = args[args.find("--tag") + 1] if args.has("--tag") else "r0"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/gauntlet"))
	for arena_id: String in ARENAS:
		var arena: Node3D = (load("res://scenes/arena/arena_%s.tscn" % arena_id) as PackedScene).instantiate() as Node3D
		add_child(arena)
		var camera: Camera3D = Camera3D.new()
		camera.fov = 90.0
		add_child(camera)
		camera.make_current()
		var south: Node3D = arena.find_child("SpawnSouth", true, false) as Node3D
		var north: Node3D = arena.find_child("SpawnNorth", true, false) as Node3D
		var from: Vector3 = south.global_position if south != null else Vector3(0, 0, 20)
		var to: Vector3 = north.global_position if north != null else Vector3(0, 0, -20)
		# 1. Spawn view: eye height, looking at the far spawn.
		camera.look_at_from_position(from + Vector3.UP * EYE, to + Vector3.UP * EYE)
		await _capture("%s_%s_spawn" % [tag, arena_id])
		# 2. Mid view: a third of the way in from the south spawn, looking diagonally across.
		var mid: Vector3 = from.lerp(to, 0.3) + Vector3(from.distance_to(to) * 0.12, EYE, 0)
		camera.look_at_from_position(mid, to.lerp(from, 0.3) + Vector3(-from.distance_to(to) * 0.12, EYE, 0))
		await _capture("%s_%s_mid" % [tag, arena_id])
		# 3. Overview: high diagonal, shows the layout.
		camera.fov = 70.0
		camera.look_at_from_position(Vector3(from.distance_to(to) * 0.55, from.distance_to(to) * 0.6, from.distance_to(to) * 0.55), Vector3.ZERO)
		await _capture("%s_%s_overview" % [tag, arena_id])
		arena.queue_free()
		camera.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _capture(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/gauntlet/%s.png" % name)
	print("[gauntlet] saved %s" % name)
