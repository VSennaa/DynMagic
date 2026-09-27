@tool
class_name PatioSpaces
extends ArenaSpaces
## R6: "dois terraços, praça baixa" — two discontinuous diagonal terraces (no bridge over
## the point) and a lateral mass segmenting the outer corridor, so height forces a real
## reposition instead of a single dominant balcony.


func _init() -> void:
	solids = mirrored([
		# Pushed 0.6 m further from the spawn exit and narrowed from 2.2 m to 1.0 m deep
		# (user feedback v1.2.0: the low wall sat only 0.9 m past the exit at z=-18). Front
		# face now at z=-15.9, giving a clear 2.1 m apron. Both the push and the narrowing
		# are tightly capped by the east route's (5,-13.5)-(3,-12.8) diagonal elbow, which
		# needs its 2.5 m capsule clearance from this box the whole way along, not just at
		# its endpoints; the old 2.2 m depth left almost no room to move before clipping it.
		# (Depth note, superseding the comment this replaces: the old near edge (z=-17) sat
		# exactly on the sightline sampler's grid, letting a ray at x=-1 graze along the
		# vestibule wall past the anteparo untouched; the new position/depth keeps that edge
		# off-grid too.)
		solid(0, -15.4, 7, 3.5, 1.0),
		solid(-2, -7, 2, 3.5, 4),
		# Widened from the original 3 m and thinned from 3 m to 1 m deep (Round 9 Sonnet-6,
		# sightline gate): the old east edge sat exactly on the sightline sampler's grid
		# (x=-11.0), so a ray grazed past it down the corridor untouched. Widening it while
		# keeping the original 3 m depth would have pulled its z clearance band (+-2.75 m)
		# over the west route's z=-2.0 detour; thinning to 1 m shrinks that band to +-1.75 m,
		# clearing the detour (z=-2.0) while the new east edge (x=-4.4) still clears the
		# route's closer diagonal approach (x=-3 at z=-1.5) by over 1.25 m.
		solid(-9.4, 0, 9.2, 3.5, 1),
		# Shifted 0.1 m and raised to full height (Round 9 Sonnet-6, sightline gate): the
		# old 1.4 m height and grid-aligned edge (x=-4/-8) let both a balcony-eye ray and a
		# standing-eye ray graze past it down the corridor untouched.
		solid(-6.1, -12, 3, 3.5, 1.5),
		# Round 9 Sonnet-6 (sightline gate): raised planter colonnade flanking the plaza on
		# its z axis (disc stays a clear r=2; nearest planter corner is 4 m out). Breaks the
		# shell's own corner-to-corner 45 deg diagonal, unaffected by the terraces since it
		# runs through the open plaza. Clear of both named routes (they stay at z<=3 near
		# centre) and of the flank corridors.
		solid(3.5, 7.5, 3, 3.5, 8),
		solid(-3.5, 7.5, 3, 3.5, 8),
	])
	platforms = mirrored([solid(8, -7, 6, 1.5, 6)])
	ramps = mirrored([
		{"position": Vector3(8, 0, -12), "width": 3.0, "height": 1.5, "length": 4.0, "yaw": PI},
		{"position": Vector3(8, 0, -2), "width": 3.0, "height": 1.5, "length": 4.0, "yaw": 0.0},
	])
	sightline_limit = 22.0
	# West: skirts H1 (-2,-7) and l (-6,-12) via a wide loop, like Cloister's own detour. The
	# last elbow steps out to z=-2.0 first (Round 9 Sonnet-6) to clear the new sightline
	# colonnade at (-3.5,-7.5), which the old straight (-7,-4)-(-4,-1) diagonal clipped.
	var left: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -22.5), Vector3(0, 0, -18.5), Vector3(-5, 0, -18.5), Vector3(-5, 0, -14.2), Vector3(-9, 0, -14.2), Vector3(-9, 0, -9.8), Vector3(-7, 0, -4), Vector3(-7, 0, -2.0), Vector3(-4, 0, -2.0), Vector3(0, 0, 0)])
	# East: cuts inside the TT platform (8,-7) instead of the west-side clutter. Re-elbows
	# around the new sightline colonnade at (3.5,-7.5) (Round 9 Sonnet-6): the old straight
	# run through (3,-11)-(3,-3) ran right through it, so it now jogs to x=0.4 first.
	var right: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -22.5), Vector3(0, 0, -18.5), Vector3(5, 0, -18.5), Vector3(5, 0, -13.5), Vector3(3, 0, -12.8), Vector3(0.4, 0, -12.8), Vector3(0.4, 0, -1.8), Vector3(0, 0, -1.8), Vector3(0, 0, 0)])
	routes = {"north_west": left, "north_east": right, "south_east": _rotate_route(left), "south_west": _rotate_route(right)}


static func _rotate_route(points: PackedVector3Array) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in points:
		result.append(Vector3(-point.x, point.y, -point.z))
	return result
