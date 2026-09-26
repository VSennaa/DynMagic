extends Node3D

var failures: int = 0


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _ready() -> void:
	var player: Player = preload("res://scenes/player/player.tscn").instantiate() as Player
	player.is_local = false
	add_child(player)
	player.set_physics_process(false)
	player.stats.set_physics_process(false)
	player.receive_status(SpellDB.resolve(&"fire", &"projectile", &"direct"))
	player.receive_status(SpellDB.resolve(&"fire", &"projectile", &"direct"))
	check(player.stats.status_time_left(&"burn") == 3.0, "burn refresh capped at 3 s")
	player.receive_hit(20, SpellDB.resolve(&"fire", &"area", &"direct"), null)
	check(player.stats.hp == 74.0 and not player.stats.has_status(&"burn"), "cone converts half remaining burn without extra total damage")
	player.reset_round()
	var root: ResolvedSpell = SpellDB.resolve(&"frost", &"area", &"burst").with_status(&"root", 0.6)
	player.receive_status(root)
	check(player.speed_mult() == 0.0, "root immobilizes")
	player.stats.tick(0.61)
	player.receive_status(root)
	player.receive_status(SpellDB.resolve(&"frost", &"area", &"direct"))
	check(not player.stats.has_status(&"root") and not player.stats.has_status(&"slow"), "root recovery blocks repeat control")
	player.stats.tick(1.0)
	player.receive_status(root)
	check(player.stats.has_status(&"root"), "control returns after recovery")
	player.reset_round()
	player.receive_status(SpellDB.resolve(&"storm", &"projectile", &"lingering"))
	player.receive_hit(5, null, null)
	check(player.stats.has_status(&"shock") and player.stats.hp == 95, "melee cannot consume shock")
	player.receive_hit(5, SpellDB.resolve(&"fire", &"projectile", &"lingering"), null)
	check(player.stats.has_status(&"shock") and player.stats.hp == 90, "zone cannot consume shock")
	player.receive_hit(10, SpellDB.resolve(&"storm", &"projectile", &"direct"), null)
	check(not player.stats.has_status(&"shock") and player.stats.hp == 78, "direct impact converts shock once")
	player.reset_round()
	player.active_guard = SpellDB.resolve(&"wind", &"self", &"direct")
	player.stats.add_shield(30, 2.5)
	player.receive_hit(10, SpellDB.resolve(&"storm", &"projectile", &"direct"), null)
	check(player.stats.shield == 20, "wind guard after opening is ordinary shield")
	var zone: Zone = preload("res://scenes/spells/zone.tscn").instantiate() as Zone
	zone.setup(SpellDB.resolve(&"fire", &"projectile", &"lingering").with_params({"strip": true, "zone_radius": 3.2}), player, Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO)
	add_child(zone)
	check(zone.affects(Vector3(0, 0, -2.9)), "strip reaches along aim")
	check(not zone.affects(Vector3(1.1, 0, 0)), "strip has 2 m width")
	check(not zone.affects(Vector3(0, 1.5, 0)), "strip excludes upper floor")
	print("ELEMENT_PLANS: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
