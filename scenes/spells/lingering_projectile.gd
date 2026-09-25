class_name LingeringProjectile
extends Projectile
## Seed: lobbed projectile (gravity) that plants a Zone where it lands.

const ZONE_SCENE: PackedScene = preload("res://scenes/spells/zone.tscn")


func _on_impact(point: Vector3, _normal: Vector3, _collider: Object) -> void:
	_plant(point)


func _on_expire() -> void:
	_plant(global_position)


func _plant(point: Vector3) -> void:
	var zone: Zone = ZONE_SCENE.instantiate() as Zone
	zone.setup(spell, caster, _ground_below(point), direction, point)
	get_parent().add_child(zone)
	queue_free()


## Zones sit on the floor even when the seed hits a wall or a target.
func _ground_below(point: Vector3) -> Vector3:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point + Vector3.DOWN * 20.0)
	query.exclude = _exclude
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return result["position"] if not result.is_empty() else point
