@tool
extends McpTestSuite
## ControlMatchFsm (M12 decisions 4-6): capture-to-100% rounds, best-of-3, wave respawn, no rune.

var fsm: ControlMatchFsm
var round_winners: Array[int] = []
var respawned: Array[int] = []
var _match_winner: int = -1


func suite_name() -> String:
	return "control_match_fsm"


func _team(team: int) -> Array[int]:
	var out: Array[int] = []
	for id: int in fsm.players:
		if fsm.teams[id] == team:
			out.append(id)
	return out


func _draft_to_combat() -> void:
	var north_team: Array[int] = _team(fsm.teams[fsm.north_id])
	var south_team: Array[int] = _team(fsm.teams[fsm.south_id()])
	var elements: Array[StringName] = [&"fire", &"frost", &"storm", &"wind", &"fire"]
	for i: int in north_team.size():
		fsm.pick_element(north_team[i], elements[i])
	for i: int in south_team.size():
		fsm.pick_element(south_team[i], elements[i])
	for id: int in fsm.players:
		fsm.confirm_draft(id)
	fsm.tick(4.0)  # countdown -> combat


func setup() -> void:
	fsm = ControlMatchFsm.new()
	fsm.rng.seed = 42
	fsm.team_size = 5
	round_winners.clear()
	respawned.clear()
	_match_winner = -1
	fsm.round_ended.connect(func(w: int, _r: StringName) -> void: round_winners.append(w))
	fsm.player_respawn_ready.connect(func(id: int) -> void: respawned.append(id))
	var ids: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	fsm.start(ids, &"random")
	for id: int in ids:
		fsm.mark_loaded(id)
	_draft_to_combat()


func test_combat_starts_with_no_rune_offers() -> void:
	assert_true(fsm.rune_offers.is_empty())
	assert_true(fsm.runes.is_empty())


func test_death_does_not_end_the_round() -> void:
	assert_eq(fsm.phase, ControlMatchFsm.Phase.COMBAT)
	fsm.resolve_deaths([fsm.north_id], {})
	assert_eq(round_winners.size(), 0)
	assert_eq(fsm.phase, ControlMatchFsm.Phase.COMBAT)


func test_death_schedules_a_ten_second_wave_respawn() -> void:
	fsm.resolve_deaths([fsm.north_id], {})
	assert_eq(fsm.respawn_at[fsm.north_id], ControlMatchFsm.WAVE_RESPAWN_TIME)
	fsm.tick(9.9)
	assert_true(fsm.respawn_at.has(fsm.north_id))
	assert_eq(respawned.size(), 0)
	fsm.tick(0.2)
	assert_false(fsm.respawn_at.has(fsm.north_id))
	assert_eq(respawned, [fsm.north_id])


func test_capture_completed_ends_the_round_for_that_team() -> void:
	var north_team: int = fsm.teams[fsm.north_id]
	fsm.capture_completed(north_team)
	assert_eq(round_winners.size(), 1)
	assert_eq(fsm.teams[round_winners[0]], north_team)
	assert_eq(fsm.score[fsm.north_id], 1)


func test_capture_completed_is_ignored_outside_combat_or_overtime() -> void:
	fsm.phase = ControlMatchFsm.Phase.DRAFT
	fsm.capture_completed(0)
	assert_eq(round_winners.size(), 0)


func test_overtime_timeout_breaks_tie_on_higher_capture_percent() -> void:
	fsm.phase = ControlMatchFsm.Phase.OVERTIME
	var north_team: int = fsm.teams[fsm.north_id]
	fsm.update_capture_progress(0.7 if north_team == 0 else 0.2, 0.7 if north_team == 1 else 0.2)
	fsm.overtime_timeout({})
	assert_eq(round_winners.size(), 1)
	assert_eq(fsm.teams[round_winners[0]], north_team)


func test_overtime_timeout_ignores_hp_and_draws_on_equal_capture_percent() -> void:
	fsm.phase = ControlMatchFsm.Phase.OVERTIME
	fsm.update_capture_progress(0.5, 0.5)
	# Wildly unequal HP must not matter: Control breaks ties on capture %, not HP.
	fsm.overtime_timeout({fsm.north_id: 100.0, fsm.south_id(): 1.0})
	assert_eq(round_winners.size(), 1)
	assert_eq(round_winners[0], 0)


func test_best_of_three_match_ends_at_two_round_wins() -> void:
	var north_team: int = fsm.teams[fsm.north_id]
	fsm.match_ended.connect(func(w: int, _r: StringName) -> void: _match_winner = w)
	fsm.capture_completed(north_team)  # round 1 -> score 1
	fsm.tick(ControlMatchFsm.ROUND_END_TIME + 0.1)  # -> next round's draft
	_draft_to_combat()
	fsm.capture_completed(north_team)  # round 2 -> score 2, best-of-3 won
	fsm.tick(ControlMatchFsm.ROUND_END_TIME + 0.1)  # ROUND_END -> _after_round -> _finish
	assert_ne(_match_winner, -1)
	assert_eq(fsm.teams[_match_winner], north_team)
