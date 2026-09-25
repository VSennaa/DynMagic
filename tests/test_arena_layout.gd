@tool
extends McpTestSuite
## Arena half-map mirroring and sight lines (docs/specs/03-arenas.md sections 1, 5 and 6).

const SPAWN_Z: float = ArenaBuilder.ARENA_Z * 0.5 + ArenaBuilder.SPAWN_SIZE * 0.5
const EYE_HEIGHT: float = 1.6


func suite_name() -> String:
	return "arena_layout"


func test_mirror_doubles_off_centre_entries() -> void:
	for variant: StringName in ArenaBuilder.VARIANTS:
		var half: Array = ArenaBuilder.LAYOUTS[variant]
		var full: Array = ArenaBuilder.mirrored_layout(variant)
		var centred: int = 0
		for entry: Array in half:
			if absf(float(entry[0])) < 0.001 and absf(float(entry[1])) < 0.001:
				centred += 1
		assert_eq(full.size(), half.size() * 2 - centred, "variant %s" % variant)


func test_every_entry_has_its_180_degree_twin() -> void:
	for variant: StringName in ArenaBuilder.VARIANTS:
		var full: Array = ArenaBuilder.mirrored_layout(variant)
		for entry: Array in full:
			var found: bool = false
			for other: Array in full:
				if absf(float(other[0]) + float(entry[0])) < 0.001 and absf(float(other[1]) + float(entry[1])) < 0.001 \
						and is_equal_approx(float(other[3]), float(entry[3])):
					found = true
					break
			assert_true(found, "%s: no mirror twin for %s" % [variant, entry])


func test_cover_stays_inside_the_arena() -> void:
	for variant: StringName in ArenaBuilder.VARIANTS:
		for entry: Array in ArenaBuilder.mirrored_layout(variant):
			assert_true(absf(float(entry[0])) <= ArenaBuilder.ARENA_X * 0.5, "%s x out of bounds: %s" % [variant, entry])
			assert_true(absf(float(entry[1])) <= ArenaBuilder.ARENA_Z * 0.5, "%s z out of bounds: %s" % [variant, entry])


## Spec 03 §6: no line of sight from one spawn to the other (eye height, straight line).
func test_no_spawn_to_spawn_line_of_sight() -> void:
	var from: Vector2 = Vector2(0.0, -SPAWN_Z)
	var to: Vector2 = Vector2(0.0, SPAWN_Z)
	for variant: StringName in ArenaBuilder.VARIANTS:
		var blocked: bool = false
		for entry: Array in ArenaBuilder.mirrored_layout(variant):
			if float(entry[3]) >= EYE_HEIGHT and _segment_hits_box(from, to, entry):
				blocked = true
				break
		assert_true(blocked, "variant %s has a clear spawn-to-spawn line" % variant)


## 2D test: does segment a-b cross the rotated rectangle of a cover entry (top view)?
func _segment_hits_box(a: Vector2, b: Vector2, entry: Array) -> bool:
	var center: Vector2 = Vector2(float(entry[0]), float(entry[1]))
	var half: Vector2 = Vector2(float(entry[2]), float(entry[4])) * 0.5
	# Godot rotates +Y counter-clockwise seen from above; in (x, z) that is rotation by -angle.
	var angle: float = -deg_to_rad(float(entry[5]))
	var la: Vector2 = (a - center).rotated(-angle)
	var lb: Vector2 = (b - center).rotated(-angle)
	var steps: int = 400
	for i: int in steps + 1:
		var p: Vector2 = la.lerp(lb, float(i) / steps)
		if absf(p.x) <= half.x and absf(p.y) <= half.y:
			return true
	return false
