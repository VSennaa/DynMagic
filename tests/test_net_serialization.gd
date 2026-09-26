@tool
extends McpTestSuite
## NetCodec round trips (docs/specs/04-networking.md sections 5 and 7).


func suite_name() -> String:
	return "net_serialization"


func test_input_frames_round_trip() -> void:
	var frames: Array[Dictionary] = [
		{"seq": 41, "move": Vector2(0.0, -1.0), "yaw": 1.25, "pitch": -0.3, "buttons": NetCodec.InputButton.JUMP | NetCodec.InputButton.SPRINT, "composer": 5},
		{"seq": 42, "move": Vector2(0.7071, -0.7071), "yaw": 1.3, "pitch": -0.31, "buttons": 0, "composer": 0},
	]
	var data: PackedByteArray = NetCodec.pack_inputs(frames)
	var back: Array[Dictionary] = NetCodec.unpack_inputs(data)
	assert_eq(back.size(), 2)
	assert_eq(back[1]["seq"], 42)
	assert_true(absf((back[1]["move"] as Vector2).x - 0.7071) < 0.01, "move quantized within 1%")
	assert_true(absf(float(back[0]["yaw"]) - 1.25) < 0.0001)
	assert_eq(back[0]["buttons"], NetCodec.InputButton.JUMP | NetCodec.InputButton.SPRINT)
	assert_eq(back[0]["composer"], 5)


func test_input_packet_is_small() -> void:
	var frames: Array[Dictionary] = []
	for i: int in 3:
		frames.append({"seq": i, "move": Vector2.ZERO, "yaw": 0.0, "pitch": 0.0, "buttons": 0, "composer": 0})
	assert_true(NetCodec.pack_inputs(frames).size() <= 70, "3 frames fit the ~64 B budget of spec 04 §7")


func test_snapshot_round_trip() -> void:
	var snapshot: Dictionary = {
		"tick": 1234,
		"players": [
			{"id": 1, "ack": 0, "pos": Vector3(1, 2, 3), "vel": Vector3(-4, 0, 5.5), "yaw": 0.5, "pitch": 0.1,
				"hp": 87.5, "mana": 42.0, "shield": 30.0, "statuses": NetCodec.status_mask([&"burn", &"aura"]), "composer": 3},
			{"id": 282219641, "ack": 99, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0,
				"hp": 100.0, "mana": 100.0, "shield": 0.0, "statuses": 0, "composer": 0},
		],
	}
	var back: Dictionary = NetCodec.unpack_snapshot(NetCodec.pack_snapshot(snapshot))
	assert_eq(back["tick"], 1234)
	var entries: Array = back["players"]
	assert_eq(entries.size(), 2)
	assert_eq(entries[1]["id"], 282219641)
	assert_eq(entries[1]["ack"], 99)
	assert_eq(entries[0]["pos"], Vector3(1, 2, 3))
	assert_eq(entries[0]["hp"], 87.5)
	assert_eq(entries[0]["statuses"], 1 | 8)


func test_composer_packing() -> void:
	var packed: int = NetCodec.pack_composer(2, 1, -1)
	assert_eq(NetCodec.unpack_composer(packed), Vector3i(2, 1, -1))
	assert_eq(NetCodec.unpack_composer(NetCodec.pack_composer(0, -1, -1)), Vector3i(0, -1, -1))
	assert_eq(NetCodec.unpack_composer(NetCodec.pack_composer(3, 2, 2)), Vector3i(3, 2, 2))


func _gameplay() -> Dictionary:
	var runtime: Dictionary = {}
	for field: Array in NetCodec.GAMEPLAY_FIELDS:
		match int(field[1]):
			NetCodec.Field.FLOAT: runtime[field[0]] = 1.5
			NetCodec.Field.INT: runtime[field[0]] = 2
			NetCodec.Field.BOOL: runtime[field[0]] = true
			NetCodec.Field.VEC3: runtime[field[0]] = Vector3(1, -2, 3)
	runtime[&"active_aura"] = [&"frost", &"self", &"lingering"]
	runtime[&"active_guard"] = []
	runtime[&"last_spell"] = [&"fire", &"projectile", &"direct"]
	var stats: Dictionary = {"hp": 63.5, "max_hp": 100.0, "mana": 41.0, "max_mana": 130.0, "shield": 25.0,
		"shield_time_left": 3.5, "is_dead": false, "regen_pause": 0.25,
		"statuses": {&"burn": 2.5, &"slow": 1.0}, "cooldowns": {&"area_burst": 4.5, &"self_direct": 1.0}}
	return {"stats": stats, "runtime": runtime}


func _entry(id: int) -> Dictionary:
	return {"id": id, "ack": 7, "pos": Vector3(1, 2, 3), "vel": Vector3.ZERO, "yaw": 0.5, "pitch": 0.1,
		"hp": 63.5, "mana": 41.0, "shield": 25.0, "statuses": 3, "composer": 0, "gameplay": _gameplay()}


func test_gameplay_fields_match_reconnect_state() -> void:
	var codec_fields: Array[StringName] = []
	for field: Array in NetCodec.GAMEPLAY_FIELDS:
		codec_fields.append(field[0])
	assert_eq(codec_fields, ReconnectState.PLAYER_FIELDS, "codec schema must list every replicated player field")


func test_gameplay_round_trip() -> void:
	var back: Dictionary = NetCodec.unpack_snapshot(NetCodec.pack_snapshot({"tick": 1, "players": [_entry(5)]}))
	var gameplay: Dictionary = (back["players"][0] as Dictionary)["gameplay"]
	var stats: Dictionary = gameplay["stats"]
	assert_eq(stats["hp"], 63.5)
	assert_eq(stats["max_mana"], 130.0)
	assert_eq((stats["statuses"] as Dictionary)[&"burn"], 2.5)
	assert_eq((stats["cooldowns"] as Dictionary)[&"area_burst"], 4.5)
	var runtime: Dictionary = gameplay["runtime"]
	assert_eq(runtime[&"_arrow_charges"], 2)
	assert_eq(runtime[&"_knockback"], Vector3(1, -2, 3))
	assert_eq(runtime[&"sudden_death"], true)
	assert_eq(runtime[&"active_aura"], [&"frost", &"self", &"lingering"])
	assert_eq(runtime[&"active_guard"], [])


func test_two_player_snapshot_under_600_bytes() -> void:
	var size: int = NetCodec.pack_snapshot({"tick": 1, "players": [_entry(1), _entry(282219641)]}).size()
	assert_true(size < 600, "M11: 2-player snapshot is %d B (target < 600, ENet MTU 1392)" % size)
