class_name ElementFx
extends RefCounted
## GPU particle looks per element (docs/specs/07-art-pipeline.md section 2 and
## docs/briefs/gauntlet-vfx.md). Each element is a distinct SDF glyph drawn by
## shaders/particle_glyph.gdshader on a billboarded quad, plus a soft additive
## core-glow layer for volume. Shapes + glow together stay under 2,000 live
## particles per spell (spec 07 acceptance).

const GLYPH_SHADER: Shader = preload("res://shaders/particle_glyph.gdshader")

## Additive variant of GLYPH_SHADER (blend_add) for Fire/Storm shapes and the
## glow layer. ShaderMaterial has no runtime blend mode, so we rebuild the same
## source with the single render_mode token swapped.
static var _additive_shader_cache: Shader = null

const LOOKS: Dictionary = {
	&"fire": {
		"shape": 0, "quad": Vector2(0.34, 0.34), "additive": true,
		"core": Color("ffe9a8"), "edge": Color("ff5a1f"), "alpha": 1.0,
		"glow_alpha": 0.35, "random_rot": 0.0,
		"gravity": Vector3(0, 2.5, 0), "spread": 25.0, "speed": 1.2, "lifetime": 0.5,
		"scale_curve": [Vector2(0.0, 0.4), Vector2(1.0, 1.0)], "turbulence": 0.0, "orbit": 0.0,
	},
	&"frost": {
		"shape": 1, "quad": Vector2(0.28, 0.5), "additive": false,
		"core": Color("6fd3ff"), "edge": Color("e8fbff"), "alpha": 1.0,
		"glow_alpha": 0.15, "random_rot": 1.0,
		"gravity": Vector3(0, -1.5, 0), "spread": 60.0, "speed": 0.6, "lifetime": 0.8,
		"scale_curve": [Vector2(0.0, 1.0), Vector2(1.0, 0.4)], "turbulence": 0.0, "orbit": 0.0,
	},
	&"storm": {
		"shape": 2, "quad": Vector2(0.22, 0.4), "additive": true,
		"core": Color("f3e6ff"), "edge": Color("c98bff"), "alpha": 1.0,
		"glow_alpha": 0.45, "random_rot": 0.0,
		"gravity": Vector3.ZERO, "spread": 180.0, "speed": 3.0, "lifetime": 0.15,
		"scale_curve": [Vector2(0.0, 0.0), Vector2(0.35, 1.0), Vector2(1.0, 0.0)], "turbulence": 4.0, "orbit": 0.0,
	},
	&"wind": {
		"shape": 3, "quad": Vector2(0.4, 0.34), "additive": false,
		"core": Color("7cf2b0"), "edge": Color("a9f8cd"), "alpha": 0.7,
		"glow_alpha": 0.25, "random_rot": 0.0,
		"gravity": Vector3.ZERO, "spread": 40.0, "speed": 2.0, "lifetime": 0.6,
		"scale_curve": [Vector2(0.0, 0.5), Vector2(1.0, 1.2)], "turbulence": 0.0, "orbit": 0.8,
	},
}


## Continuous trail for a moving spell. Particles live in world space so they stay behind.
static func trail(element_id: StringName, color: Color, amount: int = 48) -> GPUParticles3D:
	return _make(element_id, color, amount)


## One-shot burst (explosions, zone spawn). Frees itself when done.
static func burst(element_id: StringName, color: Color, radius: float, amount: int = 160) -> GPUParticles3D:
	var particles: GPUParticles3D = _make(element_id, color, amount)
	_set_one_shot(particles, radius)
	return particles


static func _make(element_id: StringName, color: Color, amount: int) -> GPUParticles3D:
	var look: Dictionary = LOOKS.get(element_id, LOOKS[&"fire"])
	var particles: GPUParticles3D = _build_layer(look, amount)
	var glow: GPUParticles3D = _build_glow(look, color, amount)
	glow.name = "Glow"
	particles.add_child(glow)
	return particles


