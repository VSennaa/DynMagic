class_name ElementFx
extends RefCounted
## Placeholder GPU particle looks per element (docs/specs/07-art-pipeline.md section 2):
##   fire  orange square sparks rising        frost  pale crystal flakes drifting down
##   storm short bright streaks, jittery      wind   long thin ribbons swirling
## Every system stays under 2,000 live particles (spec 07 acceptance).

const LOOKS: Dictionary = {
	&"fire": {"size": Vector3(0.07, 0.07, 0.07), "gravity": Vector3(0, 2.5, 0), "spread": 25.0, "speed": 1.2, "lifetime": 0.5},
	&"frost": {"size": Vector3(0.05, 0.09, 0.05), "gravity": Vector3(0, -1.5, 0), "spread": 60.0, "speed": 0.6, "lifetime": 0.8},
	&"storm": {"size": Vector3(0.02, 0.02, 0.22), "gravity": Vector3.ZERO, "spread": 180.0, "speed": 3.0, "lifetime": 0.15},
	&"wind": {"size": Vector3(0.02, 0.02, 0.35), "gravity": Vector3.ZERO, "spread": 40.0, "speed": 2.0, "lifetime": 0.6},
}


## Continuous trail for a moving spell. Particles live in world space so they stay behind.
static func trail(element_id: StringName, color: Color, amount: int = 48) -> GPUParticles3D:
	var particles: GPUParticles3D = _make(element_id, color, amount)
	particles.local_coords = false
	return particles


## One-shot burst (explosions, zone spawn). Frees itself when done.
static func burst(element_id: StringName, color: Color, radius: float, amount: int = 160) -> GPUParticles3D:
	var particles: GPUParticles3D = _make(element_id, color, amount)
	particles.one_shot = true
	particles.explosiveness = 0.9
	var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius * 0.3
	process.spread = 180.0
	process.initial_velocity_min = radius * 1.5
	process.initial_velocity_max = radius * 3.0
	particles.finished.connect(particles.queue_free)
	return particles


static func _make(element_id: StringName, color: Color, amount: int) -> GPUParticles3D:
	var look: Dictionary = LOOKS.get(element_id, LOOKS[&"fire"])
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = mini(amount, 2000)
	particles.lifetime = float(look["lifetime"])
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3(0, 0, 1)
	process.spread = float(look["spread"])
	process.initial_velocity_min = float(look["speed"]) * 0.5
	process.initial_velocity_max = float(look["speed"])
	process.gravity = look["gravity"]
	process.scale_min = 0.6
	process.scale_max = 1.2
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	if element_id == &"storm":
		process.turbulence_enabled = true
		process.turbulence_noise_strength = 4.0
	elif element_id == &"wind":
		process.orbit_velocity_min = 0.5
		process.orbit_velocity_max = 1.0
	particles.process_material = process
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = look["size"]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color.lerp(Color.WHITE, 0.25)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	particles.draw_pass_1 = mesh
	return particles
