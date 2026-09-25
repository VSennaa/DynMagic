extends Node3D
## Networked arena for M3: spawns one Player per connected peer, streams host
## snapshots and relays spell casts (docs/specs/04-networking.md sections 4-6).
## The match state machine (draft, rounds) arrives in M4.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SNAPSHOT_RATE: float = 30.0
## Host rejects casts whose origin is farther than this from the caster's cast origin.
const MAX_ORIGIN_ERROR: float = 1.5

var _snapshot_timer: float = 0.0
var _tick: int = 0
var _hud: Hud
## --bot: scripted input for headless smoke tests (walks, strafes and casts Bolt).
var _bot: bool = false
var _bot_clock: float = 0.0
var _log_timer: float = 0.0

@onready var _players_root: Node3D = $Players
@onready var _arena: Node3D = $Arena


func _ready() -> void:
	add_to_group(&"net_match")
	Net.peer_joined.connect(func(_id: int, _name: String) -> void: _sync_players())
	Net.peer_left.connect(func(_id: int) -> void: _sync_players())
	Net.joined.connect(_sync_players)
	Net.disconnected.connect(func() -> void: get_tree().quit())
	_bot = OS.get_cmdline_user_args().has("--bot")
	_hud = Hud.new()
	add_child(_hud)
	_sync_players()


func _physics_process(delta: float) -> void:
	if _bot:
		_bot_step(delta)
	_log_timer -= delta
	if _log_timer <= 0.0:
		_log_timer = 2.0
		_log_state()
	if not Net.is_host():
		return
	_tick += 1
	_snapshot_timer -= delta
	if _snapshot_timer <= 0.0:
		_snapshot_timer = 1.0 / SNAPSHOT_RATE
		_send_snapshot()


## Creates missing players and removes departed ones, matching Net.players.
func _sync_players() -> void:
	for child: Node in _players_root.get_children():
		if not Net.players.has(int(String(child.name))):
			child.queue_free()
	var ids: Array = Net.players.keys()
	ids.sort()
	for id: int in ids:
		if _players_root.has_node(str(id)):
			continue
		var player: Player = PLAYER_SCENE.instantiate() as Player
		player.name = str(id)
		player.is_local = id == multiplayer.get_unique_id()
		_players_root.add_child(player)
		var sync: NetSync = NetSync.new()
		sync.name = "NetSync"
		player.add_child(sync)
		sync.configure(player, id)
		# Host (id 1) starts north, the guest south (sides swap per round in M4).
		var spawn: Marker3D = _arena.get_node(^"Layout/SpawnNorth" if id == 1 else ^"Layout/SpawnSouth") as Marker3D
		player.global_transform = spawn.global_transform
		if player.is_local:
			_hud.bind(player)


func _player(id: int) -> Player:
	return _players_root.get_node_or_null(str(id)) as Player


# --- Snapshots (host -> clients) -------------------------------------------------

func _send_snapshot() -> void:
	var entries: Array[Dictionary] = []
	for child: Node in _players_root.get_children():
		var sync: NetSync = child.get_node_or_null(^"NetSync") as NetSync
		if sync != null:
			entries.append(sync.snapshot_entry())
	_receive_snapshot.rpc(NetCodec.pack_snapshot({"tick": _tick, "players": entries}))


@rpc("authority", "call_remote", "unreliable_ordered", Net.CHANNEL_SNAPSHOT)
func _receive_snapshot(data: PackedByteArray) -> void:
	var snapshot: Dictionary = NetCodec.unpack_snapshot(data)
	var me: int = multiplayer.get_unique_id()
	for entry: Dictionary in snapshot["players"]:
		var player: Player = _player(int(entry["id"]))
		if player == null:
			continue
		player.stats.hp = float(entry["hp"])
		player.stats.mana = float(entry["mana"])
		player.stats.shield = float(entry["shield"])
		var sync: NetSync = player.get_node(^"NetSync") as NetSync
		if int(entry["id"]) == me:
			sync.reconcile(entry)
		else:
			sync.push_remote_state(entry)


