@tool
class_name ArenaBuilder
extends Node3D
## Builds an arena greybox from half-map tables and mirrors it by 180° around Y,
## so both spawns see the same layout. See docs/specs/03-arenas.md.
## Rebuilds in the editor when `variant` changes, and at runtime on _ready.

const ARENA_X: float = 28.0
const ARENA_Z: float = 38.0
const WALL_HEIGHT: float = 8.0
const WALL_THICKNESS: float = 1.0
const SPAWN_SIZE: float = 7.0
const BALCONY_WIDTH: float = 3.0
const BALCONY_HEIGHT: float = 1.5
const BALCONY_HALF_LENGTH: float = 9.0
const RAMP_LENGTH: float = 4.0

## Cover entries: [x, z, size_x, size_y, size_z, rotation_deg]. Only the north half (z < 0)
## and the centre line are listed; the builder adds the 180° mirror of each entry off-centre.
const LAYOUTS: Dictionary = {
	&"A": [
		# Central pillar (on the mirror axis: not duplicated).
		[0.0, 0.0, 3.0, 3.0, 3.0, 0.0],
		# Low boxes on the X axis, 5 m from the pillar.
		[-6.5, 0.0, 1.5, 1.0, 1.5, 0.0],
		# Box pairs (low + high) in the quadrants, rotated 20-30°.
		[-6.0, -9.5, 1.5, 1.0, 1.5, 25.0],
		[-4.6, -8.85, 1.5, 2.2, 1.5, 25.0],
		[6.5, -7.0, 1.5, 1.0, 1.5, -20.0],
		[5.1, -6.5, 1.5, 2.2, 1.5, -20.0],
		# Wall niches.
		[-13.25, -14.0, 1.5, 2.2, 1.0, 90.0],
		[13.25, -15.5, 1.5, 2.2, 1.0, 90.0],
	],
	&"B": [
		# Small high box at the exact centre.
		[0.0, 0.0, 1.5, 2.2, 1.5, 0.0],
		# Bars across the lane in front of each spawn.
		[0.0, -11.0, 4.5, 1.4, 1.2, 0.0],
		# "L" group (bar + box), diagonal.
		[-6.0, -6.0, 4.5, 1.4, 1.2, 30.0],
		[-4.3, -4.4, 1.5, 2.2, 1.5, 30.0],
		# Loose high box, opposite diagonal.
		[7.0, -4.0, 1.5, 2.2, 1.5, 15.0],
		# Large niche on one wall per side.
		[-13.0, -14.0, 1.0, 2.2, 3.0, 0.0],
	],
	&"C": [
		# Central spine along Z: 12 m with two 1 m gaps (3 + 1 + 4 + 1 + 3).
		[0.0, 0.0, 0.8, 2.5, 4.0, 0.0],
		[0.0, -4.5, 0.8, 2.5, 3.0, 0.0],
		# "L" blocks glued to the spine on opposite sides.
		[1.6, -4.5, 2.4, 1.4, 1.2, 0.0],
		# "T" structures on the side walls beyond the balconies.
		[-12.5, -15.5, 3.0, 2.2, 0.8, 0.0],
		[-11.4, -15.5, 0.8, 2.2, 3.0, 0.0],
		# Box pair and a loose high box in the quadrants.
		[-6.0, -10.0, 1.5, 1.0, 1.5, 0.0],
		[-4.5, -10.0, 1.5, 2.2, 1.5, 0.0],
		[6.0, -9.0, 1.5, 2.2, 1.5, 20.0],
	],
}

const VARIANTS: Array[StringName] = [&"A", &"B", &"C"]

@export var spaces: ArenaSpaces

@export var variant: StringName = &"A":
	set(value):
		variant = value
		if is_inside_tree():
			build()

## M12: footprint scale for expanded team arenas (3v3 = 1.5, decision 10). Scales the
## shell and every authored space in X/Z only (heights unchanged so traversal metrics
## stay valid) and opens two extra ground-level flank corridors. 1.0 keeps 1v1/2v2 exact.
@export var team_scale: float = 1.0:
	set(value):
		team_scale = value
		if is_inside_tree():
			build()

@export var floor_color: Color = Color(0.7, 0.65, 0.57)
@export var wall_color: Color = Color(0.6, 0.56, 0.52)
@export var cover_color: Color = Color(0.46, 0.4, 0.62)
@export var balcony_color: Color = Color(0.54, 0.35, 0.26)


func _ready() -> void:
	build()


