class_name AimPreview
extends Node3D
## Shows where a confirm spell will land while the composer is AIMING.
## Only the caster sees it (docs/specs/01-spell-system.md section 2.1).

@export var player: Player

var _spell: ResolvedSpell
## Surface normal of the last preview ray hit.
var _normal: Vector3 = Vector3.UP

@onready var _ring: MeshInstance3D = $Ring
@onready var _arc: MeshInstance3D = $Arc


func _ready() -> void:
	top_level = true
	# Arc vertices are written in world space, so this node must sit at the origin.
	global_transform = Transform3D.IDENTITY
	visible = false
	if player == null:
		player = get_parent() as Player
	# Children are ready before the player, so its @onready vars are still null here.
	var composer: SpellComposer = player.get_node(^"SpellComposer") as SpellComposer
	composer.aim_started.connect(_on_aim_started)
	composer.aim_ended.connect(_on_aim_ended)


func _physics_process(_delta: float) -> void:
	if _spell == null:
		return
	match _spell.key:
		&"projectile_burst":
			_show_ring(_projectile_impact(float(_spell.param(&"max_range", 30.0))), float(_spell.param(&"radius", 3.0)))
		&"projectile_lingering":
			var landing: Vector3 = _trace_arc()
			_normal = Vector3.UP
			_show_ring(landing, float(_spell.param(&"zone_radius", 3.5)))
		&"area_burst":
			_show_ring(_ground_point(float(_spell.param(&"range", 25.0))), float(_spell.param(&"radius", 2.5)))
		_:
			_ring.visible = false
	if _spell.key != &"projectile_lingering":
		_arc.visible = false


## Simulates the Seed's ballistic path, draws it and returns the landing point.
func _trace_arc() -> Vector3:
	const STEP: float = 1.0 / 30.0
	var origin: Vector3 = player.cast_origin.global_position
	var aim: Vector3 = player.get_node(^"SpellCaster").call(&"aim_point")
	var velocity: Vector3 = (aim - origin).normalized() * float(_spell.param(&"speed", 18.0))
	var gravity: float = float(_spell.param(&"gravity", 14.0))
	var lifetime: float = float(_spell.param(&"lifetime", 5.0))
	var mesh: ImmediateMesh = _arc.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var pos: Vector3 = origin
	var landing: Vector3 = pos
	var t: float = 0.0
	mesh.surface_add_vertex(pos)
	while t < lifetime:
		velocity.y -= gravity * STEP
		var next: Vector3 = pos + velocity * STEP
		var hit_point: Vector3 = _ray(pos, next)
		if hit_point != next:
			landing = hit_point
			mesh.surface_add_vertex(hit_point)
			break
		mesh.surface_add_vertex(next)
		pos = next
		landing = pos
		t += STEP
	mesh.surface_end()
	_arc.visible = true
	return _ray(landing + Vector3.UP * 0.2, landing + Vector3.DOWN * 20.0)


## First hit along the cast direction, capped at max range.
func _projectile_impact(max_range: float) -> Vector3:
	var origin: Vector3 = player.cast_origin.global_position
	var aim: Vector3 = player.get_node(^"SpellCaster").call(&"aim_point")
	var dir: Vector3 = (aim - origin).normalized()
	return _ray(origin, origin + dir * max_range)


## Crosshair point projected to the ground below it, clamped to range.
func _ground_point(max_range: float) -> Vector3:
	var aim: Vector3 = player.get_node(^"SpellCaster").call(&"aim_point")
	var flat: Vector3 = aim - player.global_position
	flat.y = 0.0
	if flat.length() > max_range:
		aim = player.global_position + flat.normalized() * max_range + Vector3.UP * aim.y
	return _ray(aim + Vector3.UP * 0.5, aim + Vector3.DOWN * 20.0)


func _ray(from: Vector3, to: Vector3) -> Vector3:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	_normal = result["normal"] if not result.is_empty() else Vector3.UP
	return result["position"] if not result.is_empty() else to


func _show_ring(point: Vector3, radius: float) -> void:
	_ring.visible = true
	# Lay the ring flat on the surface that was hit (floor, wall or target).
	var up: Vector3 = _normal.normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var ring_basis: Basis = Basis(side * radius, up, side.cross(up) * radius)
	_ring.global_transform = Transform3D(ring_basis, point + up * 0.03)


func _on_aim_started(spell: ResolvedSpell) -> void:
	_spell = spell
	visible = true
	for mesh_node: MeshInstance3D in [_ring, _arc]:
		var mat: StandardMaterial3D = mesh_node.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(spell.color, 0.45)


func _on_aim_ended() -> void:
	_spell = null
	visible = false
