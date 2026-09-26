class_name Zone
extends SpellNode
## Lingering ground zone (Seed). Ticks every TICK seconds on targets inside the radius.
## Params: zone_radius, zone_duration, zone_dps, zone_applies_status.

const TICK: float = 0.5
const RING_SHADER: Shader = preload("res://shaders/ground_ring.gdshader")

var radius: float = 3.5
var duration: float = 4.0
var dps: float = 0.0

var _age: float = 0.0
var _tick_timer: float = 0.0
var _ring: ShaderMaterial

@onready var _disc: MeshInstance3D = $Disc


func _ready() -> void:
	radius = float(spell.param(&"zone_radius", 3.5))
	duration = float(spell.param(&"zone_duration", 4.0))
	dps = float(spell.param(&"zone_dps", 0.0))
	add_to_group(&"territory")
	if bool(spell.param(&"deflect", false)):
		add_to_group(&"deflect_zone")
	# M11: lingering effects read as a pulsing dotted ring with a time-left arc,
	# unlike the one-shot solid ring of area spells (ExplosionFx).
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	_disc.mesh = plane
	_disc.scale = Vector3(radius, 1.0, radius)
	_ring = ShaderMaterial.new()
	_ring.shader = RING_SHADER
	_ring.set_shader_parameter(&"color", Color(spell.color, 0.9))
	_ring.set_shader_parameter(&"mode", 1)
	_disc.material_override = _ring
	if bool(spell.param(&"strip", false)):
		_disc.scale = Vector3(1.0, 1.0, 3.0)
		rotation.y = atan2(-direction.x, -direction.z)


func _physics_process(delta: float) -> void:
	_age += delta
	_tick_timer += delta
	_ring.set_shader_parameter(&"pulse_time", _age)
	_ring.set_shader_parameter(&"remaining", clampf(1.0 - _age / maxf(duration, 0.01), 0.0, 1.0))
	if _tick_timer >= TICK:
		_tick_timer -= TICK
		_apply_tick()
	if _age >= duration:
		queue_free()


func _apply_tick() -> void:
	if not has_authority():
		return
	var applies_status: bool = bool(spell.param(&"zone_applies_status", false))
	for target: Node in overlap_damageables(global_position + Vector3.UP * 0.9, radius):
		if not affects((target as Node3D).global_position):
			continue
		var duplicate_tick: bool = false
		for other: Node in get_tree().get_nodes_in_group(&"territory"):
			var zone: Zone = other as Zone
			if zone != self and zone.caster == caster and zone.spell.key == spell.key and zone.get_instance_id() < get_instance_id() and zone.affects((target as Node3D).global_position):
				duplicate_tick = true
				break
		if duplicate_tick:
			continue
		if SpatialContract.exposure(get_world_3d(), global_position + Vector3.UP * 0.05, target as Node3D, caster) <= 0.0:
			continue
		if dps > 0.0:
			hit_amount(target, dps * TICK)
		elif applies_status and target != caster and target.has_method(&"receive_status"):
			target.call(&"receive_status", spell, caster)
		var force: float = float(spell.param(&"current_force", 0.0))
		if force > 0.0 and target != caster and target.has_method(&"apply_knockback"):
			target.call(&"apply_knockback", Vector3(direction.x, 0, direction.z).normalized() * force)


func affects(point: Vector3) -> bool:
	if not SpatialContract.on_floor(point, global_position, radius):
		return false
	if bool(spell.param(&"strip", false)):
		var local: Vector3 = to_local(point)
		return absf(local.x) <= 1.0 and absf(local.z) <= 3.0
	return true
