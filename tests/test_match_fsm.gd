@tool
extends McpTestSuite
## MatchFsm transitions (docs/specs/02-match-loop.md).

const A: int = 1
const B: int = 77

var fsm: MatchFsm
var round_winners: Array[int] = []
var match_winner: int = -1


func suite_name() -> String:
	return "match_fsm"


func setup() -> void:
	fsm = MatchFsm.new()
	fsm.rng.seed = 1234
	round_winners.clear()
	match_winner = -1
	fsm.round_ended.connect(func(w: int, _r: StringName) -> void: round_winners.append(w))
	fsm.match_ended.connect(func(w: int, _r: StringName) -> void: match_winner = w)
	fsm.start([A, B] as Array[int], &"random")


func _load_both() -> void:
	fsm.mark_loaded(A)
	fsm.mark_loaded(B)


## Plays the draft with legal picks and runs the countdown into COMBAT.
func _to_combat() -> void:
	var first: int = fsm.north_id
	var second: int = fsm.south_id()
	assert_true(fsm.pick_element(first, &"fire"))
	assert_true(fsm.pick_element(second, &"frost"))
	fsm.tick(MatchFsm.COUNTDOWN_TIME + 0.01)
	assert_eq(fsm.phase, MatchFsm.Phase.COMBAT)


func _finish_round_end() -> void:
	fsm.tick(MatchFsm.ROUND_END_TIME + 0.01)


func test_loading_waits_for_everyone() -> void:
	assert_eq(fsm.phase, MatchFsm.Phase.LOADING)
	fsm.mark_loaded(A)
	assert_eq(fsm.phase, MatchFsm.Phase.LOADING)
	fsm.mark_loaded(B)
	assert_eq(fsm.phase, MatchFsm.Phase.DRAFT)
	assert_eq(fsm.round_number, 1)


func test_draft_order_and_no_duplicates() -> void:
	_load_both()
	assert_eq(fsm.north_id, A)
	assert_false(fsm.pick_element(B, &"wind"), "side B cannot pick first")
	assert_true(fsm.pick_element(A, &"storm"))
	assert_false(fsm.pick_element(B, &"storm"), "no duplicate element")
	assert_true(fsm.pick_element(B, &"wind"))
	assert_eq(fsm.phase, MatchFsm.Phase.COUNTDOWN)


func test_draft_timeout_auto_picks_legal_elements() -> void:
	_load_both()
	fsm.tick(MatchFsm.DRAFT_PICK_TIME + 0.01)
	fsm.tick(MatchFsm.DRAFT_PICK_TIME + 0.01)
	assert_eq(fsm.phase, MatchFsm.Phase.COUNTDOWN)
	assert_ne(fsm.elements[A], fsm.elements[B])


func test_kill_ends_round_and_sides_swap() -> void:
	_load_both()
	_to_combat()
	fsm.player_died(B)
	assert_eq(fsm.phase, MatchFsm.Phase.ROUND_END)
	assert_eq(fsm.score[A], 1)
	_finish_round_end()
	assert_eq(fsm.phase, MatchFsm.Phase.DRAFT)
	assert_eq(fsm.north_id, B, "sides swap, so B picks first in round 2")


func test_loser_gets_rune_offer() -> void:
	_load_both()
	_to_combat()
	fsm.player_died(B)
	_finish_round_end()
	assert_true(fsm.rune_offers.has(B))
	assert_false(fsm.rune_offers.has(A))
	assert_eq((fsm.rune_offers[B] as Array).size(), 3)
	var offered: StringName = fsm.rune_offers[B][0]
	assert_true(fsm.pick_rune(B, offered))
	assert_false(fsm.pick_rune(A, offered), "winner gets no rune")


func test_core_spawns_after_30_seconds() -> void:
	_load_both()
	_to_combat()
	fsm.tick(29.0)
	assert_false(fsm.core_spawned)
	fsm.tick(1.5)
	assert_true(fsm.core_spawned)


func test_combat_timeout_goes_to_overtime() -> void:
	_load_both()
	_to_combat()
	fsm.tick(MatchFsm.COMBAT_TIME + 0.01)
	assert_eq(fsm.phase, MatchFsm.Phase.OVERTIME)
	assert_true(MatchFsm.OVERTIME_RULES.has(fsm.overtime_rule))


func test_fixed_overtime_rule() -> void:
	fsm = MatchFsm.new()
	fsm.start([A, B] as Array[int], &"sudden_death")
	_load_both()
	_to_combat()
	fsm.tick(MatchFsm.COMBAT_TIME + 0.01)
	assert_eq(fsm.overtime_rule, &"sudden_death")


func test_overtime_timeout_hp_then_core_then_draw() -> void:
	_load_both()
	_to_combat()
	fsm.tick(MatchFsm.COMBAT_TIME + 0.01)
	fsm.tick(MatchFsm.OVERTIME_LIMIT + 0.01, {A: 40.0, B: 55.0})
	assert_eq(round_winners[-1], B, "more HP wins")
	_finish_round_end()
	_to_combat()
	fsm.core_captured(A)
	fsm.tick(MatchFsm.COMBAT_TIME + 0.01)
	fsm.tick(MatchFsm.OVERTIME_LIMIT + 0.01, {A: 50.0, B: 50.0})
	assert_eq(round_winners[-1], A, "tie goes to the Core holder")
	_finish_round_end()
	_to_combat()
	fsm.tick(MatchFsm.COMBAT_TIME + 0.01)
	fsm.tick(MatchFsm.OVERTIME_LIMIT + 0.01, {A: 50.0, B: 50.0})
	assert_eq(round_winners[-1], 0, "no Core: drawn round")
	assert_eq(fsm.score[A], 1)
	assert_eq(fsm.score[B], 1)


func test_decisive_round_at_3_3() -> void:
	_load_both()
	for i: int in 6:
		_to_combat()
		fsm.player_died(B if i % 2 == 0 else A)
		_finish_round_end()
	assert_eq(fsm.score[A], 3)
	assert_eq(fsm.score[B], 3)
	assert_true(fsm.decisive)
	assert_true(fsm.rune_offers.has(A) and fsm.rune_offers.has(B), "both get runes")
	_to_combat()
	fsm.tick(MatchFsm.COMBAT_TIME + 0.01)
	assert_eq(fsm.overtime_rule, &"collapse", "decisive overtime is always Collapse")


func test_first_to_four_wins() -> void:
	_load_both()
	for i: int in 4:
		_to_combat()
		fsm.player_died(B)
		_finish_round_end()
	assert_eq(fsm.phase, MatchFsm.Phase.MATCH_END)
	assert_eq(match_winner, A)


func test_both_died_higher_hp_wins() -> void:
	_load_both()
	_to_combat()
	fsm.both_died({A: 5.0, B: 12.0})
	assert_eq(round_winners[-1], B)


func test_disconnect_pause_resume_and_forfeit() -> void:
	_load_both()
	_to_combat()
	fsm.tick(10.0)
	fsm.player_disconnected(B)
	assert_eq(fsm.phase, MatchFsm.Phase.PAUSED)
	fsm.player_reconnected()
	assert_eq(fsm.phase, MatchFsm.Phase.COMBAT)
	assert_true(absf(fsm.time_left - (MatchFsm.COMBAT_TIME - 10.0)) < 0.01, "clock resumes")
	fsm.player_disconnected(B)
	fsm.forfeit(B)
	assert_eq(fsm.phase, MatchFsm.Phase.MATCH_END)
	assert_eq(match_winner, A)
