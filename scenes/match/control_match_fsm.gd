@tool
class_name ControlMatchFsm
extends TeamMatchFsm
## M12 decisions 4-6: 5v5 Control. One capture point (the Arcane Core, reused as the
## control point) captured to 100% wins the round; best-of-3 (first to 2); dead players
## rejoin after a 10 s wave respawn instead of sitting out the round; no loser rune.
## The point's occupancy/percentage math lives in `ControlCore` (scene-side, needs player
## positions); this FSM only owns round/score/respawn-timer bookkeeping, like `core_holder`
## does for the elimination Overcharge core.

## Host: a wave-respawned player is ready to be teleported back in (net_match listens).
signal player_respawn_ready(id: int)

const CONTROL_ROUNDS_TO_WIN: int = 2
const WAVE_RESPAWN_TIME: float = 10.0

## player id -> seconds left until wave respawn (host authoritative, mirrored to clients
## for the HUD countdown).
var respawn_at: Dictionary[int, float] = {}


func _begin_round() -> void:
	super._begin_round()
	respawn_at.clear()
	decisive = score[players[0]] == CONTROL_ROUNDS_TO_WIN - 1 and score[players[1]] == CONTROL_ROUNDS_TO_WIN - 1


## Decision 6: no loser rune in Control.
func _grants_rune() -> bool:
	return false


## Decision 5: death never ends a Control round; the player rejoins after WAVE_RESPAWN_TIME.
func resolve_deaths(ids: Array[int], _hp_before: Dictionary) -> void:
	if phase != Phase.COMBAT and phase != Phase.OVERTIME:
		return
	for id: int in ids:
		if players.has(id) and not respawn_at.has(id):
			respawn_at[id] = WAVE_RESPAWN_TIME


## Base MatchFsm.both_died assumes exactly two players in the whole match; Control (like
## every team mode) never ends a round on death, so just queue both for wave respawn.
func both_died(hp_before: Dictionary) -> void:
	resolve_deaths(Array(hp_before.keys()), {})


func tick(delta: float, hp: Dictionary = {}) -> void:
	if phase == Phase.COMBAT or phase == Phase.OVERTIME:
		var scaled: float = delta * speed
		for id: int in respawn_at.keys().duplicate():
			respawn_at[id] -= scaled
			if respawn_at[id] <= 0.0:
				respawn_at.erase(id)
				player_respawn_ready.emit(id)
	super.tick(delta, hp)


## Host: a team's ControlCore capture reached 100% (decision 4). Ends the round like any
## other win condition.
func capture_completed(team: int) -> void:
	if phase == Phase.COMBAT or phase == Phase.OVERTIME:
		_end_round(leader(team), &"capture")


func _after_round() -> void:
	for id: int in players:
		if score[id] >= CONTROL_ROUNDS_TO_WIN:
			_finish(id, &"score")
			return
	_begin_round()
