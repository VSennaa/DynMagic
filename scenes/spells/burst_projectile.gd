class_name BurstProjectile
extends Projectile
## Orb: explodes on impact or at max range. Damage falls off linearly from the
## center (spell.damage) to the edge (min_damage scaled by the element multiplier).

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/spells/explosion_fx.tscn")


func _on_impact(point: Vector3, _normal: Vector3, _collider: Object) -> void:
	_explode(point)


func _on_expire() -> void:
	_explode(global_position)


func _explode(center: Vector3) -> void:
	var radius: float = float(spell.param(&"radius", 3.0))
	var min_scale: float = float(spell.param(&"min_damage", 0.0)) / maxf(spell.base_damage, 0.001)
	for target: Node in overlap_damageables(center, radius):
		var target_3d: Node3D = target as Node3D
		var distance: float = center.distance_to(target_3d.global_position + Vector3.UP * 0.9)
		var t: float = clampf(distance / radius, 0.0, 1.0)
		hit(target, lerpf(1.0, min_scale, t))
	var fx: ExplosionFx = EXPLOSION_SCENE.instantiate() as ExplosionFx
	fx.configure(radius, spell.color)
	get_parent().add_child(fx)
	fx.global_position = center
	queue_free()


## Damageable nodes whose colliders overlap a sphere (caster excluded by hit()).
func overlap_damageables(center: Vector3, radius: float) -> Array[Node]:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	var found: Array[Node] = []
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var target: Node = find_damageable(result["collider"])
		if target != null and not found.has(target):
			found.append(target)
	return found
