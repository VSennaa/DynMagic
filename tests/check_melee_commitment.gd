extends Node3D
## Headless check for the M11 staff swing: hits in front within reach, misses behind and far.

const PLAYER: PackedScene = preload("res://scenes/player/player.tscn")
const DUMMY: PackedScene = preload("res://scenes/sandbox/training_dummy.tscn")


func _ready() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(shape)
	add_child(floor_body)
	var player: Player = PLAYER.instantiate() as Player
	player.is_local = false
	add_child(player)
	var results: PackedStringArray = PackedStringArray()
	var failures: int = 0
	for case: Array in [["front 1.2 m", Vector3(0, 0, -1.2), true], ["behind", Vector3(0, 0, 1.2), false], ["far 4 m", Vector3(0, 0, -4.0), false], ["side 30 deg", Vector3(0.6, 0, -1.0), true]]:
		var dummy: TrainingDummy = DUMMY.instantiate() as TrainingDummy
		dummy.position = case[1]
		add_child(dummy)
		await get_tree().physics_frame
		await get_tree().physics_frame
		player._melee_cooldown = 0.0
		player.cast_lockout = 0.0
		player.perform_melee()
		player.simulate(0.1, Vector2.ZERO, false, false, false)
		if dummy.total_damage != 0.0:
			failures += 1
		player.simulate(0.021, Vector2.ZERO, false, false, false)
		if player._validate_cast(SpellDB.resolve(&"fire", &"projectile", &"direct")) != &"lockout":
			failures += 1
		var hit: bool = dummy.total_damage > 0.0
		var ok: bool = hit == bool(case[2])
		failures += 0 if ok else 1
		results.append("%s %s (damage %.1f)" % ["OK  " if ok else "FAIL", case[0], dummy.total_damage])
		dummy.queue_free()
		await get_tree().process_frame
	player._melee_cooldown = 0.0
	player.perform_melee()
	results.append("%s cooldown blocks a second swing" % ["OK  " if not player.can_melee() else "FAIL"])
	failures += 0 if not player.can_melee() else 1
	print("\n".join(results))
	print("MELEE_CHECKS: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)
