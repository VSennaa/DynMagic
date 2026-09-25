@tool
class_name MatchFsm
extends RefCounted
## Pure match state machine (docs/specs/02-match-loop.md). No nodes, no networking:
## the host's MatchState drives it with tick() and events, then broadcasts `phase_changed`.

signal phase_changed(phase: Phase)
signal round_ended(winner_id: int, reason: StringName)
signal match_ended(winner_id: int, reason: StringName)

enum Phase { LOBBY, LOADING, DRAFT, COUNTDOWN, COMBAT, OVERTIME, ROUND_END, MATCH_END, PAUSED }
enum DraftStep { SIDE_A, SIDE_B, DONE }

const ROUNDS_TO_WIN: int = 4
const DRAFT_PICK_TIME: float = 10.0
const COUNTDOWN_TIME: float = 3.0
const COMBAT_TIME: float = 90.0
const OVERTIME_LIMIT: float = 60.0
const ROUND_END_TIME: float = 3.0
const DISCONNECT_GRACE: float = 30.0
const CORE_SPAWN_AT: float = 30.0
const ELEMENTS: Array[StringName] = [&"fire", &"frost", &"storm", &"wind"]
const OVERTIME_RULES: Array[StringName] = [&"collapse", &"sudden_death", &"mana_surge"]
const ARENAS: Array[StringName] = [&"A", &"B", &"C"]
const RUNES: Array[StringName] = [&"breath", &"haste", &"light_step", &"husk", &"focus", &"echo", &"cold_blood"]

var phase: Phase = Phase.LOBBY
## Seconds left in the current phase (the HUD clock).
var time_left: float = 0.0
var round_number: int = 0
## Player ids: [host, guest]. Order never changes; sides do.
var players: Array[int] = []
var score: Dictionary[int, int] = {}
## Player on the north spawn this round = side A = first to pick.
var north_id: int = 0
var draft_step: DraftStep = DraftStep.DONE
var elements: Dictionary[int, StringName] = {}
## Rune offers and picks for this round (loser of the previous round, or both in the decisive round).
var rune_offers: Dictionary[int, Array] = {}
var runes: Dictionary[int, StringName] = {}
var last_round_loser: int = 0
var decisive: bool = false
## "collapse" (alpha default), "sudden_death", "mana_surge" or "random", chosen in the lobby.
var overtime_setting: StringName = &"collapse"
var overtime_rule: StringName = &""
## "rotation" (default), "random", or a fixed variant id (spec 03 §3).
var arena_setting: StringName = &"rotation"
var arena: StringName = &"A"
var core_holder: int = 0
var core_spawned: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Debug: multiplies the clock (e.g. --match-speed 8 for automated full-match runs).
var speed: float = 1.0

var confirmed: Array[int] = []
var _draft_elapsed: float = 0.0
var _loaded: Array[int] = []
var _paused_phase: Phase = Phase.LOBBY
var _paused_time: float = 0.0


func start(p_players: Array[int], p_overtime_setting: StringName = &"collapse") -> void:
	players = p_players.duplicate()
	overtime_setting = p_overtime_setting
	score.clear()
	for id: int in players:
		score[id] = 0
	round_number = 0
	north_id = players[rng.randi_range(0, players.size() - 1)]
	last_round_loser = 0
	_loaded.clear()
	_set_phase(Phase.LOADING, 0.0)


func mark_loaded(id: int) -> void:
	if phase != Phase.LOADING or not players.has(id) or _loaded.has(id):
		return
	_loaded.append(id)
	if _loaded.size() >= players.size():
		_begin_round()


func other(id: int) -> int:
	return players[1] if id == players[0] else players[0]


func south_id() -> int:
	return other(north_id)


# --- Draft (spec 02 §3) --------------------------------------------------------

## Returns false when the pick is illegal (wrong turn, taken element, unknown id).
func pick_element(id: int, element: StringName) -> bool:
	if phase != Phase.DRAFT or not ELEMENTS.has(element):
		return false
	var expected: int = north_id if draft_step == DraftStep.SIDE_A else (south_id() if draft_step == DraftStep.SIDE_B else 0)
	if id != expected:
		return false
	if draft_step == DraftStep.SIDE_B and elements.get(north_id, &"") == element:
		return false
	elements[id] = element
	confirmed.erase(id)
	if draft_step == DraftStep.SIDE_A:
		draft_step = DraftStep.SIDE_B
	phase_changed.emit(phase)
	return true


