class_name ExplosionFx
extends Node3D
## Placeholder burst: an unshaded sphere that grows to the radius and fades out.

const DURATION: float = 0.35
## M11: the ground ring of area spells, sharper and faster than the lingering ring.
const RING_TIME: float = 0.3
const RING_SHADER: Shader = preload("res://shaders/ground_ring.gdshader")

var _radius: float = 3.0
var _color: Color = Color.WHITE
var _element: StringName = &"fire"

@onready var _mesh: MeshInstance3D = $Mesh


func configure(radius: float, color: Color, element: StringName = &"fire") -> void:
	_radius = radius
	_color = color
	_element = element


func _ready() -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(_color, 0.6)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = mat
	_mesh.scale = Vector3.ONE * 0.1
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_mesh, ^"scale", Vector3.ONE * _radius, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(mat, ^"albedo_color:a", 0.0, DURATION)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	ring.mesh = plane
	ring.scale = Vector3(_radius, 1.0, _radius)
	ring.position.y = 0.05
	var ring_mat: ShaderMaterial = ShaderMaterial.new()
	ring_mat.shader = RING_SHADER
	ring_mat.set_shader_parameter(&"color", _color.lightened(0.25))
	ring_mat.set_shader_parameter(&"mode", 0)
	ring.material_override = ring_mat
	add_child(ring)
	tween.tween_method(func(t: float) -> void: ring_mat.set_shader_parameter(&"progress", t), 0.0, 1.0, RING_TIME)
	tween.chain().tween_interval(0.6)
	tween.chain().tween_callback(queue_free)
	AudioBus.play_impact.call_deferred(_element, global_position, get_parent())
	var particles: GPUParticles3D = ElementFx.burst(_element, _color, _radius)
	add_child(particles)
	particles.emitting = true
