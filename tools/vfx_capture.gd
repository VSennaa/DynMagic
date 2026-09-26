extends Node3D
## Gauntlet VFX capture (docs/briefs/gauntlet-vfx.md): renders the four element
## particle glyphs (a trail and a burst per element) side by side on a flat
## mid-gray floor, then saves a PNG plus a grayscale copy. Run windowed (not
## headless):
##   Godot --path D:\DynMagic res://tools/vfx_capture.tscn -- --tag v1
## Output: res://build/gauntlet/<tag>_vfx.png and <tag>_vfx_gray.png.

const ELEMENT_IDS: Array[StringName] = [&"fire", &"frost", &"storm", &"wind"]
const ELEMENT_COLORS: Array[Color] = [
	Color("ff5a1f"), Color("6fd3ff"), Color("c98bff"), Color("7cf2b0"),
]
const BACKGROUND: Color = Color("5a5f6b")
const FLOOR: Color = Color("4a4f5b")
const SPACING: float = 4.0
const TRAIL_Y: float = 1.3
const BURST_RADIUS: float = 1.0


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	var tag: String = _tag()
	_setup_scene()

	for i: int in ELEMENT_IDS.size():
		var x: float = _x(i)
		var trail: GPUParticles3D = ElementFx.trail(ELEMENT_IDS[i], ELEMENT_COLORS[i])
		trail.position = Vector3(x - 0.7, TRAIL_Y, 0.0)
		add_child(trail)

	# Let the trails build up, then fire the one-shot bursts just before capturing
	# so every element (including the short-lived storm bolt) is still on screen.
	await get_tree().create_timer(0.9).timeout
	for i: int in ELEMENT_IDS.size():
		var x: float = _x(i)
		var burst: GPUParticles3D = ElementFx.burst(ELEMENT_IDS[i], ELEMENT_COLORS[i], BURST_RADIUS)
		burst.position = Vector3(x + 0.7, TRAIL_Y, 0.0)
		add_child(burst)
		burst.emitting = true
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw

	var dir: String = ProjectSettings.globalize_path("res://build/gauntlet")
	DirAccess.make_dir_recursive_absolute(dir)
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://build/gauntlet/%s_vfx.png" % tag)
	_grayscale(image).save_png("res://build/gauntlet/%s_vfx_gray.png" % tag)
	print("[vfx] saved %s_vfx.png and %s_vfx_gray.png" % [tag, tag])
	get_tree().quit()


func _x(i: int) -> float:
	return (float(i) - float(ELEMENT_IDS.size() - 1) * 0.5) * SPACING


func _tag() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var idx: int = args.find("--tag")
	if idx != -1 and idx + 1 < args.size():
		return args[idx + 1]
	return "v0"


func _setup_scene() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	env.environment = environment
	add_child(env)

	var floor: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor.mesh = plane
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mat.albedo_color = FLOOR
	floor.material_override = floor_mat
	add_child(floor)

	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 2.2, 6.5)
	camera.fov = 65.0
	add_child(camera)
	camera.make_current()
	camera.look_at(Vector3(0.0, 1.3, 0.0))


func _grayscale(image: Image) -> Image:
	image.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = image.get_data()
	var i: int = 0
	while i < data.size():
		var l: int = int(0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2])
		data[i] = l
		data[i + 1] = l
		data[i + 2] = l
		i += 4
	return Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, data)
