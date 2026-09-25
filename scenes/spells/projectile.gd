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
## Wind Bolt: degrees it may still turn toward the caster's crosshair.
var _homing_left: float = 0.0
var _deflected_by: Array[Node] = []

@onready var _mesh: MeshInstance3D = get_node_or_null(^"Mesh") as MeshInstance3D
@onready var _light: OmniLight3D = get_node_or_null(^"Light") as OmniLight3D


func _ready() -> void:
	velocity = direction * float(spell.param(&"speed", 30.0))
	# Storm Aura: faster projectiles.
	var caster_player: Player = caster as Player
	if caster_player != null and caster_player.active_aura != null:
		velocity *= 1.0 + float(caster_player.active_aura.param(&"projectile_speed_bonus", 0.0))
	if caster_player != null and caster_player.rune == &"focus":
		velocity *= 1.2
	_lifetime = float(spell.param(&"lifetime", 5.0))
	_max_range = float(spell.param(&"max_range", INF))
	_gravity = float(spell.param(&"gravity", 0.0))
	_homing_left = deg_to_rad(float(spell.param(&"homing_deg", 0.0)))
	var body: CollisionObject3D = caster as CollisionObject3D
	if body != null:
		_exclude.append(body.get_rid())
	_apply_color(spell.color)
	add_child(ElementFx.trail(spell.element, spell.color))


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y -= _gravity * delta
	_steer(delta)
	_check_deflect_zones()
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


## Wind Bolt: bends toward the point under the caster's crosshair, up to homing_deg in total.
func _steer(delta: float) -> void:
	if _homing_left <= 0.0 or caster == null or not is_instance_valid(caster):
		return
	var spell_caster: Node = caster.get_node_or_null(^"SpellCaster")
	if spell_caster == null:
		return
	var desired: Vector3 = (spell_caster.call(&"aim_point") as Vector3) - global_position
	var angle: float = velocity.angle_to(desired)
	if angle < 0.001:
		return
	var axis: Vector3 = velocity.cross(desired).normalized()
	var turn: float = minf(minf(angle, _homing_left), deg_to_rad(90.0) * delta)
	velocity = velocity.rotated(axis, turn)
	_homing_left -= turn


## Wind Seed zones deflect enemy projectiles that pass through them (35°, once per zone).
func _check_deflect_zones() -> void:
	for zone: Node in get_tree().get_nodes_in_group(&"deflect_zone"):
		var zone_3d: SpellNode = zone as SpellNode
		if zone_3d == null or zone_3d.caster == caster or _deflected_by.has(zone):
			continue
		var offset: Vector3 = global_position - zone_3d.global_position
		offset.y = 0.0
		if offset.length() <= float(zone_3d.spell.param(&"zone_radius", 3.5)) and global_position.y - zone_3d.global_position.y < 3.0:
			_deflected_by.append(zone)
			velocity = velocity.rotated(Vector3.UP, deg_to_rad(35.0))
