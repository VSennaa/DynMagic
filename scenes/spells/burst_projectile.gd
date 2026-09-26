class_name BurstProjectile
extends Projectile
## Orb: explodes on impact or at max range. Damage falls off linearly from the
## center (spell.damage) to the edge (min_damage scaled by the element multiplier).
## Element variants (spec 01 §3): fire burning ground, frost frozen ground,
## storm chain bolt, wind pull before the blast.

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/spells/explosion_fx.tscn")


func _on_impact(point: Vector3, normal: Vector3, _collider: Object) -> void:
	_explode(point + normal * 0.04)


func _on_expire() -> void:
	_explode(global_position)


func _explode(center: Vector3) -> void:
	var radius: float = float(spell.param(&"radius", 3.0))
	var min_scale: float = float(spell.param(&"min_damage", 0.0)) / maxf(spell.base_damage, 0.001)
	var targets: Array[Node] = overlap_damageables(center, radius)
	var pull: float = float(spell.param(&"pull_force", 0.0))
	for target: Node in targets:
		var target_3d: Node3D = target as Node3D
		var exposed: float = SpatialContract.exposure(get_world_3d(), center, target_3d, caster)
		if exposed <= 0.0:
			continue
		var body_center: Vector3 = target_3d.global_position + Vector3.UP * 0.9
		if pull > 0.0 and has_authority() and target != caster and target.has_method(&"apply_knockback"):
			var toward: Vector3 = center - body_center
			toward.y = 0.0
			target.call(&"apply_knockback", toward.normalized() * pull)
		var t: float = clampf(center.distance_to(body_center) / radius, 0.0, 1.0)
		hit(target, lerpf(1.0, min_scale, t) * exposed)
	var fx: ExplosionFx = EXPLOSION_SCENE.instantiate() as ExplosionFx
	fx.configure(radius, spell.color, spell.element)
	get_parent().add_child(fx)
	fx.global_position = center
	queue_free()

