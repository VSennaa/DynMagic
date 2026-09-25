class_name Projectile
extends SpellNode
## Ray-stepped projectile (no tunneling at 45-70 m/s). Used by Bolt; Orb and Seed extend it.
## Params read from the resolved spell: speed, lifetime, max_range, gravity.

var velocity: Vector3 = Vector3.ZERO
var _travelled: float = 0.0
var _age: float = 0.0
var _lifetime: float = 2.5
var _max_range: float = INF
var _gravity: float = 0.0
var _exclude: Array[RID] = []

@onready var _mesh: MeshInstance3D = get_node_or_null(^"Mesh") as MeshInstance3D
@onready var _light: OmniLight3D = get_node_or_null(^"Light") as OmniLight3D


func _ready() -> void:
	velocity = direction * float(spell.param(&"speed", 30.0))
	_lifetime = float(spell.param(&"lifetime", 5.0))
	_max_range = float(spell.param(&"max_range", INF))
	_gravity = float(spell.param(&"gravity", 0.0))
	var body: CollisionObject3D = caster as CollisionObject3D
	if body != null:
		_exclude.append(body.get_rid())
	_apply_color(spell.color)


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y -= _gravity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = _exclude
	query.collide_with_areas = false
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		global_position = result["position"]
		_on_impact(result["position"], result["normal"], result["collider"])
		return
	global_position = to
	_travelled += from.distance_to(to)
	if _travelled >= _max_range or _age >= _lifetime:
		_on_expire()


## Direct hit: damage + optional status. Subclasses override for explosions and zones.
func _on_impact(_point: Vector3, _normal: Vector3, collider: Object) -> void:
	hit(find_damageable(collider))
	queue_free()


func _on_expire() -> void:
	queue_free()


func _apply_color(color: Color) -> void:
	if _mesh != null:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mesh.material_override = mat
	if _light != null:
		_light.light_color = color