func build() -> void:
	for child: Node in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.free()
	var effective: ArenaSpaces = _effective_spaces()
	_build_shell()
	if effective == null:
		_build_balconies()
		_build_cover()
	else:
		_build_spaces(effective)
	_build_spawns()
	var anchor: Marker3D = Marker3D.new()
	anchor.name = "CoreAnchor"
	anchor.position = effective.core_anchor if effective != null else Vector3(4.0, 0.0, 0.0)
	_adopt(anchor)
	if effective != null:
		for i: int in effective.spawn_regions.size():
			var region: Marker3D = Marker3D.new()
			region.name = "SpawnRegion%d" % i
			region.position = effective.spawn_regions[i].get_center()
			region.set_meta(&"bounds", effective.spawn_regions[i])
			_adopt(region)
		for i: int in effective.exits.size():
			var exit_marker: Marker3D = Marker3D.new()
			exit_marker.name = "Exit%d" % i
			exit_marker.position = effective.exits[i]
			_adopt(exit_marker)
	ArenaDressing.apply(self, wall_color, cover_color)


func _build_spaces(effective: ArenaSpaces) -> void:
	var index: int = 0
	for piece: Dictionary in effective.solids + effective.platforms:
		var size: Vector3 = piece["size"]
		var box: CSGBox3D = _box("Space%02d" % index, (piece["position"] as Vector3) + Vector3.UP * size.y * 0.5, size, cover_color)
		box.rotation.y = float(piece.get("yaw", 0.0))
		box.add_to_group(&"cover")
		index += 1
	for entry: Dictionary in effective.ramps:
		var height: float = entry["height"]
		var length: float = entry["length"]
		var ramp: CSGBox3D = _box("SpaceRamp%02d" % index, (entry["position"] as Vector3) + Vector3.UP * (height * 0.5 - 0.15), Vector3(float(entry["width"]), 0.3, sqrt(length * length + height * height)), balcony_color)
		ramp.rotation = Vector3(atan2(height, length), float(entry.get("yaw", 0.0)), 0)
		index += 1


## Returns `spaces` unchanged for team_scale 1.0 (1v1/2v2 exact), or a scaled-and-augmented
## copy for expanded team arenas. X/Z only; heights and thicknesses are untouched.
## Public so tests can validate the expanded routes/regions physically (tests/check_cloister.gd).
func effective_spaces() -> ArenaSpaces:
	return _effective_spaces()


func _effective_spaces() -> ArenaSpaces:
	if spaces == null:
		return null
	if is_equal_approx(team_scale, 1.0):
		return spaces
	var scaled: ArenaSpaces = ArenaSpaces.new()
	for piece: Dictionary in spaces.solids:
		scaled.solids.append(_scale_piece(piece))
	for piece: Dictionary in spaces.platforms:
		scaled.platforms.append(_scale_piece(piece))
	for ramp: Dictionary in spaces.ramps:
		scaled.ramps.append(_scale_ramp(ramp))
	scaled.core_anchor = _scale_xz(spaces.core_anchor)
	var regions: Array[AABB] = []
	for aabb: AABB in spaces.spawn_regions:
		regions.append(_scale_aabb(aabb))
	scaled.spawn_regions = regions
	var exits: Array[Vector3] = []
	for exit_point: Vector3 in spaces.exits:
		exits.append(_scale_xz(exit_point))
	scaled.exits = exits
	scaled.sightline_limit = spaces.sightline_limit * team_scale
	var routes: Dictionary = {}
	for key: String in spaces.routes:
		routes[key] = _scale_route(spaces.routes[key])
	_add_flank_routes(routes)
	scaled.routes = routes
	return scaled


func _scale_xz(v: Vector3) -> Vector3:
	return Vector3(v.x * team_scale, v.y, v.z * team_scale)


func _scale_piece(piece: Dictionary) -> Dictionary:
	return {"position": _scale_xz(piece["position"]), "size": _scale_xz(piece["size"]), "yaw": float(piece.get("yaw", 0.0))}


func _scale_ramp(ramp: Dictionary) -> Dictionary:
	return {"position": _scale_xz(ramp["position"]), "width": float(ramp["width"]) * team_scale,
		"length": float(ramp["length"]) * team_scale, "height": float(ramp["height"]), "yaw": float(ramp.get("yaw", 0.0))}


