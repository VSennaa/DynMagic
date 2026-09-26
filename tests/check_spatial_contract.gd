extends Node3D
## Run with check_spatial_contract.tscn: real physics, not mocked ray queries.

var failures: int = 0


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _ready() -> void:
	var dummy: TrainingDummy = preload("res://scenes/sandbox/training_dummy.tscn").instantiate() as TrainingDummy
	dummy.position = Vector3(0, 0, -1.5)
	add_child(dummy)
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, 2, -0.75)
	add_child(body)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(SpatialContract.exposure(get_world_3d(), Vector3(0, 0.9, 0), dummy) == 0.0, "solid stops blast")
	check(not SpatialContract.clear_path(get_world_3d(), Vector3(0, 0.9, 0), dummy.position + Vector3.UP * 0.9, dummy), "solid stops melee")
	check(SpatialContract.exposure(get_world_3d(), Vector3(0, 0.05, -1), dummy) == 1.0, "seed behind cover reaches target")
	box.size.y = 0.6
	body.position.y = 0.3
	await get_tree().physics_frame
	await get_tree().physics_frame
	var partial: float = SpatialContract.exposure(get_world_3d(), Vector3(0, 0.9, 0), dummy)
	check(partial > 0.0 and partial < 1.0, "partial cover scales blast")
	body.collision_layer = 2
	box.size.y = 4
	body.position.y = 2
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(SpatialContract.exposure(get_world_3d(), Vector3(0, 0.9, 0), dummy) == 0.0, "wind barrier stops blast")
	print("SPATIAL: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
