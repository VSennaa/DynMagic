extends Node
## Camera-local viewmodel composited over the world, below the HUD.
## An isolated World3D has no arena depth, so walls cannot clip the arms.
const ARMS_LAYER: int = 1 << 19
const CAST_FLASH: float = 0.12
## M11: staff swing duration (sideways sweep).
const MELEE_SWING: float = 0.28
## Single grip anchored at the lower right; its own FOV keeps gameplay aim stable.
const REST_OFFSET: Vector3 = Vector3(0.29, -0.23, -0.64)
const ARMS_SCALE: float = 0.56
var player: Player
var source_camera: Camera3D
var view: SubViewport
var camera: Camera3D
var arms: Node3D
var staff: Node3D
var element: StringName = &""
var current_pose: StringName = &"idle"
var flash_light: OmniLight3D
var mirrored_shader: Shader
var overlay: CanvasLayer
var _flash: float = 0.0
var _swing: float = 0.0
var _time: float = 0.0


func setup(owner_player: Player, owner_camera: Camera3D) -> void:
	player = owner_player
	source_camera = owner_camera
	overlay = CanvasLayer.new()
	overlay.layer = -1
	add_child(overlay)
	var container: SubViewportContainer = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(container)
	view = SubViewport.new()
	view.name = "ArmsViewport"
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.handle_input_locally = false
	container.add_child(view)
	camera = Camera3D.new()
	camera.cull_mask = ARMS_LAYER
	camera.near = 0.01
	camera.far = 3.0
	camera.current = true
	view.add_child(camera)
	arms = Node3D.new()
	arms.name = "StaffGrip"
	camera.add_child(arms)
	var hand: Node3D = preload("res://scenes/assets/fp_staff_arm.tscn").instantiate() as Node3D
	arms.add_child(hand)
	# Negative X scale reverses winding; inverse-transpose normal transform is
	# supplied by Godot. Disable culling only for this isolated viewmodel.
	mirrored_shader = Shader.new()
	mirrored_shader.code = Toon.TOON_SHADER.code.replace("render_mode diffuse_toon, specular_toon;", "render_mode diffuse_toon, specular_toon, cull_disabled;")
	_prepare_meshes(hand)
	flash_light = OmniLight3D.new()
	flash_light.position = Vector3(0, .76, 0)
	flash_light.omni_range = 1.5
	flash_light.light_cull_mask = ARMS_LAYER
	arms.add_child(flash_light)
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed(&"left_handed")
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.light_cull_mask = ARMS_LAYER
	light.rotation_degrees = Vector3(-35, -30, 0)
	view.add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.65, .7, .85)
	environment.environment.ambient_light_energy = .4
	view.add_child(environment)
	player.spell_cast.connect(_on_cast)
	player.melee_swung.connect(func() -> void: _swing = MELEE_SWING)
	player.stats.died.connect(_on_died)
	_process(0.0)


func _on_cast(_spell: ResolvedSpell) -> void:
	_flash = CAST_FLASH


func _on_died() -> void:
	_flash = 0.0


func _process(delta: float) -> void:
	if arms == null:
		return
	_time += delta
	_flash = maxf(0.0, _flash - delta)
	_swing = maxf(0.0, _swing - delta)
	camera.fov = Settings.viewmodel_fov
	camera.keep_aspect = source_camera.keep_aspect
	view.msaa_3d = player.get_viewport().msaa_3d
	overlay.visible = player.is_local and source_camera.current and not player.stats.is_dead and player.stats.hp > 0.0
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if overlay.visible else SubViewport.UPDATE_DISABLED
	_update_staff()
	current_pose = &"idle"
	if _flash > 0.0:
		current_pose = &"cast"
	elif player.composer.state == SpellComposer.State.AIMING:
		current_pose = &"aim"
	elif player.composer.state == SpellComposer.State.SLOT_EFFECT:
		current_pose = &"compose"
	var raised: float = 1.0 if current_pose == &"compose" else 0.0
	var aim: float = 1.0 if current_pose in [&"aim", &"cast"] else 0.0
	var thrust: float = sin((_flash / CAST_FLASH) * PI) if _flash > 0.0 else 0.0
	var side: float = -1.0 if Settings.left_handed else 1.0
	arms.position = REST_OFFSET * Vector3(side, 1, 1) + Vector3(0, raised * .045 + sin(_time * 2.0) * .004, -aim * .035 - thrust * .12)
	arms.rotation = Vector3(-.22 - aim * .70 + raised * .12, 0, -.12 * side)
	if _swing > 0.0:
		# Sweep from the grip side across the screen and back.
		var t: float = 1.0 - _swing / MELEE_SWING
		var arc: float = sin(t * PI)
		arms.position += Vector3(-0.22 * side * arc, 0.05 * arc, -0.12 * arc)
		arms.rotation += Vector3(-0.3 * arc, 0.9 * side * arc, 0.6 * side * arc)
	flash_light.light_energy = 2.0 * _flash / CAST_FLASH


func _on_settings_changed(key: StringName) -> void:
	if key == &"left_handed":
		arms.scale = Vector3(-1 if Settings.left_handed else 1, 1, 1) * ARMS_SCALE
		arms.position.x = REST_OFFSET.x * (-1 if Settings.left_handed else 1)
	if key == &"viewmodel_fov":
		camera.fov = Settings.viewmodel_fov


func _prepare_meshes(root: Node3D) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		mesh.layers = ARMS_LAYER
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for index: int in mesh.mesh.get_surface_count():
			var mat: ShaderMaterial = mesh.get_surface_override_material(index).duplicate() as ShaderMaterial
			mat.shader = mirrored_shader
			mesh.set_surface_override_material(index, mat)


func _update_staff() -> void:
	var selected: StringName = player.composer.element_id
	if selected not in [&"fire", &"frost", &"storm", &"wind"]:
		selected = &"fire"
	if selected == element:
		return
	element = selected
	if staff != null:
		staff.free()
	staff = (load("res://scenes/assets/staff_%s.tscn" % element) as PackedScene).instantiate() as Node3D
	arms.add_child(staff)
	_prepare_meshes(staff)
	flash_light.light_color = {&"fire": Color("FF5A1F"), &"frost": Color("6FD3FF"), &"storm": Color("C98BFF"), &"wind": Color("7CF2B0")}[element]
