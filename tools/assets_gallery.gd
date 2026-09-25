extends Control
## Render all wrappers with the game's toon and outline. Optional --capture writes a PNG.


func _ready() -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	add_child(grid)
	var entries: Array[String] = ["mage", "fp_arms:OpenPalm", "fp_arms:Fist", "fp_arms:PalmDown", "fp_arms:Cast", "cover_low", "cover_high", "cover_bar", "pillar", "banner", "brazier", "spawn_arch", "arcane_core"]
	for entry: String in entries:
		var parts: PackedStringArray = entry.split(":")
		var asset: String = parts[0]
		var panel: VBoxContainer = VBoxContainer.new()
		grid.add_child(panel)
		var label: Label = Label.new()
		label.text = entry
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(label)
		var container: SubViewportContainer = SubViewportContainer.new()
		container.custom_minimum_size = Vector2(384, 292)
		panel.add_child(container)
		var view: SubViewport = SubViewport.new()
		view.size = Vector2i(384, 292)
		view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(view)
		var model: Node3D = (load("res://scenes/assets/%s.tscn" % asset) as PackedScene).instantiate() as Node3D
		if parts.size() > 1:
			model.set("pose", parts[1])
		view.add_child(model)
		var bounds: AABB
		var first: bool = true
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			if not mesh.visible:
				continue
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var env: WorldEnvironment = WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(.055, .075, .105)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(.6, .65, .8)
		env.environment.ambient_light_energy = .45
		view.add_child(env)
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, -30, 0)
		view.add_child(light)
		var camera: Camera3D = Camera3D.new()
		view.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z)) * 1.5
		camera.position = bounds.get_center() + Vector3(2.4, 1.8, -4) * maxf(bounds.size.length(), 1.0)
		camera.look_at(bounds.get_center())
		Toon.add_outline(camera)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--capture"):
		for frame: int in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = args[args.find("--capture") + 1]
		var result: Error = get_viewport().get_texture().get_image().save_png(path)
		print("GALLERY_CAPTURE ", result)
		get_tree().quit(int(result))
