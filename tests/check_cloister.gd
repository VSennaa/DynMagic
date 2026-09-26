extends Node3D

var failures: int = 0


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _ready() -> void:
	var layout: ArenaBuilder = ArenaBuilder.new()
	var spaces: ArenaSpaces = CloisterSpaces.new()
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
	wall.position = Vector3(-7, 1.5, -3)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not ArenaMetrics.route_clear(get_world_3d(), spaces.routes["north_west"]), "barrier blocks west")
	check(ArenaMetrics.route_clear(get_world_3d(), spaces.routes["north_east"]), "barrier leaves east open")
	print(ArenaMetrics.sightlines(get_world_3d(), spaces.sightline_limit))
	print("CLOISTER: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
