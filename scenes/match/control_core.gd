class_name ControlCore
extends ArcaneCore
## M12 decisions 4-6: the Arcane Core reused as a 5v5 Control point. Unlike the elimination
## Core (per-player capture), this counts team occupancy: only one team standing inside
## RADIUS advances its percentage; empty or contested (both teams present) pauses it
## (decision 4). Visuals/rotation/bob come from the base ArcaneCore.

## Host: seconds of uncontested single-team occupation needed to go from 0% to 100%.
const CAPTURE_FULL_TIME: float = 60.0

## Host: a team (0 or 1) reached 100% capture.
signal team_captured(team: int)

## team -> 0..100 capture percentage, mirrored to clients once per second for the HUD.
var team_progress: Dictionary[int, float] = {0: 0.0, 1: 0.0}
var _team_done: bool = false


static func create() -> ControlCore:
	var core: ControlCore = ControlCore.new()
	ArcaneCore.build_visuals(core)
	return core


## Host: advance the point from team occupancy this tick. `players` is {id: Player},
## `teams` is {id: team int}.
func host_tick_teams(delta: float, players: Dictionary, teams: Dictionary) -> void:
	if _team_done:
		return
	var occupying: Dictionary[int, bool] = {}
	for id: int in players:
		var player: Player = players[id]
		if player == null or player.stats.is_dead:
			continue
		if SpatialContract.on_floor(player.global_position, global_position, RADIUS):
			occupying[int(teams.get(id, -1))] = true
	if occupying.size() != 1:
		return  # empty or contested: paused, never decays (decision 4)
	var team: int = occupying.keys()[0]
	if team != 0 and team != 1:
		return
	team_progress[team] = clampf(team_progress.get(team, 0.0) + delta / CAPTURE_FULL_TIME * 100.0, 0.0, 100.0)
	if team_progress[team] >= 100.0:
		_team_done = true
		team_captured.emit(team)


func progress_ratio_team(team: int) -> float:
	return clampf(team_progress.get(team, 0.0) / 100.0, 0.0, 1.0)
