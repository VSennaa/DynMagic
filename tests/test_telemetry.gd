@tool
extends McpTestSuite
## D12: local telemetry JSON is written and parseable.

const DIR: String = "user://telemetry"


func suite_name() -> String:
	return "telemetry"


func test_match_telemetry_written_and_parsed() -> void:
	MatchState.stats = {1: {"dealt": 12.0, "taken": 4.0, "casts": {&"projectile": 3}, "hits": {&"projectile": 2}, "cores": 1}}
	MatchState.participant_names = {1: "Ana", 2: "Bia"}
	MatchState.fsm = MatchFsm.new()
	MatchState._write_telemetry(1, &"kill")
	var dir: DirAccess = DirAccess.open(DIR)
	assert_true(dir != null, "telemetry directory created")
	var newest: String = ""
	var newest_time: int = -1
	for file: String in dir.get_files():
		if file.begins_with("match_") and file.ends_with(".json"):
			var stamp: int = int(file.trim_prefix("match_").trim_suffix(".json"))
			if stamp >= newest_time:
				newest_time = stamp
				newest = file
	assert_ne(newest, "", "telemetry file written")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/" + newest))
	assert_true(parsed is Dictionary, "telemetry is valid JSON")
	var payload: Dictionary = parsed
	assert_eq(String(payload.get("reason", "")), "kill")
	assert_eq(String(payload.get("game", "")), "DynMagic")
	var players: Dictionary = payload.get("players", {})
	assert_true(players.has("Ana"), "player name is the key")
	assert_eq(int((players.get("Ana", {}) as Dictionary).get("cores", -1)), 1)
	MatchState.stats = {}
	MatchState.participant_names = {}
	MatchState.fsm = null
