extends Node3D
## Gauntlet spell-body capture: spawns every spell body (Bolt, Orb, Seed, Wall, Guard
## shell, Zone, ExplosionFx) for the four elements, one spell type per row, four element
## columns, on a flat mid-gray floor. Run windowed (not headless):
##   Godot --path D:\DynMagic res://tools/spell_capture.tscn -- --tag t1
## Output: res://build/gauntlet/<tag>_spells.png.

const ELEMENT_IDS: Array[StringName] = [&"fire", &"frost", &"storm", &"wind"]
const ELEMENT_COLORS: Array[Color] = [
	Color("ff5a1f"), Color("6fd3ff"), Color("c98bff"), Color("7cf2b0"),
]
const BACKGROUND: Color = Color("5a5f6b")
const FLOOR: Color = Color("4a4f5b")
const COL_SPACING: float = 4.2
const ROW_SPACING: float = 3.6

const BOLT_SCENE: PackedScene = preload("res://scenes/spells/bolt.tscn")
const ORB_SCENE: PackedScene = preload("res://scenes/spells/orb.tscn")
const SEED_SCENE: PackedScene = preload("res://scenes/spells/seed.tscn")
const WALL_SCENE: PackedScene = preload("res://scenes/spells/wall.tscn")
const SELF_SCENE: PackedScene = preload("res://scenes/spells/self_spell.tscn")
const ZONE_SCENE: PackedScene = preload("res://scenes/spells/zone.tscn")
const EXPLOSION_SCENE: PackedScene = preload("res://scenes/spells/explosion_fx.tscn")

## Near (small z, bottom of frame) to far (large z, top of frame): shortest geometry first
## so a tall row never occludes a row spawned behind it.
const ROW_NAMES: Array[String] = ["Zone", "Bolt", "Orb", "Seed", "Guard", "Blast", "Wall"]


func _ready() -> void:
	get_window().size = Vector2i(1920, 1440)
	var tag: String = _tag()
	_setup_scene()

	for row: int in ROW_NAMES.size():
		for col: int in ELEMENT_IDS.size():
			_spawn(row, col, ELEMENT_IDS[col], ELEMENT_COLORS[col])

	# Let TIME-driven shader animation (flame flicker, plasma crackle, ring sweep) settle
	# into a representative mid-animation frame before capturing.
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw

	var dir: String = ProjectSettings.globalize_path("res://build/gauntlet")
	DirAccess.make_dir_recursive_absolute(dir)
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://build/gauntlet/%s_spells.png" % tag)
	print("[spell_capture] saved %s_spells.png" % tag)
	get_tree().quit()


func _spawn(row: int, col: int, element: StringName, color: Color) -> void:
	var pos: Vector3 = Vector3(_x(col), 0.0, _z(row))
	var spell: ResolvedSpell = _make_spell(row, element, color)
	match ROW_NAMES[row]:
		"Bolt":
			_spawn_projectile(BOLT_SCENE, spell, pos)
		"Orb":
			_spawn_projectile(ORB_SCENE, spell, pos)
		"Seed":
			_spawn_projectile(SEED_SCENE, spell, pos)
		"Wall":
			_spawn_wall(spell, pos)
		"Guard":
			_spawn_self(spell, pos)
		"Zone":
			_spawn_zone(spell, pos)
		"Blast":
			_spawn_explosion(spell, color, element, pos)


func _spawn_projectile(scene: PackedScene, spell: ResolvedSpell, pos: Vector3) -> void:
	var node: Projectile = scene.instantiate() as Projectile
	node.setup(spell, null, pos + Vector3.UP * 1.2, Vector3.FORWARD, pos)
	add_child(node)
	# Freeze flight/expiry so the body stays put for the screenshot; shader TIME still animates.
	node.set_physics_process(false)


func _spawn_wall(spell: ResolvedSpell, pos: Vector3) -> void:
	var wall: Wall = WALL_SCENE.instantiate() as Wall
	wall.setup(spell, null, pos + Vector3.UP * 0.0, Vector3.FORWARD, pos)
	add_child(wall)
	wall.set_process(false)


func _spawn_self(spell: ResolvedSpell, pos: Vector3) -> void:
	var self_spell: SelfSpell = SELF_SCENE.instantiate() as SelfSpell
	self_spell.setup(spell, null, pos + Vector3.UP * 1.1, Vector3.FORWARD, pos)
	add_child(self_spell)
	self_spell.set_process(false)
	self_spell.set_physics_process(false)


func _spawn_zone(spell: ResolvedSpell, pos: Vector3) -> void:
	var zone: Zone = ZONE_SCENE.instantiate() as Zone
	zone.setup(spell, null, pos, Vector3.FORWARD, pos)
	add_child(zone)


func _spawn_explosion(spell: ResolvedSpell, color: Color, element: StringName, pos: Vector3) -> void:
	var fx: ExplosionFx = EXPLOSION_SCENE.instantiate() as ExplosionFx
	fx.configure(float(spell.param(&"radius", 1.8)), color, element)
	add_child(fx)
	fx.global_position = pos


func _make_spell(row: int, element: StringName, color: Color) -> ResolvedSpell:
	var spell: ResolvedSpell = ResolvedSpell.new()
	spell.element = element
	spell.form = &"projectile"
	spell.effect = &"direct"
	spell.key = &"capture"
	spell.display_name = "Capture"
	spell.cast_mode = SpellBase.CastMode.QUICK
	spell.color = color
	spell.base_damage = 10.0
	spell.damage = 10.0
	spell.mana_cost = 0.0
	spell.cooldown = 0.0
	spell.status_id = &""
	spell.status_duration = 0.0
	spell.status_params = {}
	match ROW_NAMES[row]:
		"Bolt", "Orb", "Seed":
			spell.params = {"speed": 6.0, "lifetime": 30.0, "max_range": 9999.0, "gravity": 0.0, "radius": 2.0}
		"Wall":
			spell.form = &"area"
			spell.effect = &"lingering"
			spell.params = {"width": 3.0, "height": 2.2, "duration": 30.0, "hp": 9999.0}
		"Guard":
			spell.form = &"self"
			spell.effect = &"direct"
			spell.params = {"duration": 30.0, "shield": 30.0}
		"Zone":
			spell.params = {"zone_radius": 1.4, "zone_duration": 30.0, "zone_dps": 0.0}
		"Blast":
			spell.params = {"radius": 1.6}
	return spell


func _x(col: int) -> float:
	return (float(col) - float(ELEMENT_IDS.size() - 1) * 0.5) * COL_SPACING


func _z(row: int) -> float:
	return float(row) * ROW_SPACING


func _tag() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var idx: int = args.find("--tag")
	if idx != -1 and idx + 1 < args.size():
		return args[idx + 1]
	return "t0"


func _setup_scene() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	env.environment = environment
	add_child(env)

	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(30, ROW_SPACING * (ROW_NAMES.size() + 1))
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0.0, 0.0, _z(ROW_NAMES.size() - 1) * 0.5)
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mat.albedo_color = FLOOR
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)

	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 8.5, -7.0)
	camera.fov = 60.0
	add_child(camera)
	camera.make_current()
	camera.look_at(Vector3(0.0, 1.0, _z(ROW_NAMES.size() - 1) * 0.5), Vector3.UP)
