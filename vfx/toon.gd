class_name Toon
extends RefCounted
## Helpers to apply the shared toon look (spec 07 §2: 100% of visible meshes).

const TOON_SHADER: Shader = preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://shaders/outline.gdshader")


static func material(color: Color, albedo: Texture2D = null) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter(&"base_color", color)
	if albedo != null:
		mat.set_shader_parameter(&"albedo_texture", albedo)
	return mat


## Adds the screen-space ink outline in front of a camera.
static func add_outline(camera: Camera3D) -> void:
	if camera.has_node(^"InkOutline"):
		return
	var quad: MeshInstance3D = MeshInstance3D.new()
	quad.name = "InkOutline"
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(2, 2)
	quad.mesh = mesh
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	quad.material_override = mat
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(quad)
