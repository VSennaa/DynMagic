@tool
class_name SpineSpaces
extends ArenaSpaces
## R7: "espinha interrompida" — two longitudinal halls either side of a broken spine, a
## 6 m crossover at the centre and architectural masses (not corridor walls) segmenting
## the old wall-to-wall sightlines. No mandatory 1 m slit: halls are 5.25 m clear.


func _init() -> void:
	solids = mirrored([
		solid(0, -16, 7, 3.5, 2),
		solid(0, -6, 1.5, 3.5, 6),
		solid(-10, -6, 8, 3.5, 6),
		solid(10, -6, 8, 3.5, 6),
		solid(-7, 0, 2, 1.4, 2),
		solid(-9, 0, 2, 1.0, 2),
	])
	sightline_limit = 14.0
	var left: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -22.5), Vector3(0, 0, -18.5), Vector3(-5, 0, -18.5), Vector3(-5, 0, -12), Vector3(-3, 0, -12), Vector3(-3, 0, -1), Vector3(0, 0, 0)])
	var right: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -22.5), Vector3(0, 0, -18.5), Vector3(5, 0, -18.5), Vector3(5, 0, -12), Vector3(3, 0, -12), Vector3(3, 0, -1), Vector3(0, 0, 0)])
	routes = {"north_west": left, "north_east": right, "south_east": _rotate_route(left), "south_west": _rotate_route(right)}


static func _rotate_route(points: PackedVector3Array) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in points:
		result.append(Vector3(-point.x, point.y, -point.z))
	return result
