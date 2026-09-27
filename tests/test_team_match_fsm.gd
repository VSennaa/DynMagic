@tool
extends McpTestSuite
## TeamMatchFsm: team draft, elimination rounds, replace_player (docs/reviews/r2-decisions.md).

var fsm: TeamMatchFsm
var round_winners: Array[int] = []


func suite_name() -> String:
	return "team_match_fsm"


func _make(ids: Array[int], team_size: int) -> void:
	fsm = TeamMatchFsm.new()
	fsm.rng.seed = 42
	fsm.team_size = team_size
	round_winners.clear()
	fsm.round_ended.connect(func(w: int, _r: StringName) -> void: round_winners.append(w))
	fsm.start(ids, &"random")
	for id: int in ids:
		fsm.mark_loaded(id)


func _team(team: int) -> Array[int]:
	var out: Array[int] = []
	for id: int in fsm.players:
		if fsm.teams[id] == team:
			out.append(id)
	return out


## 2v2: [1,2,3,4] -> team0 {1,3}, team1 {2,4} (TeamRules.assign alternates by index).
func setup() -> void:
	_make([1, 2, 3, 4], 2)


func test_teams_assigned_by_index_parity() -> void:
	assert_eq(fsm.teams[1], 0)
	assert_eq(fsm.teams[2], 1)
	assert_eq(fsm.teams[3], 0)
	assert_eq(fsm.teams[4], 1)


func test_north_id_is_the_drafting_teams_leader() -> void:
	var north_team: int = fsm.teams[fsm.north_id]
	assert_eq(fsm.leader(north_team), fsm.north_id)


func test_draft_no_duplicate_within_team_but_enemies_may_repeat() -> void:
	var north: int = fsm.north_id
	var north_team: Array[int] = _team(fsm.teams[north])
	var north_mate: int = north_team[0] if north_team[0] != north else north_team[1]
	assert_true(fsm.pick_element(north, &"fire"))
	assert_false(fsm.pick_element(north_mate, &"fire"))  # same team, duplicate
	assert_true(fsm.pick_element(north_mate, &"frost"))
	var south: int = fsm.south_id()
	var south_team: Array[int] = _team(fsm.teams[south])
	var south_mate: int = south_team[0] if south_team[0] != south else south_team[1]
	assert_true(fsm.pick_element(south, &"fire"))  # enemy team may repeat
	assert_true(fsm.pick_element(south_mate, &"storm"))


func test_draft_completing_side_a_advances_to_side_b() -> void:
	var north: int = fsm.north_id
	var north_team: Array[int] = _team(fsm.teams[north])
	var north_mate: int = north_team[0] if north_team[0] != north else north_team[1]
	assert_eq(fsm.draft_step, TeamMatchFsm.DraftStep.SIDE_A)
	fsm.pick_element(north, &"fire")
	assert_eq(fsm.draft_step, TeamMatchFsm.DraftStep.SIDE_A)  # teammate still missing
	fsm.pick_element(north_mate, &"frost")
	assert_eq(fsm.draft_step, TeamMatchFsm.DraftStep.SIDE_B)


func _draft_to_combat() -> void:
	var north: int = fsm.north_id
	var north_team: Array[int] = _team(fsm.teams[north])
	var north_mate: int = north_team[0] if north_team[0] != north else north_team[1]
	var south: int = fsm.south_id()
	var south_team: Array[int] = _team(fsm.teams[south])
	var south_mate: int = south_team[0] if south_team[0] != south else south_team[1]
	fsm.pick_element(north, &"fire")
	fsm.pick_element(north_mate, &"frost")
	fsm.pick_element(south, &"storm")
	fsm.pick_element(south_mate, &"wind")
	for id: int in fsm.rune_offers:
		fsm.pick_rune(id, fsm.rune_offers[id][0])
	for id: int in fsm.players:
		fsm.confirm_draft(id)
	fsm.tick(4.0)  # countdown -> combat


## Elimination round: last team standing wins, whole team scores.
func test_resolve_deaths_ends_round_for_losing_team() -> void:
	_draft_to_combat()
	assert_eq(fsm.phase, TeamMatchFsm.Phase.COMBAT)
	var north: int = fsm.north_id
	var north_mate: int = _team(fsm.teams[north]).filter(func(id: int) -> bool: return id != north)[0]
	var south: int = fsm.south_id()
	var south_mate: int = _team(fsm.teams[south]).filter(func(id: int) -> bool: return id != south)[0]
	fsm.resolve_deaths([south, south_mate], {})
	assert_eq(round_winners.size(), 1)
	assert_eq(fsm.teams[round_winners[0]], fsm.teams[north])
	assert_eq(fsm.score[north], 1)
	assert_eq(fsm.score[north_mate], 1)
	assert_eq(fsm.score[south], 0)


func test_replace_player_keeps_team_and_alive_slot() -> void:
	fsm.player_disconnected(2)
	assert_true(fsm.replace_player(2, 99))
	assert_eq(fsm.teams[99], 1)
	assert_false(fsm.teams.has(2))
	assert_true(fsm.alive.has(99))
	assert_false(fsm.alive.has(2))


## 5v5: at most 2 players per team may share an element.
func test_5v5_allows_two_of_same_element_per_team() -> void:
	_make([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 5)
	var north_team: Array[int] = _team(fsm.teams[fsm.north_id])
	assert_eq(north_team.size(), 5)
	assert_true(fsm.pick_element(north_team[0], &"fire"))
	assert_true(fsm.pick_element(north_team[1], &"fire"))
	assert_false(fsm.pick_element(north_team[2], &"fire"))
	assert_true(fsm.pick_element(north_team[2], &"frost"))