func pick_rune(id: int, rune: StringName) -> bool:
	if phase != Phase.DRAFT or not rune_offers.has(id) or not (rune_offers[id] as Array).has(rune):
		return false
	confirmed.erase(id)
	runes[id] = rune
	return true


func confirm_draft(id: int) -> bool:
	if phase != Phase.DRAFT or not elements.has(id) or (rune_offers.has(id) and not runes.has(id)):
		return false
	if not confirmed.has(id):
		confirmed.append(id)
	if confirmed.size() == players.size():
		_finish_draft()
	return true


func _finish_draft() -> void:
	for id: int in [north_id, south_id()]:
		if not elements.has(id):
			var options: Array[StringName] = ELEMENTS.duplicate()
			options.erase(elements.get(other(id), &""))
			elements[id] = options[rng.randi_range(0, options.size() - 1)]
	_auto_pick_runes()
	draft_step = DraftStep.DONE
	_set_phase(Phase.COUNTDOWN, COUNTDOWN_TIME)


func _auto_pick_runes() -> void:
	for id: int in rune_offers:
		if not runes.has(id):
			var offers: Array = rune_offers[id]
			runes[id] = offers[rng.randi_range(0, offers.size() - 1)]


# --- Combat events ---------------------------------------------------------------

func player_died(id: int) -> void:
	if phase != Phase.COMBAT and phase != Phase.OVERTIME:
		return
	_end_round(other(id), &"kill")


## Both players died on the same tick: higher HP before the tick wins (spec 02 §5).
func both_died(hp_before: Dictionary) -> void:
	if phase != Phase.COMBAT and phase != Phase.OVERTIME:
		return
	var a: int = players[0]
	var b: int = players[1]
	var winner: int = a if float(hp_before.get(a, 0.0)) > float(hp_before.get(b, 0.0)) else (b if float(hp_before.get(b, 0.0)) > float(hp_before.get(a, 0.0)) else 0)
	_end_round(winner, &"double_kill")


func core_captured(id: int) -> void:
	if phase == Phase.COMBAT or phase == Phase.OVERTIME:
		core_holder = id


## Overtime timeout: higher HP wins; tie goes to the Core holder; else a drawn round.
func overtime_timeout(hp: Dictionary) -> void:
	var a: int = players[0]
	var b: int = players[1]
	var ha: float = float(hp.get(a, 0.0))
	var hb: float = float(hp.get(b, 0.0))
	if not is_equal_approx(ha, hb):
		_end_round(a if ha > hb else b, &"hp")
	elif core_holder != 0:
		_end_round(core_holder, &"core")
	else:
		_end_round(0, &"draw")


func player_disconnected(id: int) -> void:
	if not players.has(id) or phase == Phase.PAUSED or phase == Phase.MATCH_END or phase == Phase.LOBBY:
		return
	_paused_phase = phase
	_paused_time = time_left
	_set_phase(Phase.PAUSED, DISCONNECT_GRACE)


func player_reconnected() -> void:
	if phase == Phase.PAUSED and time_left > 0.0:
		var resume_time: float = _paused_time
		_set_phase(_paused_phase, resume_time)


## The host moves the disconnected slot to the new transport id without restarting it.
func replace_player(old_id: int, new_id: int) -> bool:
	if phase != Phase.PAUSED or time_left <= 0.0 or not players.has(old_id) or players.has(new_id):
		return false
	players[players.find(old_id)] = new_id
	for mapping: Dictionary in [score, elements, rune_offers, runes]:
		if mapping.has(old_id):
			mapping[new_id] = mapping[old_id]
			mapping.erase(old_id)
	if _loaded.has(old_id):
		_loaded[_loaded.find(old_id)] = new_id
	if north_id == old_id:
		north_id = new_id
	if last_round_loser == old_id:
		last_round_loser = new_id
	if core_holder == old_id:
		core_holder = new_id
	return true


