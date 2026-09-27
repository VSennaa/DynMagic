@tool
class_name ArenaDressing
extends RefCounted
## Visual dressing for the arena hull (docs/specs/03-arenas.md, M13 gauntlet).
## Static-only helper: builds a single collision-free "Dressing" Node3D under the
## Layout. Wall-hugging bands (plinth/pilaster) protrude <= 0.2 m into the playable
## floor so the R3 corridor/cover metrics are unchanged; the cornice overhang and
## the placed props are above head height or outside the playable floor and are
## visual only, so they carry no collision either.

const WALL_HEIGHT: float = 8.0

const PLINTH_HEIGHT: float = 0.55
const PLINTH_DEPTH: float = 0.18

const CORNICE_HEIGHT: float = 0.35
const CORNICE_OVERHANG: float = 0.3

const PILASTER_WIDTH: float = 0.9
const PILASTER_DEPTH: float = 0.18
const PILASTER_SPACING: float = 6.0
const CAPITAL_HEIGHT: float = 0.3
const CAPITAL_WIDTH: float = 1.2

const COVER_TOP_THICKNESS: float = 0.12
const COVER_TOP_OVERHANG: float = 0.08

const ARENA_HALF_X: float = 14.0
const ARENA_HALF_Z: float = 19.0

const BANNER_HEIGHT_M: float = 2.7
const BANNER_TOP_HEIGHT: float = 5.0

const ARCH_SCENE: PackedScene = preload("res://scenes/assets/spawn_arch.tscn")
const BRAZIER_SCENE: PackedScene = preload("res://scenes/assets/brazier.tscn")
const BANNER_SCENE: PackedScene = preload("res://scenes/assets/banner.tscn")
const PILLAR_SCENE: PackedScene = preload("res://scenes/assets/pillar.tscn")


static func apply(layout: Node3D, wall_color: Color, cover_color: Color) -> void:
	var dressing: Node3D = Node3D.new()
	dressing.name = "Dressing"
	dressing.set_meta(&"generated", true)
	layout.add_child(dressing)

	var walls: Array[Node3D] = []
	for child: Node in layout.get_children():
		if not (child is CSGBox3D):
			continue
		var child_name: String = child.name
		if child_name.begins_with("Wall") or child_name.begins_with("Spawn"):
			walls.append(child as Node3D)

	for wall: Node3D in walls:
		_add_plinth(dressing, wall, wall_color)
		_add_cornice(dressing, wall, wall_color)
		if not wall.name.contains("Side"):
			_add_pilasters(dressing, wall, wall_color)

	_add_cover_tops(dressing, layout, cover_color)
	_add_props(dressing)


## Splits a hull wall into its length/thickness axes and the inward normal.
static func _wall_axes(wall: Node3D) -> Dictionary:
	var size: Vector3 = (wall as CSGBox3D).size
	var pos: Vector3 = wall.position
	if size.x > size.z:
		# Runs along X; thickness along Z, faces the arena centre (z = 0).
		return {"along_x": true, "length": size.x, "thickness": size.z, "inward_x": 0.0, "inward_z": -signf(pos.z)}
	# Runs along Z; thickness along X, faces the arena centre (x = 0).
	return {"along_x": false, "length": size.z, "thickness": size.x, "inward_x": -signf(pos.x), "inward_z": 0.0}


static func _add_plinth(parent: Node3D, wall: Node3D, color: Color) -> void:
	var axes: Dictionary = _wall_axes(wall)
	var along_x: bool = axes["along_x"]
	var length: float = axes["length"]
	var thickness: float = axes["thickness"]
	var inward_x: float = axes["inward_x"]
	var inward_z: float = axes["inward_z"]
	var pos: Vector3 = wall.position
	var size: Vector3
	var center: Vector3
	if along_x:
		size = Vector3(length, PLINTH_HEIGHT, PLINTH_DEPTH)
		center = Vector3(pos.x, PLINTH_HEIGHT * 0.5, pos.z + inward_z * (thickness * 0.5 + PLINTH_DEPTH * 0.5))
	else:
		size = Vector3(PLINTH_DEPTH, PLINTH_HEIGHT, length)
		center = Vector3(pos.x + inward_x * (thickness * 0.5 + PLINTH_DEPTH * 0.5), PLINTH_HEIGHT * 0.5, pos.z)
	_mesh(parent, "Plinth_" + wall.name, size, center, color.darkened(0.25))


static func _add_cornice(parent: Node3D, wall: Node3D, color: Color) -> void:
	var axes: Dictionary = _wall_axes(wall)
	var along_x: bool = axes["along_x"]
	var length: float = axes["length"]
	var thickness: float = axes["thickness"]
	var pos: Vector3 = wall.position
	var depth: float = thickness + CORNICE_OVERHANG * 2.0
	var size: Vector3
	if along_x:
		size = Vector3(length, CORNICE_HEIGHT, depth)
	else:
		size = Vector3(depth, CORNICE_HEIGHT, length)
	# Sits at the top of the wall, nudged 1 cm up so its top face does not fight the wall top.
	var center: Vector3 = Vector3(pos.x, WALL_HEIGHT - CORNICE_HEIGHT * 0.5 + 0.01, pos.z)
	_mesh(parent, "Cornice_" + wall.name, size, center, color.lightened(0.12))


