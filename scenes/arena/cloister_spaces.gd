@tool
class_name CloisterSpaces
extends ArenaSpaces
## R5: broken ring, ground capture, two short terraces with two ramps each.


func _init() -> void:
	solids = mirrored([
		solid(0, -16, 7, 3.5, 2),
		solid(-6, -10, 4, 2.2, 2),
		solid(6, -10, 4, 1.4, 1.5),
		solid(-4, -3, 2, 3.5, 4),
	])
	platforms = mirrored([solid(-12, -2, 4, 1.5, 6)])
	ramps = mirrored([
		{"position": Vector3(-12, 0, -7), "width": 3.0, "height": 1.5, "length": 4.0, "yaw": PI},
		{"position": Vector3(-12, 0, 3), "width": 3.0, "height": 1.5, "length": 4.0, "yaw": 0.0},
	])
	var left: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -22.5), Vector3(0, 0, -18.5), Vector3(-5, 0, -18.5), Vector3(-9.5, 0, -13), Vector3(-9.5, 0, -7), Vector3(-7, 0, -6.5), Vector3(-7, 0, 0.5), Vector3(0, 0, 0.5)])
	var right: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -22.5), Vector3(0, 0, -18.5), Vector3(5, 0, -18.5), Vector3(9.5, 0, -13), Vector3(9.5, 0, -7), Vector3(7, 0, -6.5), Vector3(0, 0, -6.5), Vector3(0, 0, -1.5)])
	routes = {"north_west": left, "north_east": right, "south_east": _rotate_route(left), "south_west": _rotate_route(right)}


static func _rotate_route(points: PackedVector3Array) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in points:
		result.append(Vector3(-point.x, point.y, -point.z))
	return result
