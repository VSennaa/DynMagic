class_name NetSync
extends Node
## Moves one Player over the network (docs/specs/04-networking.md section 5).
##   Local client player : sends inputs, predicts, reconciles against host snapshots.
##   Host, remote player : replays the client's inputs (authoritative simulation).
##   Client, remote player: interpolates host snapshots with a 100 ms buffer.
##   Host, own player    : plain local play; state goes out in snapshots.

const INPUT_REDUNDANCY: int = 3
const HISTORY_SIZE: int = 120
const RECONCILE_EPSILON: float = 0.05
const INTERP_DELAY: float = 0.1
## Host keeps at most this many buffered inputs; older ones are dropped to cap latency.
const MAX_INPUT_BACKLOG: int = 6
const LAG_HISTORY: float = 0.25

enum Role { OFFLINE, LOCAL_CLIENT, HOST_REMOTE, CLIENT_REMOTE, HOST_LOCAL }

var player: Player
var peer_id: int = 1
var role: Role = Role.OFFLINE
## Last input sequence the host has simulated for this player (sent back as "ack").
var last_processed_seq: int = 0
## Largest position error corrected by reconciliation (F3 overlay).
var last_correction: float = 0.0

var _seq: int = 0
## Local client: [{seq, frame, pos}] of inputs not yet acknowledged.
var _history: Array[Dictionary] = []
## Host: inputs received from the client, ordered by seq.
var _pending_inputs: Array[Dictionary] = []
var _last_frame: Dictionary = {}
## Client remote: [{time, pos, yaw, pitch}] snapshots for interpolation.
var _buffer: Array[Dictionary] = []
var _clock: float = 0.0
## Host: [{time, pos}] for the last LAG_HISTORY seconds (Cone lag compensation, spec 04 §6).
var _pos_history: Array[Dictionary] = []


func configure(p_player: Player, p_peer_id: int) -> void:
	player = p_player
	peer_id = p_peer_id
	var me: int = multiplayer.get_unique_id()
	if not Net.is_online():
		role = Role.OFFLINE
	elif Net.is_host():
		role = Role.HOST_LOCAL if peer_id == me else Role.HOST_REMOTE
	else:
		role = Role.LOCAL_CLIENT if peer_id == me else Role.CLIENT_REMOTE
	player.net_driven = role == Role.HOST_REMOTE or role == Role.CLIENT_REMOTE
	if role == Role.LOCAL_CLIENT:
		player.input_sampled.connect(_on_input_sampled)


func _physics_process(delta: float) -> void:
	_clock += delta
	if role == Role.HOST_REMOTE:
		_host_step(delta)
	if role == Role.HOST_REMOTE or role == Role.HOST_LOCAL:
		_pos_history.append({"time": _clock, "pos": player.global_position})
		while not _pos_history.is_empty() and _clock - float(_pos_history[0]["time"]) > LAG_HISTORY:
			_pos_history.pop_front()


## Host: where this player was seconds ago (clamped to the kept history).
func position_ago(seconds: float) -> Vector3:
	var when: float = _clock - seconds
	for i: int in range(_pos_history.size() - 1, -1, -1):
		if float(_pos_history[i]["time"]) <= when:
			return _pos_history[i]["pos"]
	return _pos_history[0]["pos"] if not _pos_history.is_empty() else player.global_position


func _process(_delta: float) -> void:
	if role == Role.CLIENT_REMOTE:
		_interpolate()


# --- Local client: send + predict --------------------------------------------

func _on_input_sampled(frame: Dictionary) -> void:
	_seq += 1
	var entry: Dictionary = frame.duplicate()
	entry["seq"] = _seq
	entry["composer"] = _composer_bits()
	_history.append({"seq": _seq, "frame": entry, "pos": player.global_position})
	if _history.size() > HISTORY_SIZE:
		_history.pop_front()
	var recent: Array[Dictionary] = []
	for i: int in range(maxi(0, _history.size() - INPUT_REDUNDANCY), _history.size()):
		recent.append(_history[i]["frame"])
	var data: PackedByteArray = NetCodec.pack_inputs(recent)
	Net.simulate_send(func() -> void: receive_inputs.rpc_id(1, data))