static func _add_pilasters(parent: Node3D, wall: Node3D, color: Color) -> void:
	var axes: Dictionary = _wall_axes(wall)
	var along_x: bool = axes["along_x"]
	var length: float = axes["length"]
	var thickness: float = axes["thickness"]
	var inward_x: float = axes["inward_x"]
	var inward_z: float = axes["inward_z"]
	var pos: Vector3 = wall.position
	var color_dark: Color = color.darkened(0.1)
	var face_x: float = pos.x + inward_x * (thickness * 0.5 + PILASTER_DEPTH * 0.5)
	var face_z: float = pos.z + inward_z * (thickness * 0.5 + PILASTER_DEPTH * 0.5)
	var body_size: Vector3
	var capital_size: Vector3
	if along_x:
		body_size = Vector3(PILASTER_WIDTH, WALL_HEIGHT, PILASTER_DEPTH)
		capital_size = Vector3(CAPITAL_WIDTH, CAPITAL_HEIGHT, PILASTER_DEPTH)
	else:
		body_size = Vector3(PILASTER_DEPTH, WALL_HEIGHT, PILASTER_WIDTH)
		capital_size = Vector3(PILASTER_DEPTH, CAPITAL_HEIGHT, CAPITAL_WIDTH)
	var marks: PackedFloat32Array = _spacing_marks(length * 0.5, PILASTER_SPACING)
	var index: int = 0
	for mark: float in marks:
		var along: Vector3 = Vector3(mark, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, mark)
		var base: Vector3 = Vector3(face_x, 0.0, face_z) + along
		_mesh(parent, "Pilaster_%s_%d" % [wall.name, index], body_size, Vector3(base.x, WALL_HEIGHT * 0.5, base.z), color_dark)
		_mesh(parent, "Capital_%s_%d" % [wall.name, index], capital_size, Vector3(base.x, WALL_HEIGHT + CAPITAL_HEIGHT * 0.5, base.z), color_dark)
		index += 1


## Symmetric marks along a wall centred at 0, ~spacing apart.
static func _spacing_marks(half_len: float, spacing: float) -> PackedFloat32Array:
	var count: int = maxi(1, int(round(half_len * 2.0 / spacing)))
	var step: float = half_len * 2.0 / float(count)
	var marks: PackedFloat32Array = PackedFloat32Array()
	for i: int in count:
		marks.append(-half_len + (float(i) + 0.5) * step)
	return marks


static func _add_cover_tops(parent: Node3D, layout: Node3D, color: Color) -> void:
	var color_light: Color = color.lightened(0.2)
	for child: Node in layout.get_children():
		if not (child is CSGBox3D):
			continue
		var box: CSGBox3D = child as CSGBox3D
		if not box.is_in_group(&"cover"):
			continue
		var size: Vector3 = box.size
		var slab_size: Vector3 = Vector3(size.x + COVER_TOP_OVERHANG * 2.0, COVER_TOP_THICKNESS, size.z + COVER_TOP_OVERHANG * 2.0)
		var slab_pos: Vector3 = Vector3(box.position.x, box.position.y + size.y * 0.5 + COVER_TOP_THICKNESS * 0.5, box.position.z)
		_mesh(parent, "CoverTop_" + box.name, slab_size, slab_pos, color_light, box.rotation.y)


static func _add_props(parent: Node3D) -> void:
	# Corner pillars at the four arena corners.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_place_prop(parent, PILLAR_SCENE, "CornerPillar", Vector3(sx * ARENA_HALF_X, 0.0, sz * ARENA_HALF_Z), 0.0)
	# Spawn arches framing the back-wall openings, plus a brazier in each inner spawn corner.
	for sign_z: float in [-1.0, 1.0]:
		var z_wall: float = sign_z * (ARENA_HALF_Z + 0.5)
		var arch_yaw: float = 0.0 if sign_z > 0.0 else PI
		_place_prop(parent, ARCH_SCENE, "SpawnArch", Vector3(0.0, 0.0, z_wall), arch_yaw)
		for sx: float in [-1.0, 1.0]:
			_place_prop(parent, BRAZIER_SCENE, "Brazier", Vector3(sx * 3.2, 0.0, sign_z * ARENA_HALF_Z), 0.0)
	# Banners hung on the side walls ~12 m apart, alternating sides (180° symmetric).
	var banner_zs: Array[float] = [-18.0, -6.0, 6.0, 18.0]
	for i: int in banner_zs.size():
		var on_west: bool = i % 2 == 0
		var x: float = -ARENA_HALF_X if on_west else ARENA_HALF_X
		var yaw: float = -PI * 0.5 if on_west else PI * 0.5
		_place_prop(parent, BANNER_SCENE, "Banner%d" % i, Vector3(x, BANNER_TOP_HEIGHT - BANNER_HEIGHT_M, banner_zs[i]), yaw)


static func _place_prop(parent: Node3D, scene: PackedScene, prop_name: String, pos: Vector3, yaw: float) -> void:
	var instance: Node3D = scene.instantiate() as Node3D
	instance.name = prop_name
	instance.position = pos
	instance.rotation.y = yaw
	parent.add_child(instance)


static func _mesh(parent: Node3D, mesh_name: String, size: Vector3, pos: Vector3, color: Color, yaw: float = 0.0) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = mesh_name
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = pos
	instance.rotation.y = yaw
	instance.material_override = Toon.material(color)
	parent.add_child(instance)
