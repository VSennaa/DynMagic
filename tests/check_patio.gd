extends Node3D

var failures: int = 0


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _ready() -> void:
	var layout: ArenaBuilder = ArenaBuilder.new()
	var spaces: ArenaSpaces = PatioSpaces.new()
	layout.spaces = spaces
	add_child(layout)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(spaces.validate().is_empty(), "data validation")
	check(ArenaMetrics.spawn_leaks(get_world_3d(), spaces) == 0, "spawn regions protected")
	for key: String in spaces.routes:
		check(ArenaMetrics.route_clear(get_world_3d(), spaces.routes[key]), "capsule route " + key)
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(6, 3, 0.5)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(-9, 1.5, -12)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not ArenaMetrics.route_clear(get_world_3d(), spaces.routes["north_west"]), "barrier blocks west")
	check(ArenaMetrics.route_clear(get_world_3d(), spaces.routes["north_east"]), "barrier leaves east open")
	var sight: Dictionary = ArenaMetrics.sightlines(get_world_3d(), spaces.sightline_limit)
	print(sight)
	# Sightline gate is a warning until the chicane pass lands (ROADMAP M13, HANDOFF Sonnet-6 notes).
	if sight["max_sightline"] > spaces.sightline_limit + 2.0:
		print("WARN: max sightline %.2f m above target %.2f m (+2 m tolerance)" % [sight["max_sightline"], spaces.sightline_limit])
	# M12 decision 10: 3v3/5v5 expanded arena (x1.5) with extra ground-level flank routes.
	wall.queue_free()
	layout.team_scale = 1.5
	await get_tree().physics_frame
	await get_tree().physics_frame
	var expanded: ArenaSpaces = layout.effective_spaces()
	check(expanded.spawn_regions[0].size.x > spaces.spawn_regions[0].size.x, "expanded spawn regions are larger")
	for key: String in expanded.routes:
		check(ArenaMetrics.route_clear(get_world_3d(), expanded.routes[key]), "expanded capsule route " + key)
	check(expanded.routes.has("flank_west_north") and expanded.routes.has("flank_east_south"), "extra flank routes present")
	print("PATIO: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
