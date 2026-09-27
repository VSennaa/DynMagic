@tool
class_name PatioSpaces
extends ArenaSpaces
## R6: "dois terraços, praça baixa" — two discontinuous diagonal terraces (no bridge over
## the point) and a lateral mass segmenting the outer corridor, so height forces a real
## reposition instead of a single dominant balcony.


func _init() -> void:
	solids = mirrored([
		solid(0, -16, 7, 3.5, 2),
		solid(-2, -7, 2, 3.5, 4),
		solid(-12.5, 0, 3, 3.5, 3),
		solid(-6, -12, 3, 1.4, 1.5),
	])
	platforms = mirrored([solid(8, -7, 6, 1.5, 6)])
	ramps = mirrored([
		{"position": Vector3(8, 0, -12), "width": 3.0, "height": 1.5, "length": 4.0, "yaw": PI},
		{"position": Vector3(8, 0, -2), "width": 3.0, "height": 1.5, "length": 4.0, "yaw": 0.0},
	])
	sightline_limit = 22.0
	# West: skirts H1 (-2,-7) and l (-6,-12) via a wide loop, like Cloister's own detour.
	var left: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -22.5), Vector3(0, 0, -18.5), Vector3(-5, 0, -18.5), Vector3(-5, 0, -14.2), Vector3(-9, 0, -14.2), Vector3(-9, 0, -9.8), Vector3(-7, 0, -4), Vector3(-4, 0, -1), Vector3(0, 0, 0)])
	# East: cuts inside the TT platform (8,-7) instead of the west-side clutter.
	var right: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -22.5), Vector3(0, 0, -18.5), Vector3(5, 0, -18.5), Vector3(5, 0, -14), Vector3(3, 0, -11), Vector3(3, 0, -3), Vector3(0, 0, 0)])
	routes = {"north_west": left, "north_east": right, "south_east": _rotate_route(left), "south_west": _rotate_route(right)}


static func _rotate_route(points: PackedVector3Array) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in points:
		result.append(Vector3(-point.x, point.y, -point.z))
	return result
