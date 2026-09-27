@tool
extends McpTestSuite

func suite_name() -> String:
	return "round_memory"

func test_act_boundaries_and_pause() -> void:
	var f: MatchFsm = MatchFsm.new()
	f.start([1, 2])
	f.mark_loaded(1)
	f.mark_loaded(2)
	f.tick(30.0)
	f.tick(3.0)
	assert_eq(f.combat_act(), &"scouting")
	f.tick(20.0)
	assert_eq(f.combat_act(), &"announcement")
	assert_false(f.core_spawned)
	f.tick(10.0)
	assert_eq(f.combat_act(), &"conversion")
	assert_true(f.core_spawned)
	f.player_disconnected(2)
	f.tick(5.0)
	f.player_reconnected()
	assert_eq(f.time_left, 60.0)
	f.tick(30.0)
	assert_eq(f.combat_act(), &"convergence")
	f.tick(30.0)
	assert_eq(f.phase, MatchFsm.Phase.OVERTIME)
	assert_eq(f.time_left, 60.0, "absolute timeout and tie rules remain unchanged")

func test_offers_cover_three_adaptation_categories() -> void:
	var f: MatchFsm = MatchFsm.new()
	for seed_value: int in 64:
		f.rng.seed = seed_value
		var offer: Array = f.adaptation_offer()
		assert_true(offer[0] in [&"breath", &"echo"])
		assert_true(offer[1] in [&"light_step", &"focus"])
		assert_eq(offer[2], &"husk")

func test_team_rematches_and_secret_shared_decisive_offer() -> void:
	for size: int in [2, 3]:
		var f: TeamMatchFsm = TeamMatchFsm.new()
		f.team_size = size
		var ids: Array[int] = []
		for id: int in range(1, size * 2 + 1):
			ids.append(id)
		f.start(ids)
		for id: int in ids:
			f.mark_loaded(id)
		var first_north: int = f.north_id
		for round_index: int in 7:
			assert_eq(f.arena, MatchFsm.REMATCH_ROTATION[round_index])
			assert_eq(f.north_id, first_north if round_index % 2 == 0 else f.other(first_north))
			if round_index > 0:
				assert_true(f.runes.is_empty(), "no stacking")
				for id: int in ids:
					assert_eq(f.rune_offers.has(id), f.decisive or f.teams[id] == f.teams[f.last_round_loser])
			if round_index == 6:
				assert_true(f.decisive)
				for id: int in ids:
					assert_eq(f.rune_offers[id], f.rune_offers[1])
					f.pick_rune(id, f.rune_offers[id][id % 3])
				assert_eq(f.visible_runes(1).size(), 1)
				assert_true(f.visible_runes(999).is_empty(), "spectators receive no secrets")
			f.tick(30.0)
			assert_eq(f.visible_runes(999).size(), f.runes.size(), "reveal at countdown")
			f.tick(3.0)
			if round_index < 6:
				var dead: Array[int] = []
				for id: int in ids:
					if f.teams[id] == round_index % 2:
						dead.append(id)
				f.resolve_deaths(dead, {})
				assert_eq(f.previous_round["reason"], &"kill")
				f.tick(3.0)

func test_fixed_and_random_arenas_preserve_legacy_decisive_lottery() -> void:
	var f: MatchFsm = MatchFsm.new()
	f.round_number = 7
	for arena: StringName in MatchFsm.ARENAS:
		f.arena_setting = arena
		assert_eq(f._choose_arena(), arena)
	f.arena = &"B"
	f.decisive = true
	for setting: StringName in [&"A", &"B", &"C", &"random"]:
		f.arena_setting = setting
		for i: int in 16:
			assert_ne(f._choose_arena(), &"B", "non-rotation decisive retains its old lottery")

func test_core_contest_exit_grace_decay_damage_and_one_capture() -> void:
	var c: ArcaneCore = ArcaneCore.new()
	c.capture_enabled = false
	c.advance_capture(5.0, [1], false)
	assert_eq(c.progress_ratio(1), 0.0)
	c.capture_enabled = true
	c.advance_capture(1.5, [1], false)
	c.advance_capture(4.0, [1, 2], true)
	assert_eq(c.progress[1], 1.5)
	assert_eq(c.progress_ratio(2), 0.0)
	c.advance_capture(0.8, [], false)
	assert_eq(c.progress[1], 1.5)
	c.advance_capture(0.7, [], false)
	assert_eq(c.progress[1], 1.0)
	c.advance_capture(0.1, [1], false, [1])
	assert_eq(c.progress[1], 0.0)
	c.advance_capture(2.5, [2], false)
	assert_true(c._done)
	c.advance_capture(10.0, [1], false)
	assert_eq(c.progress[1], 0.0, "one reward per round")
	c.free()

func test_core_allies_progress_without_acceleration_and_reconnect() -> void:
	var c: ArcaneCore = ArcaneCore.new()
	c.advance_capture(1.0, [1, 3], false)
	assert_eq(c.progress[1], 1.0)
	assert_eq(c.progress[3], 1.0)
	c.advance_capture(0.8, [3], false)
	c.replace_player(1, 9)
	c.advance_capture(0.7, [3], true)
	assert_eq(c.progress[9], 0.5, "exit grace survives reconnect")
	assert_false(c.progress.has(1))
	c.free()

func test_collapse_final_close_and_variant_isolation() -> void:
	var c: CollapseZone = CollapseZone.new()
	c.elapsed = 20.0
	assert_eq(c.radius(), 5.0)
	c.elapsed = 35.0
	assert_eq(c.radius(), 2.0)
	c.elapsed = 60.0
	assert_eq(c.radius(), 2.0)
	c.final_shrink = false
	assert_eq(c.radius(), 5.0)
	c.warning_only = true
	c.elapsed = 0.0
	assert_eq(c.radius(), 5.0)
	c.free()

func test_overcharge_preserves_base_reservation_damage_and_cooldowns() -> void:
	var p: Player = Player.new()
	var stats: Stats = Stats.new()
	var composer: SpellComposer = SpellComposer.new()
	p.stats = stats
	p.composer = composer
	stats.reset()
	var spell: ResolvedSpell = ResolvedSpell.new()
	spell.mana_cost = 40.0
	spell.cooldown = 5.0
	composer.stored = spell
	var damage: float = p.damage_mult()
	var cooldown: float = p.cooldown_for(spell)
	p.grant_overcharge()
	assert_eq(p.reserved_mana(), 40.0)
	assert_eq(p.mana_cost_for(spell, false), 0.0)
	assert_eq(p.damage_mult(), damage)
	assert_eq(p.cooldown_for(spell), cooldown)
	assert_eq(p.overcharge_casts, 3)
	p.overcharge_time = 0.0
	assert_eq(p.reserved_mana(), 40.0)
	assert_eq(p.mana_cost_for(spell, false), 40.0)
	composer.stored = null
	assert_eq(p.reserved_mana(), 0.0)
	composer.free()
	stats.free()
	p.free()

func test_replicated_side_swap_for_duels_and_teams() -> void:
	assert_true(TeamRules.at_north(1, 1, {}))
	assert_false(TeamRules.at_north(1, 77, {}))
	assert_true(TeamRules.at_north(77, 77, {}))
	var teams: Dictionary = {1: 0, 2: 1, 3: 0, 4: 1, 5: 0, 6: 1}
	assert_true(TeamRules.at_north(3, 1, teams))
	assert_false(TeamRules.at_north(3, 2, teams))
	assert_true(TeamRules.at_north(6, 2, teams))
