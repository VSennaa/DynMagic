@tool
extends McpTestSuite

func suite_name() -> String:
	return "reconnect_stats"


func test_bootstrap_preserves_health_mana_status_and_cooldowns() -> void:
	var original: Stats = Stats.new()
	original.hp = 37.0
	original.max_mana = 130.0
	original.mana = 42.0
	original.add_shield(20.0, 3.0)
	original.apply_status(&"slow", 2.0)
	original.start_cooldown(&"projectile_direct", 4.0)
	var restored: Stats = Stats.new()
	restored.import_state(original.export_state())
	assert_eq(restored.export_state(), original.export_state())
	restored.tick(0.5)
	assert_ne(restored.export_state(), original.export_state(), "bootstrap dictionaries do not alias the host")
	original.free()
	restored.free()
