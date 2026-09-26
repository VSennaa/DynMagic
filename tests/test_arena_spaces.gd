@tool
extends McpTestSuite


func suite_name() -> String:
	return "arena_spaces"


func test_bounds_include_rotated_corners() -> void:
	var spaces: ArenaSpaces = ArenaSpaces.new()
	var piece: Dictionary = ArenaSpaces.solid(12.5, -10, 3, 2.2, 3)
	piece["yaw"] = PI / 4
	spaces.solids = [piece]
	assert_false(spaces.validate().is_empty(), "centre inside is not enough")


func test_core_disc_must_be_free() -> void:
	var spaces: ArenaSpaces = ArenaSpaces.new()
	spaces.solids = [ArenaSpaces.solid(0, 0, 3, 3, 3)]
	assert_false(spaces.validate().is_empty())


func test_mirror_preserves_height_and_rotates_yaw() -> void:
	var pieces: Array[Dictionary] = ArenaSpaces.mirrored([ArenaSpaces.solid(-4, -3, 2, 3.5, 4)])
	assert_eq(pieces.size(), 2)
	assert_eq(pieces[1]["position"], Vector3(4, 0, 3))
	assert_eq(pieces[1]["size"], Vector3(2, 3.5, 4))
	assert_eq(pieces[1]["yaw"], PI)


func test_corridor_clearance_is_measured_along_route() -> void:
	var spaces: ArenaSpaces = ArenaSpaces.new()
	spaces.solids = [ArenaSpaces.solid(-4, -10, 2, 2.2, 4)]
	spaces.routes = {"narrow": PackedVector3Array([Vector3(-2, 0, -14), Vector3(-2, 0, -6)])}
	assert_false(spaces.validate().is_empty())
	spaces.routes = {"clear": PackedVector3Array([Vector3(0, 0, -14), Vector3(0, 0, -6)])}
	assert_true(spaces.validate().is_empty())
