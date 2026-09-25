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
