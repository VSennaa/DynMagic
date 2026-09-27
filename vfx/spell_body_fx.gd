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
	# Plain alpha blend, not the additive variant: additive glyphs barely tint a bright
	# background (arena sky/sunlit stone, glow bloom) and the flame nearly disappears --
	# this is one of the "sometimes even invisible" reports. The particle trail
	# (ElementFx.trail, added separately in projectile.gd) stays additive for its glow accent.
	mat.shader = GLYPH_SHADER
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
	# Bigger and lower-poly than before: at the old 0.17 m radius (0.093 m on a Bolt) the
	# crackling plasma texture never resolved at gameplay distance/speed, so the whole body
	# read as nothing but "a light" -- the actual user complaint. The low segment count also
	# breaks up the perfectly round silhouette a little instead of a smooth ball.
	sphere.radius = 0.26 * body_scale
	sphere.height = 0.52 * body_scale
	sphere.radial_segments = 7
	sphere.rings = 4
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
		jitter.radius = 0.3 * body_scale
		jitter.seed_offset = float(i) * 2.17
		var arc: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.34, 0.34) * body_scale
		var amat: ShaderMaterial = ShaderMaterial.new()
		# Plain alpha blend (see _fire_body): the additive arcs washed out to nothing against
		# a bright background instead of reading as crackling lightning.
		amat.shader = GLYPH_SHADER
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
