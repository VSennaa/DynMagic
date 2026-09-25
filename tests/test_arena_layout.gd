@tool
extends McpTestSuite
## Arena half-map mirroring (docs/specs/03-arenas.md sections 1 and 5).


func suite_name() -> String:
	return "arena_layout"


func test_mirror_doubles_off_centre_entries() -> void:
	var half: Array = ArenaBuilder.LAYOUTS[&"A"]
	var full: Array = ArenaBuilder.mirrored_layout(&"A")
	var centred: int = 0
	for entry: Array in half:
		if absf(float(entry[0])) < 0.001 and absf(float(entry[1])) < 0.001:
			centred += 1
	assert_eq(full.size(), half.size() * 2 - centred)


func test_every_entry_has_its_180_degree_twin() -> void:
	var full: Array = ArenaBuilder.mirrored_layout(&"A")
	for entry: Array in full:
		var found: bool = false
		for other: Array in full:
			if absf(float(other[0]) + float(entry[0])) < 0.001 and absf(float(other[1]) + float(entry[1])) < 0.001 \
					and is_equal_approx(float(other[3]), float(entry[3])):
				found = true
				break
		assert_true(found, "no mirror twin for %s" % [entry])


func test_cover_stays_inside_the_arena() -> void:
	for entry: Array in ArenaBuilder.mirrored_layout(&"A"):
		assert_true(absf(float(entry[0])) <= ArenaBuilder.ARENA_X * 0.5, "x out of bounds: %s" % [entry])
		assert_true(absf(float(entry[1])) <= ArenaBuilder.ARENA_Z * 0.5, "z out of bounds: %s" % [entry])
