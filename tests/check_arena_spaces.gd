extends Node3D

var failures: int = 0


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _ready() -> void:
	var layout: ArenaBuilder = ArenaBuilder.new()
	var spaces: ArenaSpaces = ArenaSpaces.new()
	spaces.solids = ArenaSpaces.mirrored([ArenaSpaces.solid(0, -16, 6, 3.5, 2)])
	spaces.routes = {"west": PackedVector3Array([Vector3(-5, 0, -14), Vector3(-5, 0, 0), Vector3.ZERO]), "east": PackedVector3Array([Vector3(5, 0, -14), Vector3(5, 0, 0), Vector3.ZERO])}
	layout.spaces = spaces
	add_child(layout)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(spaces.validate().is_empty(), "data validation")
	check(ArenaMetrics.spawn_leaks(get_world_3d(), spaces) > 0, "detect exposed spawn borders beside 6 m baffle")
	spaces.solids = ArenaSpaces.mirrored([ArenaSpaces.solid(0, -16, 7, 3.5, 2)])
	layout.build()
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(ArenaMetrics.spawn_leaks(get_world_3d(), spaces) == 0, "7 m baffle protects spawn borders")
	for key: String in spaces.routes:
		check(ArenaMetrics.route_clear(get_world_3d(), spaces.routes[key]), "capsule route " + key)
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(6, 3, 0.5)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(-5, 1.5, -7)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not ArenaMetrics.route_clear(get_world_3d(), spaces.routes["west"]), "barrier blocks west")
	check(ArenaMetrics.route_clear(get_world_3d(), spaces.routes["east"]), "barrier leaves east open")
	print("ARENA_SPACES: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
