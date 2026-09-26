@tool
class_name TeamRules
extends RefCounted

const MODES: Array[StringName] = [&"1v1", &"2v2", &"3v3", &"5v5"]


static func size_for(mode: StringName) -> int:
	return int(String(mode).left(1)) if MODES.has(mode) else 1


static func assign(ids: Array[int]) -> Dictionary[int, int]:
	var teams: Dictionary[int, int] = {}
	for i: int in ids.size():
		teams[ids[i]] = i % 2
	return teams


static func can_pick(id: int, element: StringName, elements: Dictionary, teams: Dictionary, team_size: int) -> bool:
	if not teams.has(id) or not MatchFsm.ELEMENTS.has(element):
		return false
	var count: int = 0
	for other: int in elements:
		if other != id and (team_size == 1 or teams.get(other, -1) == teams[id]) and elements[other] == element:
			count += 1
	return count < (2 if team_size == 5 else 1)


static func friendly(source: Node, target: Node) -> bool:
	if source == null or target == null or source == target:
		return false
	var teams: Dictionary = MatchState.view.get("teams", {})
	var a: int = int(String(source.name))
	var b: int = int(String(target.name))
	return teams.has(a) and teams.has(b) and teams[a] == teams[b]


static func spawn_offset(index: int) -> Vector3:
	return Vector3((index % 3 - 1) * 1.5, 0, (index / 3) * 1.5) if index >= 0 else Vector3.ZERO
