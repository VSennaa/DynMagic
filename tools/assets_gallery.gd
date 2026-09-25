extends Control
## Render all wrappers with the game's toon and outline. Optional --capture writes a PNG.


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--first-person"):
		_first_person_preview()
		await _capture()
		return
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	add_child(grid)
	var entries: Array[String] = ["mage", "fp_arms:OpenPalm", "fp_arms:Fist", "fp_arms:PalmDown", "fp_arms:Cast", "cover_low", "cover_high", "cover_bar", "pillar", "banner", "brazier", "spawn_arch", "arcane_core", "training_dummy", "staff_fire", "staff_frost", "staff_storm", "staff_wind", "fp_staff_arm"]
	if OS.get_cmdline_user_args().has("--staffs"):
		entries = ["staff_fire", "staff_frost", "staff_storm", "staff_wind", "fp_staff_arm"]
	if OS.get_cmdline_user_args().has("--animations") or OS.get_cmdline_user_args().has("--remote-staff"):
		entries = ["mage:idle", "mage:walk", "mage:cast", "mage:dash", "mage:death"]
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
		if parts.size() > 1 and asset == "fp_arms":
			model.set("pose", parts[1])
		if OS.get_cmdline_user_args().has("--remote-staff"):
			model.free()
			var remote: Player = preload("res://scenes/player/player.tscn").instantiate() as Player
			remote.is_local = false
			view.add_child(remote)
			remote.set_physics_process(false)
			remote.get_node("MageAnimation").set_process(false)
			model = remote.get_node("ThirdPersonModel") as Node3D
		else:
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
		camera.current = true
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z)) * 1.5
		camera.position = bounds.get_center() + Vector3(2.4, 1.8, -4) * maxf(bounds.size.length(), 1.0)
		camera.look_at(bounds.get_center())
		Toon.add_outline(camera)
		if parts.size() > 1 and asset == "mage":
			var animation: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			animation.play(parts[1])
			animation.seek(.9 if parts[1] == "death" else .25, true)
			animation.pause()
	await _capture()


func _first_person_preview() -> void:
	var player: Player = preload("res://scenes/player/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.frozen = true
	player.composer.validator = Callable()
	player.composer.set_process(false)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	Settings.left_handed = args.has("--left")
	if args.has("--element"):
		player.composer.element_id = StringName(args[args.find("--element") + 1])
	if args.has("--pose"):
		var pose: String = args[args.find("--pose") + 1]
		if pose in ["compose", "aim", "cast"]:
			player.composer.press_slot(0)
		if pose in ["aim", "cast"]:
			player.composer.press_slot(1)
		if pose == "cast":
			var arms: Node = player.get_node("Head/Camera3D/FirstPersonArms")
			arms._on_cast(null)
			arms._process(.06)
			arms.set_process(false)
	# Wall crosses the arms' normal depth range: the overlay must stay visible.
	var wall: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(4, 4, .05)
	wall.mesh = box
	wall.material_override = Toon.material(Color(.24, .30, .38))
	wall.position = Vector3(0, 1.6, -.25)
	add_child(wall)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -20, 0)
	add_child(light)
	var label: Label = Label.new()
	label.text = "First-person arms / wall at 0.25 m / isolated depth"
	label.position = Vector2(32, 32)
	add_child(label)


func _capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--capture"):
		for frame: int in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = args[args.find("--capture") + 1]
		var result: Error = get_viewport().get_texture().get_image().save_png(path)
		print("GALLERY_CAPTURE ", result)
		get_tree().quit(int(result))