func _scale_aabb(aabb: AABB) -> AABB:
	var pos: Vector3 = aabb.position
	var size: Vector3 = aabb.size
	return AABB(Vector3(pos.x * team_scale, pos.y, pos.z * team_scale), Vector3(size.x * team_scale, size.y, size.z * team_scale))


func _scale_route(points: PackedVector3Array) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in points:
		out.append(_scale_xz(point))
	return out


## New ground-level flank corridors (decision 10), hugging the expanded shell wall on both
## sides. CloisterSpaces only puts a wall-adjacent terrace on a short middle stretch of each
## wall (the broken-ring platform/ramps), so the lane is carved in the two clear stretches
## north and south of it rather than the platform's own z band.
func _add_flank_routes(routes: Dictionary) -> void:
	var hx: float = ARENA_X * team_scale * 0.5
	var hz: float = ARENA_Z * team_scale * 0.5
	var flank_x: float = hx - 1.0
	var near: float = hz - 2.0
	# Clears the broken-ring platform/ramps on both walls (CloisterSpaces' furthest ramp
	# reaches roughly 7 m out plus half its slope length; scale the margin with the arena).
	var clear_of_terrace: float = 15.0 * team_scale
	for sign_x: float in [-1.0, 1.0]:
		var tag: String = "west" if sign_x < 0.0 else "east"
		routes["flank_%s_north" % tag] = PackedVector3Array([Vector3(sign_x * flank_x, 0, -near), Vector3(sign_x * flank_x, 0, -clear_of_terrace)])
		routes["flank_%s_south" % tag] = PackedVector3Array([Vector3(sign_x * flank_x, 0, clear_of_terrace), Vector3(sign_x * flank_x, 0, near)])


## Cover table expanded with its 180° mirror. Entries on the centre point are not duplicated.
static func mirrored_layout(layout_variant: StringName) -> Array:
	var out: Array = []
	for entry: Array in LAYOUTS.get(layout_variant, []):
		out.append(entry)
		var x: float = entry[0]
		var z: float = entry[1]
		if absf(x) > 0.001 or absf(z) > 0.001:
			out.append([-x, -z, entry[2], entry[3], entry[4], float(entry[5]) + 180.0])
	return out


func _build_shell() -> void:
	var ax: float = ARENA_X * team_scale
	var az: float = ARENA_Z * team_scale
	var spawn_size: float = SPAWN_SIZE * team_scale
	var hx: float = ax * 0.5
	var hz: float = az * 0.5
	var spawn_depth: float = spawn_size
	_box("Floor", Vector3(0, -0.5, 0), Vector3(ax, 1.0, az + spawn_depth * 2.0), floor_color)
	# Side walls.
	_box("WallWest", Vector3(-hx - WALL_THICKNESS * 0.5, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, az), wall_color)
	_box("WallEast", Vector3(hx + WALL_THICKNESS * 0.5, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, az), wall_color)
	# End walls with a spawn opening in the middle, plus the spawn corridors.
	var side_len: float = (ax - spawn_size) * 0.5
	for sign_z: float in [-1.0, 1.0]:
		var tag: String = "North" if sign_z < 0.0 else "South"
		var z_wall: float = sign_z * (hz + WALL_THICKNESS * 0.5)
		for sign_x: float in [-1.0, 1.0]:
			var x_center: float = sign_x * (spawn_size * 0.5 + side_len * 0.5)
			_box("Wall%s%s" % [tag, "W" if sign_x < 0.0 else "E"], Vector3(x_center, WALL_HEIGHT * 0.5, z_wall), Vector3(side_len, WALL_HEIGHT, WALL_THICKNESS), wall_color)
		var z_corridor: float = sign_z * (hz + spawn_depth * 0.5)
		for sign_x: float in [-1.0, 1.0]:
			_box("Spawn%sSide%s" % [tag, "W" if sign_x < 0.0 else "E"], Vector3(sign_x * (spawn_size * 0.5 + WALL_THICKNESS * 0.5), WALL_HEIGHT * 0.5, z_corridor), Vector3(WALL_THICKNESS, WALL_HEIGHT, spawn_depth), wall_color)
		_box("Spawn%sBack" % tag, Vector3(0, WALL_HEIGHT * 0.5, sign_z * (hz + spawn_depth + WALL_THICKNESS * 0.5)), Vector3(spawn_size + WALL_THICKNESS * 2.0, WALL_HEIGHT, WALL_THICKNESS), wall_color)
	# Invisible ceiling.
	var ceiling: StaticBody3D = StaticBody3D.new()
	ceiling.name = "Ceiling"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(ax, 1.0, az + spawn_depth * 2.0)
	shape.shape = box
	ceiling.add_child(shape)
	ceiling.position = Vector3(0, WALL_HEIGHT + 0.5, 0)
	_adopt(ceiling)