## Returns the id that forfeits when the pause ends, so the caller can pass it in.
func forfeit(loser_id: int) -> void:
	_finish(other(loser_id), &"forfeit")


# --- Clock ----------------------------------------------------------------------

## Advances timers. `hp` (id -> hp) is needed for the overtime timeout decision.
func tick(delta: float, hp: Dictionary = {}) -> void:
	if phase != Phase.PAUSED:
		delta *= speed
	match phase:
		Phase.DRAFT:
			time_left -= delta
			_draft_elapsed += delta
			if draft_step == DraftStep.SIDE_A and _draft_elapsed >= (15.0 if round_number == 1 else DRAFT_PICK_TIME):
				var options: Array[StringName] = ELEMENTS.duplicate()
				pick_element(north_id, options[rng.randi_range(0, options.size() - 1)])
			if time_left <= 0.0:
				_finish_draft()
		Phase.COUNTDOWN:
			time_left -= delta
			if time_left <= 0.0:
				_set_phase(Phase.COMBAT, COMBAT_TIME)
		Phase.COMBAT:
			time_left -= delta
			if not core_spawned and COMBAT_TIME - time_left >= CORE_SPAWN_AT:
				core_spawned = true
				phase_changed.emit(phase)
			if time_left <= 0.0:
				overtime_rule = _choose_overtime()
				_set_phase(Phase.OVERTIME, OVERTIME_LIMIT)
		Phase.OVERTIME:
			time_left -= delta
			if time_left <= 0.0:
				overtime_timeout(hp)
		Phase.ROUND_END:
			time_left -= delta
			if time_left <= 0.0:
				_after_round()
		Phase.PAUSED:
			time_left -= delta


func _choose_overtime() -> StringName:
	if decisive:
		return &"collapse"
	if overtime_setting != &"random" and OVERTIME_RULES.has(overtime_setting):
		return overtime_setting
	return OVERTIME_RULES[rng.randi_range(0, OVERTIME_RULES.size() - 1)]


## Decisive round: random arena, never the previous one (spec 02 §6).
func _choose_arena() -> StringName:
	if decisive or arena_setting == &"random":
		var options: Array[StringName] = ARENAS.duplicate()
		if decisive and round_number > 1:
			options.erase(arena)
		return options[rng.randi_range(0, options.size() - 1)]
	if ARENAS.has(arena_setting):
		return arena_setting
	return ARENAS[(round_number - 1) % ARENAS.size()]


func _begin_round() -> void:
	round_number += 1
	if round_number > 1:
		north_id = other(north_id)  # sides swap every round, so first pick alternates
	decisive = score[players[0]] == ROUNDS_TO_WIN - 1 and score[players[1]] == ROUNDS_TO_WIN - 1
	arena = _choose_arena()
	elements.clear()
	runes.clear()
	rune_offers.clear()
	core_holder = 0
	core_spawned = false
	overtime_rule = &""
	var rune_takers: Array[int] = []
	if decisive:
		rune_takers.assign(players)
	elif last_round_loser != 0:
		rune_takers.append(last_round_loser)
	for id: int in rune_takers:
		var pool: Array[StringName] = RUNES.duplicate()
		var offer: Array[StringName] = []
		for i: int in 3:
			offer.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		rune_offers[id] = offer
	confirmed.clear()
	_draft_elapsed = 0.0
	draft_step = DraftStep.SIDE_A
	_set_phase(Phase.DRAFT, 30.0 if round_number == 1 else 20.0)


func _end_round(winner_id: int, reason: StringName) -> void:
	if winner_id != 0:
		score[winner_id] += 1
		last_round_loser = other(winner_id)
	else:
		last_round_loser = 0
	round_ended.emit(winner_id, reason)
	_set_phase(Phase.ROUND_END, ROUND_END_TIME)


func _after_round() -> void:
	for id: int in players:
		if score[id] >= ROUNDS_TO_WIN:
			_finish(id, &"score")
			return
	_begin_round()


func _finish(winner_id: int, reason: StringName) -> void:
	_set_phase(Phase.MATCH_END, 0.0)
	match_ended.emit(winner_id, reason)


func _set_phase(new_phase: Phase, duration: float) -> void:
	phase = new_phase
	time_left = duration
	phase_changed.emit(phase)
