class_name BurstProjectile
extends Projectile
## Orb: explodes on impact or at max range. Damage falls off linearly from the
## center (spell.damage) to the edge (min_damage scaled by the element multiplier).
## Element variants (spec 01 §3): fire burning ground, frost frozen ground,
## storm chain bolt, wind pull before the blast.

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/spells/explosion_fx.tscn")
const ZONE_SCENE: PackedScene = preload("res://scenes/spells/zone.tscn")
const CHAIN_RANGE: float = 8.0


func _on_impact(point: Vector3, _normal: Vector3, _collider: Object) -> void:
	_explode(point)


func _on_expire() -> void:
	_explode(global_position)


func _explode(center: Vector3) -> void:
	var radius: float = float(spell.param(&"radius", 3.0))
	var min_scale: float = float(spell.param(&"min_damage", 0.0)) / maxf(spell.base_damage, 0.001)
	var targets: Array[Node] = overlap_damageables(center, radius)
	var pull: float = float(spell.param(&"pull_force", 0.0))
	for target: Node in targets:
		var target_3d: Node3D = target as Node3D
		var body_center: Vector3 = target_3d.global_position + Vector3.UP * 0.9
		if pull > 0.0 and target != caster and target.has_method(&"apply_knockback"):
			var toward: Vector3 = center - body_center
			toward.y = 0.0
			target.call(&"apply_knockback", toward.normalized() * pull)
		var t: float = clampf(center.distance_to(body_center) / radius, 0.0, 1.0)
		hit(target, lerpf(1.0, min_scale, t))
	var chain: float = float(spell.param(&"chain_damage", 0.0))
	if chain > 0.0:
		_chain(center, targets, chain)
	_leave_ground(center)
	var fx: ExplosionFx = EXPLOSION_SCENE.instantiate() as ExplosionFx
	fx.configure(radius, spell.color, spell.element)
	get_parent().add_child(fx)
	fx.global_position = center
	queue_free()


## Storm: one secondary bolt to the nearest damageable outside the blast.
func _chain(center: Vector3, already_hit: Array[Node], amount: float) -> void:
	var best: Node = null
	var best_dist: float = CHAIN_RANGE
	for target: Node in overlap_damageables(center, CHAIN_RANGE):
		if target == caster or already_hit.has(target):
			continue
		var dist: float = center.distance_to((target as Node3D).global_position)
		if dist < best_dist:
			best = target
			best_dist = dist
	if best != null:
		hit_amount(best, amount)


## Fire leaves burning ground, frost leaves frozen (slowing) ground.
func _leave_ground(center: Vector3) -> void:
	var burn_time: float = float(spell.param(&"burning_ground_duration", 0.0))
	var frost_time: float = float(spell.param(&"frozen_ground_duration", 0.0))
	if burn_time <= 0.0 and frost_time <= 0.0:
		return
	var overrides: Dictionary = {"zone_radius": float(spell.param(&"radius", 3.0)) * 0.8}
	if burn_time > 0.0:
		overrides.merge({"zone_duration": burn_time, "zone_dps": 8.0})
	else:
		overrides.merge({"zone_duration": frost_time, "zone_dps": 0.0, "zone_applies_status": true})
	var zone: Zone = ZONE_SCENE.instantiate() as Zone
	zone.setup(spell.with_params(overrides), caster, floor_below(center), direction, center)
	get_parent().add_child(zone)
