@tool
extends McpTestSuite
## Stats rules from docs/specs/05-player-controller.md section 3.

var stats: Stats


func suite_name() -> String:
	return "stats"


func setup() -> void:
	stats = Stats.new()
	stats.reset()


func teardown() -> void:
	stats.free()


func test_starts_full() -> void:
	assert_eq(stats.hp, 100.0)
	assert_eq(stats.mana, 100.0)
	assert_eq(stats.shield, 0.0)


func test_damage_reduces_hp_and_kills() -> void:
	assert_eq(stats.take_damage(30.0), 30.0)
	assert_eq(stats.hp, 70.0)
	assert_eq(stats.take_damage(500.0), 70.0)
	assert_true(stats.is_dead)
	assert_eq(stats.take_damage(10.0), 0.0, "dead players take no damage")


func test_shield_absorbs_first() -> void:
	stats.add_shield(30.0, 3.0)
	assert_eq(stats.take_damage(20.0), 0.0)
	assert_eq(stats.shield, 10.0)
	assert_eq(stats.take_damage(25.0), 15.0)
	assert_eq(stats.shield, 0.0)
	assert_eq(stats.hp, 85.0)


func test_shield_expires() -> void:
	stats.add_shield(30.0, 3.0)
	stats.tick(3.1)
	assert_eq(stats.shield, 0.0)


func test_mana_regen_pauses_after_cast() -> void:
	assert_true(stats.spend_mana(40.0))
	assert_eq(stats.mana, 60.0)
	stats.tick(0.4)
	assert_eq(stats.mana, 60.0, "regen paused for 0.5 s")
	stats.tick(0.1)
	stats.tick(1.0)
	assert_true(absf(stats.mana - 72.0) < 0.001, "12 mana per second, got %f" % stats.mana)


func test_cannot_overspend() -> void:
	assert_false(stats.spend_mana(120.0))
	assert_eq(stats.mana, 100.0)


func test_mana_caps_at_max() -> void:
	stats.spend_mana(1.0)
	stats.tick(10.0)
	stats.tick(10.0)
	assert_eq(stats.mana, 100.0)


func test_status_duration_stacks_to_cap() -> void:
	stats.apply_status(&"slow", 1.5)
	stats.apply_status(&"slow", 1.5)
	stats.apply_status(&"slow", 1.5)
	assert_eq(stats.status_time_left(&"slow"), 3.0, "cap is 2x duration")
	stats.tick(3.1)
	assert_false(stats.has_status(&"slow"))


func test_cooldowns() -> void:
	stats.start_cooldown(&"area_burst", 6.0)
	assert_true(stats.is_on_cooldown(&"area_burst"))
	stats.tick(5.9)
	assert_true(stats.is_on_cooldown(&"area_burst"))
	stats.tick(0.2)
	assert_false(stats.is_on_cooldown(&"area_burst"))


func test_reset_clears_everything() -> void:
	stats.take_damage(50.0)
	stats.spend_mana(50.0)
	stats.apply_status(&"burn", 3.0)
	stats.start_cooldown(&"projectile_direct", 1.0)
	stats.reset()
	assert_eq(stats.hp, 100.0)
	assert_eq(stats.mana, 100.0)
	assert_false(stats.has_status(&"burn"))
	assert_false(stats.is_on_cooldown(&"projectile_direct"))


func test_reserved_mana_cannot_be_spent() -> void:
	var stats: Stats = Stats.new()
	stats.mana = 50.0
	assert_true(stats.can_afford(30.0, 20.0), "50 - 20 reserved covers 30")
	assert_false(stats.can_afford(31.0, 20.0), "50 - 20 reserved does not cover 31")
	assert_true(stats.can_afford(50.0), "no reservation by default")
	stats.free()
