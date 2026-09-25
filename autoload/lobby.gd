## Lobby state: players, ready flags, match rules chosen by the host. See docs/specs/02-match-loop.md.
extends Node

signal changed
signal match_starting

## Host-chosen rules (spec 06 §1): "random" | collapse | sudden_death | mana_surge.
var overtime_setting: StringName = &"random"
## "rotation" | "random" | "A" | "B" | "C".
var arena_setting: StringName = &"rotation"
## peer id -> ready
var ready_flags: Dictionary[int, bool] = {}


func _ready() -> void:
	Net.peer_joined.connect(func(_id: int, _name: String) -> void: _push())
	Net.peer_left.connect(func(id: int) -> void:
		ready_flags.erase(id)
		_push())
	Net.joined.connect(func() -> void: changed.emit())


func reset() -> void:
	ready_flags.clear()
	overtime_setting = &"random"
	arena_setting = &"rotation"


func set_ready(value: bool) -> void:
	if Net.is_host():
		_request_ready(value)
	else:
		_request_ready.rpc_id(1, value)


func set_rules(overtime: StringName, arena: StringName) -> void:
	if not Net.is_host():
		return
	overtime_setting = overtime
	arena_setting = arena
	_push()


func can_start() -> bool:
	if not Net.is_host() or Net.players.size() < 2:
		return false
	for id: int in Net.players:
		if not ready_flags.get(id, false):
			return false
	return true


## Host: everyone loads the match scene; NetMatch starts the FSM once both players are in.
func start_match() -> void:
	if can_start():
		_begin.rpc()


@rpc("any_peer", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _request_ready(value: bool) -> void:
	if not Net.is_host():
		return
	var id: int = multiplayer.get_remote_sender_id()
	ready_flags[id if id != 0 else 1] = value
	_push()


func _push() -> void:
	if Net.is_host():
		_sync.rpc(ready_flags, overtime_setting, arena_setting)


@rpc("authority", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _sync(flags: Dictionary, overtime: StringName, arena: StringName) -> void:
	# On the host (call_local) lags IS ready_flags: copy before clearing.
	var incoming: Dictionary = flags.duplicate()
	ready_flags.clear()
	for id: Variant in incoming:
		ready_flags[int(id)] = bool(incoming[id])
	overtime_setting = overtime
	arena_setting = arena
	changed.emit()


@rpc("authority", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _begin() -> void:
	match_starting.emit()
	SceneRouter.go_to(SceneRouter.MATCH)
