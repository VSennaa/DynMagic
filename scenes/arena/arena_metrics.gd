@tool
class_name ArenaMetrics
extends RefCounted
## Physical gates operate on the built geometry, including temporary barriers.


static func capsule_clear(world: World3D, foot: Vector3, radius: float = 0.35) -> bool:
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(1.8, radius * 2.0)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.transform.origin = foot + Vector3.UP * (capsule.height * 0.5 + 0.03)
	return world.direct_space_state.intersect_shape(query, 1).is_empty()


static func route_clear(world: World3D, points: PackedVector3Array) -> bool:
	for i: int in range(1, points.size()):
		var steps: int = maxi(1, ceili(points[i - 1].distance_to(points[i]) / 0.25))
		for step: int in steps + 1:
			if not capsule_clear(world, points[i - 1].lerp(points[i], float(step) / steps)):
				return false
	return true


static func spawn_leaks(world: World3D, spaces: ArenaSpaces) -> int:
	var leaks: int = 0
	var a: AABB = spaces.spawn_regions[0]
	var b: AABB = spaces.spawn_regions[1]
	# Border/centre samples, including standing, crouching and jump apex.
	for height: float in [1.068, 1.602, 2.802]:
		for x1: float in [0.35, 3.5, 6.65]:
			for x2: float in [0.35, 3.5, 6.65]:
				for z1: float in [0.35, 3.5, 6.65]:
					for z2: float in [0.35, 3.5, 6.65]:
						var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a.position + Vector3(x1, height, z1), b.position + Vector3(x2, height, z2), 1)
						if world.direct_space_state.intersect_ray(query).is_empty():
							leaks += 1
	return leaks


## Reports maximum sampled sightline, never disguises design targets as proven gates.
static func sightlines(world: World3D, limit: float) -> Dictionary:
	var longest: float = 0.0
	var exceptions: int = 0
	for x: int in range(-26, 27):
		for z: int in range(-36, 37):
			for height: float in [1.068, 1.602, 3.102]:
				var origin: Vector3 = Vector3(x * 0.5, height, z * 0.5)
				if not capsule_clear(world, origin - Vector3.UP * 0.9):
					continue
				for angle: int in 8:
					var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, angle * PI / 4.0)
					var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 60.0, 1)
					var hit: Dictionary = world.direct_space_state.intersect_ray(query)
					var length: float = origin.distance_to(hit["position"]) if not hit.is_empty() else 60.0
					longest = maxf(longest, length)
					if length > limit:
						exceptions += 1
	return {"max_sightline": longest, "over_target": exceptions, "exposure_seconds": longest / 5.5}