## Host snapshot for our own player: drop acknowledged inputs, replay the rest if we drifted.
func reconcile(entry: Dictionary) -> void:
	var ack: int = int(entry["ack"])
	while not _history.is_empty() and int(_history[0]["seq"]) < ack:
		_history.pop_front()
	var predicted: Vector3 = player.global_position
	if not _history.is_empty() and int(_history[0]["seq"]) == ack:
		predicted = _history[0]["pos"]
		_history.pop_front()
	var server_pos: Vector3 = entry["pos"]
	var error: float = predicted.distance_to(server_pos)
	if error <= RECONCILE_EPSILON:
		return
	last_correction = error
	var yaw: float = player.rotation.y
	var pitch: float = player.get_pitch()
	player.global_position = server_pos
	player.velocity = entry["vel"]
	var step: float = 1.0 / Engine.physics_ticks_per_second
	for item: Dictionary in _history:
		player.apply_input(step, item["frame"])
		item["pos"] = player.global_position
	player.set_look(yaw, pitch)  # replay must not rewind the camera


# --- Host: replay client inputs ------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered", Net.CHANNEL_INPUT)
func receive_inputs(data: PackedByteArray) -> void:
	if role != Role.HOST_REMOTE or multiplayer.get_remote_sender_id() != peer_id:
		return
	for frame: Dictionary in NetCodec.unpack_inputs(data):
		if int(frame["seq"]) > last_processed_seq and not _has_pending(int(frame["seq"])):
			_pending_inputs.append(frame)
	_pending_inputs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["seq"]) < int(b["seq"]))
	while _pending_inputs.size() > MAX_INPUT_BACKLOG:
		last_processed_seq = int(_pending_inputs.pop_front()["seq"])


func _host_step(delta: float) -> void:
	if _pending_inputs.is_empty():
		# Late or lost input: repeat the last one so the body keeps its course (the client
		# predicted it that way too). Without any input yet, idle.
		if _last_frame.is_empty():
			player.simulate(delta, Vector2.ZERO, false, false, false)
		else:
			player.apply_input(delta, _last_frame)
		return
	var frame: Dictionary = _pending_inputs.pop_front()
	player.apply_input(delta, frame)
	_last_frame = frame
	last_processed_seq = int(frame["seq"])
	_set_remote_composer(int(frame["composer"]))


func _has_pending(seq: int) -> bool:
	for frame: Dictionary in _pending_inputs:
		if int(frame["seq"]) == seq:
			return true
	return false


# --- Client: interpolate remote players --------------------------------------

func push_remote_state(entry: Dictionary) -> void:
	_buffer.append({"time": _clock, "pos": entry["pos"], "yaw": entry["yaw"], "pitch": entry["pitch"]})
	while _buffer.size() > 20:
		_buffer.pop_front()
	_set_remote_composer(int(entry["composer"]))


func _interpolate() -> void:
	if _buffer.is_empty():
		return
	var render_time: float = _clock - INTERP_DELAY
	var older: Dictionary = _buffer[0]
	var newer: Dictionary = _buffer[-1]
	for i: int in range(_buffer.size() - 1):
		if float(_buffer[i]["time"]) <= render_time and float(_buffer[i + 1]["time"]) >= render_time:
			older = _buffer[i]
			newer = _buffer[i + 1]
			break
	var span: float = float(newer["time"]) - float(older["time"])
	var t: float = clampf((render_time - float(older["time"])) / span, 0.0, 1.0) if span > 0.0 else 1.0
	player.global_position = (older["pos"] as Vector3).lerp(newer["pos"], t)
	player.set_look(lerp_angle(float(older["yaw"]), float(newer["yaw"]), t), lerpf(float(older["pitch"]), float(newer["pitch"]), t))


# --- Snapshot helpers -----------------------------------------------------------

## Composer bits of a remote player (host from inputs, client from snapshots): drives its rune circle.
var remote_composer_bits: int = 0


func _set_remote_composer(bits: int) -> void:
	if bits == remote_composer_bits:
		return
	remote_composer_bits = bits
	var rune: RuneCircle = player.get_node_or_null(^"Head/Camera3D/RuneCircle") as RuneCircle
	if rune != null:
		rune.show_bits(bits)


func snapshot_entry() -> Dictionary:
	var statuses: Array = player.stats.active_statuses().keys()
	return {
		"id": peer_id,
		"ack": last_processed_seq,
		"pos": player.global_position,
		"vel": player.velocity,
		"yaw": player.rotation.y,
		"pitch": player.get_pitch(),
		"hp": player.stats.hp,
		"mana": player.stats.mana,
		"shield": player.stats.shield,
		"statuses": NetCodec.status_mask(statuses),
		"composer": remote_composer_bits if role == Role.HOST_REMOTE else _composer_bits(),
	}


func _composer_bits() -> int:
	var composer: SpellComposer = player.composer
	var form_index: int = SpellDB.FORMS.find(composer.form)
	var effect_index: int = SpellDB.EFFECTS.find(composer.pending.effect) if composer.pending != null else -1
	return NetCodec.pack_composer(int(composer.state), form_index, effect_index)