# --- Casting (spec 04 §6) ---------------------------------------------------------

## Called by SpellCaster after the caster's composer paid mana and cooldown locally.
func request_cast(player: Player, spell: ResolvedSpell, origin: Vector3, direction: Vector3, target: Vector3) -> void:
	if Net.is_host():
		_broadcast_spawn(int(String(player.name)), spell, origin, direction, target)
	else:
		_request_cast.rpc_id(1, spell.form, spell.effect, origin, direction, target)


@rpc("any_peer", "call_remote", "reliable", Net.CHANNEL_RELIABLE)
func _request_cast(form: StringName, effect: StringName, origin: Vector3, direction: Vector3, target: Vector3) -> void:
	if not Net.is_host():
		return
	var caster_id: int = multiplayer.get_remote_sender_id()
	var player: Player = _player(caster_id)
	if player == null:
		return
	var spell: ResolvedSpell = SpellDB.resolve(player.composer.element_id, form, effect)
	if spell == null:
		return
	var reason: StringName = _validate(player, spell, origin)
	if reason != &"":
		_cast_rejected.rpc_id(caster_id, spell.key, reason)
		return
	player.stats.spend_mana(spell.mana_cost)
	player.stats.start_cooldown(spell.key, spell.cooldown)
	_broadcast_spawn(caster_id, spell, origin, direction, target)


func _validate(player: Player, spell: ResolvedSpell, origin: Vector3) -> StringName:
	if player.stats.is_dead:
		return &"dead"
	if player.stats.is_on_cooldown(spell.key):
		return &"cooldown"
	if not player.stats.can_afford(spell.mana_cost):
		return &"no_mana"
	if origin.distance_to(player.cast_origin.global_position) > MAX_ORIGIN_ERROR:
		return &"bad_origin"
	return &""


func _broadcast_spawn(caster_id: int, spell: ResolvedSpell, origin: Vector3, direction: Vector3, target: Vector3) -> void:
	_spawn_spell.rpc(caster_id, spell.element, spell.form, spell.effect, origin, direction, target)


@rpc("authority", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _spawn_spell(caster_id: int, element: StringName, form: StringName, effect: StringName, origin: Vector3, direction: Vector3, target: Vector3) -> void:
	var player: Player = _player(caster_id)
	var spell: ResolvedSpell = SpellDB.resolve(element, form, effect)
	if player == null or spell == null:
		return
	(player.get_node(^"SpellCaster") as SpellCaster).spawn(spell, origin, direction, target)


@rpc("authority", "call_remote", "reliable", Net.CHANNEL_RELIABLE)
func _cast_rejected(spell_key: StringName, reason: StringName) -> void:
	push_warning("cast %s rejected by host: %s" % [spell_key, reason])


# --- Debug ---------------------------------------------------------------------

func _bot_step(delta: float) -> void:
	_bot_clock += delta
	var phase: int = int(_bot_clock) % 4
	for action: StringName in [&"move_forward", &"move_left", &"move_right"]:
		Input.action_release(action)
	match phase:
		0:
			Input.action_press(&"move_forward")
		1:
			Input.action_press(&"move_left")
		2:
			Input.action_press(&"move_right")
	var me: Player = _player(multiplayer.get_unique_id())
	if me != null and fmod(_bot_clock, 2.0) < delta:
		me.composer.press_slot(0)
		me.composer.press_slot(0)


func _log_state() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for child: Node in _players_root.get_children():
		var player: Player = child as Player
		if player == null:
			continue
		var sync: NetSync = player.get_node_or_null(^"NetSync") as NetSync
		parts.append("%s[%s] pos=%s hp=%d corr=%.2f" % [player.name, NetSync.Role.keys()[sync.role] if sync else "?", player.global_position.snapped(Vector3.ONE * 0.01), roundi(player.stats.hp), sync.last_correction if sync else 0.0])
	print("[net] ", " | ".join(parts))
