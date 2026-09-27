@tool
class_name TeamMatchFsm
extends MatchFsm
## Same match lifecycle as duels; team ownership is independent of transport ids.

var team_size: int = 2
var teams: Dictionary[int, int] = {}
var alive: Array[int] = []


func start(p_players: Array[int], p_overtime_setting: StringName = &"collapse") -> void:
	teams = TeamRules.assign(p_players)
	alive = p_players.duplicate()
	super.start(p_players, p_overtime_setting)
	north_id = leader(teams[north_id])


func leader(team: int) -> int:
	for id: int in players:
		if teams.get(id, -1) == team:
			return id
	return 0


func other(id: int) -> int:
	return leader(1 - int(teams.get(id, 0)))


func pick_element(id: int, element: StringName) -> bool:
	if phase != Phase.DRAFT or not teams.has(id) or not TeamRules.can_pick(id, element, elements, teams, team_size):
		return false
	var active_team: int = teams[north_id] if draft_step == DraftStep.SIDE_A else teams[south_id()]
	if draft_step == DraftStep.DONE or teams[id] != active_team:
		return false
	elements[id] = element
	confirmed.erase(id)
	var complete: bool = true
	for member: int in players:
		if teams[member] == active_team and not elements.has(member):
			complete = false
	if complete and draft_step == DraftStep.SIDE_A:
		draft_step = DraftStep.SIDE_B
	phase_changed.emit(phase)
	return true


func _finish_draft() -> void:
	for id: int in players:
		if not elements.has(id):
			for element: StringName in ELEMENTS:
				if TeamRules.can_pick(id, element, elements, teams, team_size):
					elements[id] = element
					break
	_auto_pick_runes()
	draft_step = DraftStep.DONE
	_set_phase(Phase.COUNTDOWN, COUNTDOWN_TIME)


func _begin_round() -> void:
	alive = players.duplicate()
	super._begin_round()
	if last_round_loser != 0 and not decisive and rune_offers.has(last_round_loser):
		for id: int in players:
			if teams[id] == teams[last_round_loser]:
				rune_offers[id] = (rune_offers[last_round_loser] as Array).duplicate()
	phase_changed.emit(phase)


func player_died(id: int) -> void:
	resolve_deaths([id], {})


func resolve_deaths(ids: Array[int], hp_before: Dictionary) -> void:
	if phase not in [Phase.COMBAT, Phase.OVERTIME]:
		return
	for id: int in ids:
		alive.erase(id)
	var counts: Array[int] = [0, 0]
	for id: int in alive:
		counts[teams[id]] += 1
	if counts[0] == 0 and counts[1] == 0:
		overtime_timeout(hp_before)
	elif counts[0] == 0 or counts[1] == 0:
		_end_round(leader(0 if counts[0] > 0 else 1), &"kill")


func overtime_timeout(hp: Dictionary) -> void:
	var totals: Array[float] = [0.0, 0.0]
	for id: int in players:
		totals[teams[id]] += float(hp.get(id, 0.0))
	if not is_equal_approx(totals[0], totals[1]):
		_end_round(leader(0 if totals[0] > totals[1] else 1), &"hp")
	elif core_holder != 0:
		_end_round(leader(teams[core_holder]), &"core")
	else:
		_end_round(0, &"draw")


func _end_round(winner_id: int, reason: StringName) -> void:
	if winner_id != 0:
		for id: int in players:
			if teams[id] == teams[winner_id]:
				score[id] += 1
		last_round_loser = other(winner_id)
	else:
		last_round_loser = 0
	previous_round = {"arena": arena, "winner": winner_id, "reason": reason, "core_holder": core_holder, "elements": elements.duplicate()}
	round_ended.emit(winner_id, reason)
	_set_phase(Phase.ROUND_END, ROUND_END_TIME)


func replace_player(old_id: int, new_id: int) -> bool:
	if not super.replace_player(old_id, new_id):
		return false
	teams[new_id] = teams[old_id]
	teams.erase(old_id)
	if alive.has(old_id):
		alive[alive.find(old_id)] = new_id
	return true


func tick(delta: float, hp: Dictionary = {}) -> void:
	# At the first window deadline fill every remaining allied pick, not just the captain.
	if phase == Phase.DRAFT and draft_step == DraftStep.SIDE_A and _draft_elapsed + delta * speed >= (15.0 if round_number == 1 else DRAFT_PICK_TIME):
		for id: int in players:
			if teams[id] == teams[north_id] and not elements.has(id):
				for element: StringName in ELEMENTS:
					if pick_element(id, element):
						break
	super.tick(delta, hp)
