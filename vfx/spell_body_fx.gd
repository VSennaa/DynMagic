class_name SpellBodyFx
extends RefCounted
## Element-specific stylized bodies for spell projectiles (gauntlet spell-body pass):
## replaces the SphereMesh/BoxMesh/CylinderMesh placeholders on Bolt/Orb/Seed with a
## small look per element, reusing shaders/particle_glyph.gdshader (already reused by
## vfx/element_fx.gd for the particle trail) plus the new shaders/spell_*.gdshader set.
## Fire = billboarded flame-glyph comet core (the short trail is the existing particle
## trail added by projectile.gd). Frost = faceted low-poly crystal, rotating, bright rim.
## Storm = crackling plasma orb with jittering lightning-arc quads. Wind = spinning
## translucent twisted ribbons.

const GLYPH_SHADER: Shader = preload("res://shaders/particle_glyph.gdshader")
const CRYSTAL_SHADER: Shader = preload("res://shaders/spell_crystal.gdshader")
const PLASMA_SHADER: Shader = preload("res://shaders/spell_plasma.gdshader")
const VORTEX_SHADER: Shader = preload("res://shaders/spell_vortex.gdshader")

static var _additive_glyph_cache: Shader = null


## Element index shared by the ground/wall shaders: 0 fire, 1 frost, 2 storm, 3 wind.
static func element_index(element: StringName) -> int:
	match element:
		&"frost":
			return 1
		&"storm":
			return 2
		&"wind":
			return 3
		_:
			return 0


static func build_projectile_body(element: StringName, color: Color, body_scale: float = 1.0) -> Node3D:
	match element:
		&"frost":
			return _frost_body(color, body_scale)
		&"storm":
			return _storm_body(color, body_scale)
		&"wind":
			return _wind_body(color, body_scale)
		_:
			return _fire_body(color, body_scale)


static func _fire_body(color: Color, body_scale: float) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "FireBody"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.5, 0.75) * body_scale
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _additive_glyph_shader()
	mat.set_shader_parameter(&"shape", 0)
	mat.set_shader_parameter(&"core_color", color.lightened(0.55))
	mat.set_shader_parameter(&"edge_color", color)
	mat.set_shader_parameter(&"base_alpha", 1.0)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = quad
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)
	return root


static func _frost_body(color: Color, body_scale: float) -> Node3D:
	var root: SpellSpin = SpellSpin.new()
	root.name = "FrostBody"
	root.speed = Vector3(1.4, 2.6, 0.9)
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.32, 0.62, 0.32) * body_scale
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = CRYSTAL_SHADER
	mat.set_shader_parameter(&"core_color", color.darkened(0.1))
	mat.set_shader_parameter(&"edge_color", color.lightened(0.75))
	mat.set_shader_parameter(&"rim_power", 3.0)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = prism
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)
	return root


static func _storm_body(color: Color, body_scale: float) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "StormBody"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.17 * body_scale
	sphere.height = 0.34 * body_scale
	sphere.radial_segments = 10
	sphere.rings = 6
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = PLASMA_SHADER
	mat.set_shader_parameter(&"core_color", color.lightened(0.6))
	mat.set_shader_parameter(&"edge_color", color)
	var core: MeshInstance3D = MeshInstance3D.new()
	core.mesh = sphere
	core.material_override = mat
	root.add_child(core)
	for i: int in 3:
		var jitter: SpellJitter = SpellJitter.new()
		jitter.radius = 0.24 * body_scale
		jitter.seed_offset = float(i) * 2.17
		var arc: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.3, 0.3) * body_scale
		var amat: ShaderMaterial = ShaderMaterial.new()
		amat.shader = _additive_glyph_shader()
		amat.set_shader_parameter(&"shape", 2)
		amat.set_shader_parameter(&"core_color", Color.WHITE)
		amat.set_shader_parameter(&"edge_color", color.lightened(0.3))
		amat.set_shader_parameter(&"base_alpha", 1.0)
		arc.mesh = quad
		arc.material_override = amat
		jitter.add_child(arc)
		root.add_child(jitter)
	return root


static func _wind_body(color: Color, body_scale: float) -> Node3D:
	var root: SpellSpin = SpellSpin.new()
	root.name = "WindBody"
	root.speed = Vector3(0.0, 6.0, 0.0)
	for i: int in 4:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.42, 0.8) * body_scale
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = VORTEX_SHADER
		mat.set_shader_parameter(&"core_color", Color(color.r, color.g, color.b, 0.75))
		var edge: Color = color.lightened(0.7)
		mat.set_shader_parameter(&"edge_color", Color(edge.r, edge.g, edge.b, 0.95))
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.mesh = quad
		mesh_instance.material_override = mat
		mesh_instance.rotation.y = deg_to_rad(45.0 * i)
		root.add_child(mesh_instance)
	return root


## Additive variant of particle_glyph.gdshader (same trick as ElementFx._additive_shader):
## ShaderMaterial has no runtime blend mode, so rebuild the source with blend_add.
static func _additive_glyph_shader() -> Shader:
	if _additive_glyph_cache == null:
		_additive_glyph_cache = Shader.new()
		_additive_glyph_cache.code = GLYPH_SHADER.code.replace("blend_mix", "blend_add")
	return _additive_glyph_cache
