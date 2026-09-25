class_name AreaSpell
extends SpellNode
## Area-form spells.
##   direct    = Cone (range, angle_deg): instant hit in front of the caster
##   burst     = Mark (range, radius, delay): delayed blast on the ground
##   lingering = Wall: spawns a Wall scene (see wall.gd)

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/spells/explosion_fx.tscn")
const WALL_SCENE: PackedScene = preload("res://scenes/spells/wall.tscn")
const CONE_FX_TIME: float = 0.2

var _timer: float = 0.0
var _radius: float = 2.5

@onready var _visual: MeshInstance3D = $Visual


func _ready() -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(spell.color, 0.45)
	_visual.material_override = mat
	match spell.effect:
		&"direct":
			_cast_cone()
		&"burst":
			_place_mark()
		&"lingering":
			_place_wall()


func _process(delta: float) -> void:
	_timer -= delta
	if spell.effect == &"burst":
		# The ring shrinks toward the center as the blast approaches.
		var t: float = clampf(_timer / float(spell.param(&"delay", 0.9)), 0.0, 1.0)
		_visual.scale = Vector3(_radius * (0.25 + 0.75 * t), 1.0, _radius * (0.25 + 0.75 * t))
		if _timer <= 0.0:
			_detonate()
	elif _timer <= 0.0:
		queue_free()


func _cast_cone() -> void:
	var reach: float = float(spell.param(&"range", 6.0))
	var half_angle: float = deg_to_rad(float(spell.param(&"angle_deg", 50.0)) * 0.5)
	var origin: Vector3 = caster.global_position + Vector3.UP * 0.9 if caster != null else global_position
	var forward: Vector3 = direction
	for target: Node in overlap_damageables(origin, reach):
		var to_target: Vector3 = (target as Node3D).global_position + Vector3.UP * 0.9 - origin
		if to_target.length() > reach + 0.5 or forward.angle_to(to_target) > half_angle:
			continue
		if _has_line_of_sight(origin, target as Node3D):
			hit(target)
	# Visual: a flat fan pointing along the aim direction.
	global_position = origin
	look_at(origin + forward, Vector3.UP)
	_visual.mesh = _fan_mesh(reach, half_angle)
	_timer = CONE_FX_TIME


func _place_mark() -> void:
	_radius = float(spell.param(&"radius", 2.5))
	var spell_caster: Node = caster.get_node_or_null(^"SpellCaster") if caster != null else null
	var point: Vector3 = spell_caster.call(&"ground_target", float(spell.param(&"range", 25.0))) if spell_caster != null else target_point
	global_position = point + Vector3.UP * 0.04
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.04
	_visual.mesh = disc
	_timer = float(spell.param(&"delay", 0.9))


func _detonate() -> void:
	for target: Node in overlap_damageables(global_position + Vector3.UP * 0.9, _radius):
		hit(target)
	var fx: ExplosionFx = EXPLOSION_SCENE.instantiate() as ExplosionFx
	fx.configure(_radius, spell.color)
	get_parent().add_child(fx)
	fx.global_position = global_position
	queue_free()


func _place_wall() -> void:
	var spell_caster: Node = caster.get_node_or_null(^"SpellCaster") if caster != null else null
	var xform: Transform3D = spell_caster.call(&"wall_transform", float(spell.param(&"distance", 4.0))) if spell_caster != null else global_transform
	var wall: Wall = WALL_SCENE.instantiate() as Wall
	wall.setup(spell, caster, xform.origin, direction, target_point)
	get_parent().add_child(wall)
	wall.global_basis = xform.basis
	queue_free()


func _has_line_of_sight(origin: Vector3, target: Node3D) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target.global_position + Vector3.UP * 0.9)
	var body: CollisionObject3D = caster as CollisionObject3D
	if body != null:
		query.exclude = [body.get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or find_damageable(result["collider"]) == target


## Flat triangle fan in the XZ plane, opening toward -Z (the node looks along the aim).
static func _fan_mesh(reach: float, half_angle: float) -> ArrayMesh:
	const SEGMENTS: int = 16
	var verts: PackedVector3Array = PackedVector3Array()
	for i: int in SEGMENTS:
		var a0: float = lerpf(-half_angle, half_angle, float(i) / SEGMENTS)
		var a1: float = lerpf(-half_angle, half_angle, float(i + 1) / SEGMENTS)
		verts.append(Vector3.ZERO)
		verts.append(Vector3(sin(a0), 0.0, -cos(a0)) * reach)
		verts.append(Vector3(sin(a1), 0.0, -cos(a1)) * reach)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
