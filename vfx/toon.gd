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
	else:
		# Untextured geometry is arena blockout: give it painted masonry in world space.
		mat.set_shader_parameter(&"procedural_surface", true)
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
	# The quad has no local offset, so it sits at distance ~0 from the camera -- Godot's
	# transparency sort then treats it as the single NEAREST transparent thing on screen every
	# frame, drawing it dead last over every other transparent/unshaded spell effect (spell
	# bodies, ground rings, explosion shells, self-spell shells) since its shader reads
	# SCREEN_TEXTURE and repaints the whole frame with zero blending on non-edge pixels. That
	# silently erased almost every transparent spell body in first-person play -- the exact
	# "still spherical with light, sometimes even invisible" report, since only fully opaque
	# bits (the OmniLight, Frost's ALPHA=1.0 crystal) survived. A large negative
	# `sorting_offset` makes the renderer's transparency sort treat this quad as much farther
	# from the camera than it actually is, so it draws first (earlier in the back-to-front
	# order) and every real transparent spell effect then draws normally on top of it.
	quad.sorting_offset = -10000.0
	camera.add_child(quad)
