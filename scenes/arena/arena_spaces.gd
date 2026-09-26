@tool
class_name ArenaSpaces
extends Resource
## Authored playable geometry. All positions are floor-relative, in metres.
## A solid is {position: Vector3, size: Vector3, yaw: float}; platforms use the same schema.
## Ramps are {position: Vector3 (floor centre), width, length, height, yaw}.

@export var solids: Array[Dictionary] = []
@export var platforms: Array[Dictionary] = []
@export var ramps: Array[Dictionary] = []
@export var core_anchor: Vector3 = Vector3.ZERO
@export var spawn_regions: Array[AABB] = [AABB(Vector3(-3.5, 0, -26), Vector3(7, 1.8, 7)), AABB(Vector3(-3.5, 0, 19), Vector3(7, 1.8, 7))]
@export var routes: Dictionary = {}
@export var exits: Array[Vector3] = [Vector3(-3.5, 0, -18), Vector3(3.5, 0, -18), Vector3(3.5, 0, 18), Vector3(-3.5, 0, 18)]
@export var sightline_limit: float = 18.0

const MIN_PASSAGE: float = 2.5
const MAIN_PASSAGE: float = 3.0
const MAX_STEP: float = 0.3
const OPTIONAL_JUMP: float = 1.0


static func mirrored(half: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for piece: Dictionary in half:
		result.append(piece.duplicate(true))
		var pos: Vector3 = piece["position"]
		if Vector2(pos.x, pos.z).length() < 0.001:
			continue
		var twin: Dictionary = piece.duplicate(true)
		twin["position"] = Vector3(-pos.x, pos.y, -pos.z)
		twin["yaw"] = float(piece.get("yaw", 0.0)) + PI
		result.append(twin)
	return result


static func solid(x: float, z: float, width: float, height: float, depth: float) -> Dictionary:
	return {"position": Vector3(x, 0, z), "size": Vector3(width, height, depth), "yaw": 0.0}


## Exact rotated footprint, expanded by clearance for corridor/capsule tests.
static func contains_xz(piece: Dictionary, point: Vector3, clearance: float = 0.0) -> bool:
	var local: Vector3 = (point - (piece["position"] as Vector3)).rotated(Vector3.UP, -float(piece.get("yaw", 0.0)))
	var half: Vector3 = (piece["size"] as Vector3) * 0.5
	return absf(local.x) < half.x + clearance and absf(local.z) < half.z + clearance


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	for piece: Dictionary in solids + platforms:
		var pos: Vector3 = piece["position"]
		var size: Vector3 = piece["size"]
		var yaw: float = float(piece.get("yaw", 0.0))
		var extent: Vector2 = Vector2(absf(cos(yaw)) * size.x + absf(sin(yaw)) * size.z, absf(sin(yaw)) * size.x + absf(cos(yaw)) * size.z) * 0.5
		if absf(pos.x) + extent.x > 14.001 or absf(pos.z) + extent.y > 19.001:
			errors.append("Solid outside arena: %s" % pos)
		# Nearest point on an oriented box to the capture disc.
		var local: Vector3 = (core_anchor - pos).rotated(Vector3.UP, -yaw)
		var distance: Vector2 = Vector2(maxf(absf(local.x) - size.x * 0.5, 0), maxf(absf(local.z) - size.z * 0.5, 0))
		if distance.length() < ArcaneCore.RADIUS:
			errors.append("Solid intersects capture disc: %s" % pos)
	for ramp: Dictionary in ramps:
		if float(ramp["width"]) < MAIN_PASSAGE or float(ramp["height"]) / float(ramp["length"]) > 0.5:
			errors.append("Ramp too narrow or steep")
	for key: String in routes:
		var points: PackedVector3Array = routes[key]
		for i: int in range(1, points.size()):
			var steps: int = maxi(1, ceili(points[i - 1].distance_to(points[i]) / 0.25))
			for step: int in steps + 1:
				var point: Vector3 = points[i - 1].lerp(points[i], float(step) / steps)
				for piece: Dictionary in solids + platforms:
					if contains_xz(piece, point, MIN_PASSAGE * 0.5):
						errors.append("Route %s lacks 2.5 m clearance at %s" % [key, point])
						break
	return errors
