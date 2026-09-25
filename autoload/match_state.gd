## Host-authoritative match FSM (draft, rounds, overtime, results). See docs/specs/02-match-loop.md.
## The host owns a MatchFsm; every change is mirrored to clients through `_sync`.
extends Node

signal changed
signal round_ended(winner_id: int, reason: StringName)
signal match_ended(winner_id: int, reason: StringName)

var fsm: MatchFsm
## Client-side mirror of the host FSM (also filled on the host for uniform reads).
var view: Dictionary = {}
var active: bool = false
## Host: per-player match statistics (spec 02 §7). id -> {dealt, taken, casts:{form:n}, hits:{form:n}, cores}
var stats: Dictionary = {}


func start_match(overtime_setting: StringName = &"random", arena_setting: StringName = &"rotation") -> void:
	if not Net.is_host():
		return
	fsm = MatchFsm.new()
	fsm.phase_changed.connect(func(_p: MatchFsm.Phase) -> void: _broadcast())
	fsm.round_ended.connect(func(w: int, r: StringName) -> void: _round_ended.rpc(w, r))
	fsm.match_ended.connect(func(w: int, r: StringName) -> void: _match_ended.rpc(w, r, stats))
	var ids: Array[int] = []
	for id: int in Net.players:
		ids.append(id)
	ids.sort()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var speed_index: int = args.find("--match-speed")
	if speed_index >= 0 and speed_index + 1 < args.size():
		fsm.speed = float(args[speed_index + 1])
	stats.clear()
	for id: int in ids:
		stats[id] = {"dealt": 0.0, "taken": 0.0, "casts": {}, "hits": {}, "cores": 0}
	fsm.arena_setting = arena_setting
	active = true
	if not Net.peer_left.is_connected(_on_peer_left):
		Net.peer_left.connect(_on_peer_left)
	fsm.start(ids, overtime_setting)


## Disconnect: pause, then forfeit if the player is still gone after the grace period.
func _on_peer_left(id: int) -> void:
	if fsm == null or not fsm.players.has(id):
		return
	fsm.player_disconnected(id)
	await get_tree().create_timer(MatchFsm.DISCONNECT_GRACE).timeout
	if fsm.phase == MatchFsm.Phase.PAUSED and not Net.players.has(id):
		fsm.forfeit(id)


func _physics_process(delta: float) -> void:
	if fsm == null or not Net.is_host():
		return
	var before: int = int(fsm.time_left)
	fsm.tick(delta, _hp_by_player())
	# Keep clients' clocks honest once per second without spamming reliable RPCs.
	if int(fsm.time_left) != before:
		_broadcast()


func phase() -> MatchFsm.Phase:
	return int(view.get("phase", MatchFsm.Phase.LOBBY)) as MatchFsm.Phase


func is_frozen() -> bool:
	var p: MatchFsm.Phase = phase()
	return active and p != MatchFsm.Phase.COMBAT and p != MatchFsm.Phase.OVERTIME


# --- Client requests -------------------------------------------------------------

func mark_loaded() -> void:
	_request_loaded.rpc_id(1)


func pick_element(element: StringName) -> void:
	_request_element.rpc_id(1, element)


func pick_rune(rune: StringName) -> void:
	_request_rune.rpc_id(1, rune)


@rpc("any_peer", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _request_loaded() -> void:
	if fsm != null and Net.is_host():
		fsm.mark_loaded(_sender())


@rpc("any_peer", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _request_element(element: StringName) -> void:
	if fsm != null and Net.is_host() and fsm.pick_element(_sender(), element):
		_broadcast()


@rpc("any_peer", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _request_rune(rune: StringName) -> void:
	if fsm != null and Net.is_host() and fsm.pick_rune(_sender(), rune):
		_broadcast()


## Host game events.
func report_death(id: int) -> void:
	if fsm != null and Net.is_host():
		fsm.player_died(id)


func report_core(id: int) -> void:
	if fsm != null and Net.is_host():
		fsm.core_captured(id)
		if stats.has(id):
			stats[id]["cores"] += 1
		_broadcast()


## Host: a spell was cast by id.
func report_cast(id: int, form: StringName) -> void:
	if stats.has(id):
		var casts: Dictionary = stats[id]["casts"]
		casts[form] = int(casts.get(form, 0)) + 1


## Host: mount damage from source_id (0 = environment) to 	arget_id.
func report_damage(source_id: int, target_id: int, amount: float, form: StringName) -> void:
	if stats.has(target_id):
		stats[target_id]["taken"] += amount
	if stats.has(source_id) and source_id != target_id:
		stats[source_id]["dealt"] += amount
		if form != &"":
			var hits: Dictionary = stats[source_id]["hits"]
			hits[form] = int(hits.get(form, 0)) + 1


func _sender() -> int:
	var id: int = multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


# --- Mirroring ----------------------------------------------------------------------

func _broadcast() -> void:
	var state: Dictionary = {
		"phase": fsm.phase,
		"time_left": fsm.time_left,
		"round": fsm.round_number,
		"score": fsm.score.duplicate(),
		"north": fsm.north_id,
		"draft_step": fsm.draft_step,
		"elements": fsm.elements.duplicate(),
		# Rune picks stay hidden until the draft ends (spec 02 §8).
		"runes": fsm.runes.duplicate() if fsm.draft_step == MatchFsm.DraftStep.DONE else {},
		"rune_offers": fsm.rune_offers.duplicate(),
		"decisive": fsm.decisive,
		"overtime_rule": fsm.overtime_rule,
		"core_spawned": fsm.core_spawned,
		"core_holder": fsm.core_holder,
		"arena": fsm.arena,
		"core_progress": _core_progress(),
	}
	_sync.rpc(state)


@rpc("authority", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _sync(state: Dictionary) -> void:
	active = true
	view = state
	changed.emit()


@rpc("authority", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _round_ended(winner_id: int, reason: StringName) -> void:
	print("[match] round won by %d (%s)" % [winner_id, reason])
	round_ended.emit(winner_id, reason)


@rpc("authority", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _match_ended(winner_id: int, reason: StringName, final_stats: Dictionary) -> void:
	stats = final_stats
	print("[match] match won by %d (%s) stats=%s" % [winner_id, reason, final_stats])
	match_ended.emit(winner_id, reason)


func _hp_by_player() -> Dictionary:
	var out: Dictionary = {}
	var net_match: Node = get_tree().get_first_node_in_group(&"net_match")
	if net_match == null:
		return out
	for id: int in Net.players:
		var player: Player = net_match.call(&"get_player", id) as Player
		if player != null:
			out[id] = player.stats.hp
	return out


func _core_progress() -> Dictionary:
	var net_match: Node = get_tree().get_first_node_in_group(&"net_match")
	return net_match.call(&"core_progress") if net_match != null else {}