static func _build_layer(look: Dictionary, amount: int) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = mini(amount, 1600)
	particles.lifetime = float(look["lifetime"])
	particles.local_coords = false
	particles.emitting = true
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3(0, 0, 1)
	process.spread = float(look["spread"])
	process.initial_velocity_min = float(look["speed"]) * 0.5
	process.initial_velocity_max = float(look["speed"])
	process.gravity = look["gravity"] as Vector3
	process.scale_min = 0.6
	process.scale_max = 1.2
	process.scale_curve = _scale_curve(look["scale_curve"] as Array)
	process.color_ramp = _alpha_ramp()
	var turbulence: float = float(look["turbulence"])
	if turbulence > 0.0:
		process.turbulence_enabled = true
		process.turbulence_noise_strength = turbulence
	var orbit: float = float(look["orbit"])
	if orbit > 0.0:
		process.orbit_velocity_min = orbit * 0.5
		process.orbit_velocity_max = orbit
	particles.process_material = process
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = look["quad"] as Vector2
	mesh.material = _glyph_material(look)
	particles.draw_pass_1 = mesh
	return particles


static func _build_glow(look: Dictionary, color: Color, amount: int) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = clampi(amount / 16, 3, 24)
	particles.lifetime = float(look["lifetime"])
	particles.local_coords = false
	particles.emitting = true
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3(0, 0, 1)
	process.spread = float(look["spread"])
	process.initial_velocity_min = float(look["speed"]) * 0.4
	process.initial_velocity_max = float(look["speed"]) * 0.8
	process.gravity = look["gravity"] as Vector3
	process.scale_min = 0.8
	process.scale_max = 1.2
	process.color_ramp = _alpha_ramp()
	var orbit: float = float(look["orbit"])
	if orbit > 0.0:
		process.orbit_velocity_min = orbit * 0.5
		process.orbit_velocity_max = orbit
	particles.process_material = process
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = (look["quad"] as Vector2) * 1.6
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _additive_shader()
	mat.set_shader_parameter(&"shape", 4)
	mat.set_shader_parameter(&"core_color", color.lightened(0.25))
	# A faint halo only: additive glow quads stack up fast and wash the glyphs to white.
	mat.set_shader_parameter(&"base_alpha", float(look["glow_alpha"]) * 0.3)
	mesh.material = mat
	particles.draw_pass_1 = mesh
	return particles


static func _glyph_material(look: Dictionary) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _additive_shader() if bool(look["additive"]) else GLYPH_SHADER
	mat.set_shader_parameter(&"shape", int(look["shape"]))
	mat.set_shader_parameter(&"core_color", look["core"] as Color)
	mat.set_shader_parameter(&"edge_color", look["edge"] as Color)
	mat.set_shader_parameter(&"base_alpha", float(look["alpha"]))
	mat.set_shader_parameter(&"random_rot", float(look["random_rot"]))
	return mat


static func _scale_curve(points: Array) -> CurveTexture:
	var curve: Curve = Curve.new()
	for i: int in points.size():
		curve.add_point(points[i] as Vector2)
	var texture: CurveTexture = CurveTexture.new()
	texture.curve = curve
	return texture


static func _alpha_ramp() -> GradientTexture1D:
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	return ramp


static func _additive_shader() -> Shader:
	if _additive_shader_cache == null:
		_additive_shader_cache = Shader.new()
		_additive_shader_cache.code = GLYPH_SHADER.code.replace("blend_mix", "blend_add")
	return _additive_shader_cache


static func _set_one_shot(particles: GPUParticles3D, radius: float) -> void:
	particles.one_shot = true
	particles.explosiveness = 0.9
	var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius * 0.3
	process.spread = 180.0
	process.initial_velocity_min = radius * 1.5
	process.initial_velocity_max = radius * 3.0
	particles.finished.connect(particles.queue_free)
	var glow: GPUParticles3D = particles.get_node_or_null(^"Glow") as GPUParticles3D
	if glow != null:
		glow.one_shot = true
		glow.explosiveness = 0.9
		var glow_process: ParticleProcessMaterial = glow.process_material as ParticleProcessMaterial
		glow_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		glow_process.emission_sphere_radius = radius * 0.3
		glow_process.spread = 180.0
		glow_process.initial_velocity_min = radius * 1.5
		glow_process.initial_velocity_max = radius * 3.0
