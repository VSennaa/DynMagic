@tool
class_name CloisterSpaces
extends ArenaSpaces
## R5: broken ring, ground capture, two short terraces with two ramps each.


func _init() -> void:
	solids = mirrored([
		# Pushed 2 m further from the spawn exit along +z (user feedback v1.2.0: the low
		# wall sat only 1 m past the exit at z=-18). Front face now at z=-15, giving a
		# clear 3 m apron. Still clear of the route funnel (which turns to x=+-5 by
		# z=-18.5, well short of this box) and of the z=-10 cover below it.
		solid(0, -14, 7, 3.5, 2),
		# Shifted 0.1 m further from centre and raised to full height (Round 9 Sonnet-6,
		# sightline gate): the old 2.2/1.4 m height let a balcony-eye ray (3.1 m) clear both
		# boxes untouched, and the old edge sat exactly on the sightline sampler's 0.5 m
		# grid (x=-8/+8) so a standing-eye ray grazed past it too. Same footprint and route
		# clearance, just taller and off-grid; R5's "l1 has more exposure" nuance (shallower
		# depth than H1, still true below) is now limited to depth rather than height.
		solid(-6.1, -10, 4, 3.5, 2),
		solid(6.1, -10, 4, 3.5, 1.5),
		solid(-4, -3, 2, 3.5, 4),
		# Round 9 Sonnet-6 (sightline gate): a broken colonnade pair flanking the capture
		# disc on its z axis (disc stays a clear r=2; nearest pillar corner is 4 m out).
		# Breaks the shell's own corner-to-corner 45 deg diagonal, which the ring/terrace
		# cover never touches because it runs straight through the open centre. Clear of
		# every named route (they thread past x=0 or z<3) and of the flank corridors.
		solid(3.5, 7.5, 3, 3.5, 8),
		solid(-3.5, 7.5, 3, 3.5, 8),
		# Round 9 Sonnet-6 (sightline gate): a full-width screen wall at z=-5.0, closing the
		# whole 28 m width except the two 3 m gaps both named routes already thread (x=-7/+7
		# at this z; mirrored() carries the same gap positions to the south wall). Splits
		# the 36 m corridor into <=19 m stretches; the earlier per-side pilaster/rail
		# attempts always left a residual gap next to whichever route lane they had to
		# clear, so this replaces them with one route-aware wall.
		{"position": Vector3(-11.225, 0, -5.0), "size": Vector3(5.55, 3.5, 0.5), "yaw": 0.0},
		{"position": Vector3(11.225, 0, -5.0), "size": Vector3(5.55, 3.5, 0.5), "yaw": 0.0},
		{"position": Vector3(0, 0, -5.0), "size": Vector3(10.9, 3.5, 0.5), "yaw": 0.0},
	])
	platforms = mirrored([solid(-12, -2, 4, 1.5, 6)])
	ramps = mirrored([
		{"position": Vector3(-12, 0, -7), "width": 3.0, "height": 1.5, "length": 4.0, "yaw": PI},
		{"position": Vector3(-12, 0, 3), "width": 3.0, "height": 1.5, "length": 4.0, "yaw": 0.0},
	])
	var left: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -22.5), Vector3(0, 0, -18.5), Vector3(-5, 0, -18.5), Vector3(-9.5, 0, -13), Vector3(-9.5, 0, -7), Vector3(-7, 0, -6.5), Vector3(-7, 0, 0.5), Vector3(0, 0, 0.5)])
	# East route detours around the new sightline colonnade at (3.5,-7.5): the old straight
	# elbow through (0,-6.5) ran right through it, so it now steps out to z=-2.0 first.
	var right: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -22.5), Vector3(0, 0, -18.5), Vector3(5, 0, -18.5), Vector3(9.5, 0, -13), Vector3(9.5, 0, -7), Vector3(7, 0, -6.5), Vector3(7, 0, -2.0), Vector3(0, 0, -2.0), Vector3(0, 0, -1.5)])
	routes = {"north_west": left, "north_east": right, "south_east": _rotate_route(left), "south_west": _rotate_route(right)}


static func _rotate_route(points: PackedVector3Array) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in points:
		result.append(Vector3(-point.x, point.y, -point.z))
	return result