## Raised side balconies with a ramp at each end (the red wedges of the reference image).
func _build_balconies() -> void:
	var hx: float = ARENA_X * 0.5
	for sign_x: float in [-1.0, 1.0]:
		var x: float = sign_x * (hx - BALCONY_WIDTH * 0.5)
		var tag: String = "W" if sign_x < 0.0 else "E"
		_box("Balcony%s" % tag, Vector3(x, BALCONY_HEIGHT * 0.5, 0), Vector3(BALCONY_WIDTH, BALCONY_HEIGHT, BALCONY_HALF_LENGTH * 2.0), balcony_color)
		_box("Parapet%s" % tag, Vector3(x - sign_x * (BALCONY_WIDTH * 0.5 - 0.1), BALCONY_HEIGHT + 0.5, 0), Vector3(0.2, 1.0, BALCONY_HALF_LENGTH * 2.0 - 2.0), balcony_color)
		for sign_z: float in [-1.0, 1.0]:
			_ramp("Ramp%s%s" % [tag, "N" if sign_z < 0.0 else "S"], x, sign_z)


func _ramp(ramp_name: String, x: float, sign_z: float) -> void:
	var slope_len: float = sqrt(RAMP_LENGTH * RAMP_LENGTH + BALCONY_HEIGHT * BALCONY_HEIGHT)
	var angle: float = atan2(BALCONY_HEIGHT, RAMP_LENGTH)
	var center_z: float = sign_z * (BALCONY_HALF_LENGTH + RAMP_LENGTH * 0.5)
	var ramp: CSGBox3D = _box(ramp_name, Vector3(x, BALCONY_HEIGHT * 0.5 - 0.15, center_z), Vector3(BALCONY_WIDTH, 0.3, slope_len), balcony_color)
	ramp.rotation.x = angle * sign_z


func _build_cover() -> void:
	var index: int = 0
	for entry: Array in mirrored_layout(variant):
		var size: Vector3 = Vector3(entry[2], entry[3], entry[4])
		var box: CSGBox3D = _box("Cover%02d" % index, Vector3(entry[0], size.y * 0.5, entry[1]), size, cover_color)
		box.rotation.y = deg_to_rad(float(entry[5]))
		box.add_to_group(&"cover")
		_add_cover_visual(box, size)
		index += 1


## Keep the original CSG collision and layout; replace only exact-size cover visuals.
func _add_cover_visual(box: CSGBox3D, size: Vector3) -> void:
	var scene: PackedScene
	if size.is_equal_approx(Vector3(1.5, 1.0, 1.5)):
		scene = preload("res://scenes/assets/cover_low.tscn")
	elif size.is_equal_approx(Vector3(1.5, 2.2, 1.5)):
		scene = preload("res://scenes/assets/cover_high.tscn")
	elif size.is_equal_approx(Vector3(4.5, 1.4, 1.2)):
		scene = preload("res://scenes/assets/cover_bar.tscn")
	elif size.is_equal_approx(Vector3(3.0, 3.0, 3.0)):
		scene = preload("res://scenes/assets/pillar.tscn")
	if scene == null:
		return
	# Render layers do not control CSG collision generation; visibility does.
	box.layers = 0
	var visual: Node3D = scene.instantiate() as Node3D
	visual.position = box.position - Vector3.UP * size.y * 0.5
	visual.rotation = box.rotation
	_adopt(visual)


func _build_spawns() -> void:
	var hz: float = (ARENA_Z * 0.5 + SPAWN_SIZE * 0.5) * team_scale
	for sign_z: float in [-1.0, 1.0]:
		var marker: Marker3D = Marker3D.new()
		marker.name = "SpawnNorth" if sign_z < 0.0 else "SpawnSouth"
		marker.position = Vector3(0, 0, sign_z * hz)
		# Face the arena centre.
		marker.rotation.y = 0.0 if sign_z > 0.0 else PI
		marker.add_to_group(&"spawn")
		_adopt(marker)


func _box(box_name: String, pos: Vector3, size: Vector3, color: Color) -> CSGBox3D:
	var box: CSGBox3D = CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = pos
	box.use_collision = true
	box.material = Toon.material(color)
	_adopt(box)
	return box


func _adopt(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)
