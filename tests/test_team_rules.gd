@tool
extends McpTestSuite
## TeamRules pure helpers (docs/reviews/r2-decisions.md: team draft, friendly fire).


func suite_name() -> String:
	return "team_rules"


func test_size_for() -> void:
	assert_eq(TeamRules.size_for(&"1v1"), 1)
	assert_eq(TeamRules.size_for(&"2v2"), 2)
	assert_eq(TeamRules.size_for(&"3v3"), 3)
	assert_eq(TeamRules.size_for(&"5v5"), 5)


func test_assign_alternates_teams() -> void:
	var ids: Array[int] = [1, 2, 3, 4, 5, 6]
	var teams: Dictionary[int, int] = TeamRules.assign(ids)
	assert_eq(teams[1], 0)
	assert_eq(teams[2], 1)
	assert_eq(teams[3], 0)
	assert_eq(teams[4], 1)
	assert_eq(teams[5], 0)
	assert_eq(teams[6], 1)


## 2v2/3v3: no duplicate element within the same team; enemies may repeat freely.
func test_can_pick_no_duplicate_within_team_small() -> void:
	var ids: Array[int] = [1, 2, 3, 4]
	var teams: Dictionary[int, int] = TeamRules.assign(ids)  # 1,3 team0; 2,4 team1
	var elements: Dictionary = {1: &"fire"}
	assert_false(TeamRules.can_pick(3, &"fire", elements, teams, 2))
	assert_true(TeamRules.can_pick(2, &"fire", elements, teams, 2))  # enemy team may repeat
	assert_true(TeamRules.can_pick(3, &"frost", elements, teams, 2))


## 5v5: at most 2 players per team may share an element.
func test_can_pick_5v5_allows_two_per_team() -> void:
	var ids: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var teams: Dictionary[int, int] = TeamRules.assign(ids)  # evens/odds by index parity
	var team0: Array[int] = []
	for id: int in ids:
		if teams[id] == 0:
			team0.append(id)
	assert_eq(team0.size(), 5)
	var elements: Dictionary = {team0[0]: &"fire"}
	assert_true(TeamRules.can_pick(team0[1], &"fire", elements, teams, 5))
	elements[team0[1]] = &"fire"
	assert_false(TeamRules.can_pick(team0[2], &"fire", elements, teams, 5))
	assert_true(TeamRules.can_pick(team0[2], &"frost", elements, teams, 5))


func test_can_pick_rejects_unknown_id_or_element() -> void:
	var teams: Dictionary[int, int] = {1: 0, 2: 1}
	assert_false(TeamRules.can_pick(9, &"fire", {}, teams, 1))
	assert_false(TeamRules.can_pick(1, &"lava", {}, teams, 1))


func test_friendly_true_for_same_team_false_otherwise() -> void:
	MatchState.view["teams"] = {1: 0, 2: 0, 3: 1, 4: 1}
	var a: Node = Node.new()
	a.name = "1"
	var b: Node = Node.new()
	b.name = "2"
	var c: Node = Node.new()
	c.name = "3"
	assert_true(TeamRules.friendly(a, b))
	assert_false(TeamRules.friendly(a, c))
	assert_false(TeamRules.friendly(a, a))
	assert_false(TeamRules.friendly(a, null))
	a.free()
	b.free()
	c.free()
	MatchState.view.erase("teams")


func test_spawn_offset_spreads_indices() -> void:
	var o0: Vector3 = TeamRules.spawn_offset(0)
	var o1: Vector3 = TeamRules.spawn_offset(1)
	assert_ne(o0, o1)
	assert_eq(TeamRules.spawn_offset(-1), Vector3.ZERO)
