@tool
class_name SpatialContract
extends RefCounted
## Shared authority-side geometry for impacts, blasts and floor-bound territory.

const BODY_SAMPLES: Array[float] = [0.35, 0.9, 1.45]
const TERRITORY_HEIGHT: float = 0.5


static func on_floor(point: Vector3, anchor: Vector3, radius: float, height: float = TERRITORY_HEIGHT) -> bool:
	var offset: Vector3 = point - anchor
	return absf(offset.y) <= height and Vector2(offset.x, offset.z).length() <= radius


static func clear_path(world: World3D, origin: Vector3, end: Vector3, target: Node, caster: Node = null) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	if caster is CollisionObject3D:
		query.exclude = [(caster as CollisionObject3D).get_rid()]
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	return result.is_empty() or SpellNode.find_damageable(result["collider"]) == target


static func exposure(world: World3D, origin: Vector3, target: Node3D, caster: Node = null) -> float:
	var visible_samples: int = 0
	for height: float in BODY_SAMPLES:
		if clear_path(world, origin, target.global_position + Vector3.UP * height, target, caster):
			visible_samples += 1
	return float(visible_samples) / BODY_SAMPLES.size()
