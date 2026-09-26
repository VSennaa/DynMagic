extends Node3D
## Networked arena for M3: spawns one Player per connected peer, streams host
## snapshots and relays spell casts (docs/specs/04-networking.md sections 4-6).
## The match state machine (draft, rounds) arrives in M4.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SNAPSHOT_RATE: float = 30.0
## Dedicated server: seconds on the results screen before everyone returns to the lobby.
const RESULTS_TIME: int = 15
## Host rejects casts whose origin is farther than this from the caster's cast origin.
const MAX_ORIGIN_ERROR: float = 1.5
## Host rejects confirmed targets (Mark/Wall) farther than this from the caster (C10).
const MAX_TARGET_RANGE: float = 80.0
## Host rejects compose times outside these bounds (C10: unsanitized client numbers).
const MAX_COMPOSE_SECONDS: float = 60.0

var _snapshot_timer: float = 0.0
var _tick: int = 0
var _cast_id: int = 0
var _hud: Hud
## --bot: scripted input for headless smoke tests (walks, strafes and casts Bolt).
var _bot: bool = false
var _bot_clock: float = 0.0
var _log_timer: float = 0.0
var _overlay: Label
var _match_label: Label
var _last_round: int = 0
var _runes_applied_round: int = 0
var _core: ArcaneCore
var _core_granted_round: int = 0
var _collapse: CollapseZone
## Which overtime effects were applied this round: "rule", "collapse".
var _overtime_applied: Dictionary = {}
var _loaded_sent: bool = false

@onready var _players_root: Node3D = $Players
@onready var _arena: Node3D = $Arena


func _ready() -> void:
	add_to_group(&"net_match")
	Net.peer_joined.connect(func(_id: int, _name: String) -> void: _sync_players())
	Net.peer_left.connect(func(_id: int) -> void: _sync_players())
	Net.joined.connect(_sync_players)
	Net.disconnected.connect(func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU))
	MatchState.match_ended.connect(_show_results)
	MatchState.round_ended.connect(_on_round_ended)
	_bot = OS.get_cmdline_user_args().has("--bot")
	# C15: a dedicated server keeps the simulation but skips every presentation layer.
	if Net.dedicated:
		Engine.physics_ticks_per_second = 60
	else:
		_build_presentation()
	MatchState.changed.connect(_on_match_changed)
	_sync_players()


func _build_presentation() -> void:
	_hud = Hud.new()
	add_child(_hud)
	_match_label = Label.new()
	_match_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_match_label.position = Vector2(-300, 12)
	_match_label.custom_minimum_size = Vector2(600, 0)
	_match_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_label.add_theme_font_size_override(&"font_size", 22)
	_match_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_match_label.add_theme_constant_override(&"outline_size", 6)
	_hud.add_child(_match_label)
	_pause = PauseMenu.new()
	_pause.leave_text = "Sair" if Net.spectating else "Desistir"
	add_child(_pause)
	if Net.spectating:
		_spectator = SpectatorCamera.new()
		_spectator.players_provider = _players_in_order
		add_child(_spectator)
	_overlay = Label.new()
	_overlay.position = Vector2(16, 16)
	_overlay.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override(&"outline_size", 6)
	_overlay.visible = false
	_hud.add_child(_overlay)


func _physics_process(delta: float) -> void:
	if _bot:
		_bot_step(delta)
	_log_timer -= delta
	if _log_timer <= 0.0:
		_log_timer = 2.0
		_log_state()
	if Net.is_host() and _core != null:
		var by_id: Dictionary = {}
		for id: int in Net.players:
			by_id[id] = _player(id)
		_core.host_tick(delta, by_id)
	if Net.is_host() and _collapse != null:
		var alive: Array[Player] = []
		for child: Node in _players_root.get_children():
			if child is Player:
				alive.append(child as Player)
		_collapse.host_tick(delta, alive)
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
			if MatchState.active:
				continue
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
		player.add_child(Footsteps.new())
		var sync: NetSync = NetSync.new()
		sync.name = "NetSync"
		player.add_child(sync)
		sync.configure(player, id)
		# Host (id 1) starts north, the guest south (sides swap per round in M4).
		var spawn: Marker3D = _arena.get_node(^"Layout/SpawnNorth" if id == 1 else ^"Layout/SpawnSouth") as Marker3D
		player.global_transform = spawn.global_transform
		if player.is_local and _hud != null:
			_hud.bind(player)
		if Net.is_host():
			player.stats.died.connect(func() -> void: MatchState.report_death(int(String(player.name))))
	for child: Node in _players_root.get_children():
		if child is Player and not (child as Player).is_local and _hud != null:
			_hud.threat = child as Node3D
	if Net.players.size() >= 2 and not _loaded_sent and _players_root.get_child_count() >= 2:
		_loaded_sent = true
		if Net.is_host() and not MatchState.active:
			MatchState.start_match(Lobby.overtime_setting, Lobby.arena_setting)
		if not Net.dedicated and not Net.spectating:
			MatchState.mark_loaded()


func get_player(id: int) -> Player:
	return _player(id)


func _player(id: int) -> Player:
	return _players_root.get_node_or_null(str(id)) as Player


func reassign_player(old_id: int, new_id: int) -> void:
	var player: Player = _player(old_id)
	if player == null:
		return
	player.name = str(new_id)
	(player.get_node(^"NetSync") as NetSync).reset_transport(new_id)
	if _core != null:
		_core.replace_player(old_id, new_id)


## Reliable bootstrap precedes the phase-resume RPC and the first live snapshot.
func restore_client(id: int) -> void:
	var state: Array[Dictionary] = []
	for child: Node in _players_root.get_children():
		var player: Player = child as Player
		state.append({"id": int(String(player.name)), "transform": player.transform,
			"velocity": player.velocity, "pitch": player.get_pitch(), "rune": player.rune,
			"stats": player.stats.export_state(), "runtime": ReconnectState.player_state(player)})
	_restore_client.rpc_id(id, state, MatchState.fsm.round_number, MatchState.fsm.arena, _runes_applied_round,
		_core_granted_round, ReconnectState.capture_world(self), _collapse.elapsed if _collapse != null else -1.0)


@rpc("authority", "call_remote", "reliable", Net.CHANNEL_RELIABLE)
func _restore_client(state: Array[Dictionary], round_number: int, arena_id: StringName, runes_round: int, core_round: int, spells: Array[Dictionary], collapse_elapsed: float) -> void:
	_last_round = round_number
	_runes_applied_round = runes_round
	_core_granted_round = core_round
	(_arena.get_node(^"Layout") as ArenaBuilder).variant = arena_id
	for entry: Dictionary in state:
		var player: Player = _player(int(entry["id"]))
		if player == null:
			continue
		player.apply_rune(entry["rune"])
		player.transform = entry["transform"]
		player.velocity = entry["velocity"]
		player.set_look(player.rotation.y, float(entry["pitch"]))
		player.stats.import_state(entry["stats"])
		ReconnectState.restore_player(player, entry["runtime"])
	ReconnectState.restore_world(self, spells)
	if collapse_elapsed >= 0.0:
		_collapse = CollapseZone.new()
		add_child(_collapse)
		_collapse.elapsed = collapse_elapsed


# --- Snapshots (host -> clients) -------------------------------------------------

func _send_snapshot() -> void:
	if not MatchState.active:
		return
	var entries: Array[Dictionary] = []
	for child: Node in _players_root.get_children():
		var sync: NetSync = child.get_node_or_null(^"NetSync") as NetSync
		if sync != null:
			entries.append(sync.snapshot_entry())
	var data: PackedByteArray = NetCodec.pack_snapshot({"tick": _tick, "players": entries})
	Net.simulate_send(func() -> void: _receive_snapshot.rpc(data))


@rpc("authority", "call_remote", "unreliable_ordered", Net.CHANNEL_SNAPSHOT)
func _receive_snapshot(data: PackedByteArray) -> void:
	var snapshot: Dictionary = NetCodec.unpack_snapshot(data)
	var me: int = multiplayer.get_unique_id()
	for entry: Dictionary in snapshot["players"]:
		var player: Player = _player(int(entry["id"]))
		if player == null:
			continue
		var gameplay: Dictionary = entry["gameplay"]
		player.stats.import_state(gameplay["stats"])
		ReconnectState.restore_player(player, gameplay["runtime"])
		var sync: NetSync = player.get_node(^"NetSync") as NetSync
		if int(entry["id"]) == me:
			sync.reconcile(entry)
		else:
			sync.push_remote_state(entry)


# --- Casting (spec 04 §6) ---------------------------------------------------------

## Called by SpellCaster after the caster's composer paid mana and cooldown locally.
func request_cast(player: Player, spell: ResolvedSpell, origin: Vector3, direction: Vector3, target: Vector3) -> void:
	if Net.is_host():
		_broadcast_spawn(int(String(player.name)), spell, origin, direction, target, player.composer.compose_seconds)
	else:
		_request_cast.rpc_id(1, spell.form, spell.effect, origin, direction, target, player.composer.is_recasting, player.composer.compose_seconds)


@rpc("any_peer", "call_remote", "reliable", Net.CHANNEL_RELIABLE)
func _request_cast(form: StringName, effect: StringName, origin: Vector3, direction: Vector3, target: Vector3, is_recast: bool, compose_seconds: float) -> void:
	if not Net.is_host():
		return
	var caster_id: int = multiplayer.get_remote_sender_id()
	var player: Player = _player(caster_id)
	if player == null:
		return
	var spell: ResolvedSpell = SpellDB.resolve(player.composer.element_id, form, effect)
	if spell == null:
		return
	var cost: float = player.mana_cost_for(spell, is_recast)
	var reason: StringName = _validate(player, spell, origin, cost)
	if reason != &"":
		_cast_rejected.rpc_id(caster_id, spell.key, reason, player.stats.export_state())
		return
	if not origin.is_finite() or not direction.is_finite() or not target.is_finite() or direction.length_squared() < 0.01 or not is_finite(compose_seconds):
		_cast_rejected.rpc_id(caster_id, spell.key, &"invalid", player.stats.export_state())
		return
	if target.distance_to(player.global_position) > MAX_TARGET_RANGE or compose_seconds > MAX_COMPOSE_SECONDS:
		_cast_rejected.rpc_id(caster_id, spell.key, &"invalid", player.stats.export_state())
		return
	if player.cast_lockout > 0.0 or (is_recast and (player.composer.last_spell == null or player.composer.last_spell.key != spell.key)):
		_cast_rejected.rpc_id(caster_id, spell.key, &"lockout", player.stats.export_state())
		return
	# D1: RMB only repeats confirmed spells; the Arrow uses charges, not a cooldown.
	if is_recast and spell.is_quick():
		_cast_rejected.rpc_id(caster_id, spell.key, &"invalid", player.stats.export_state())
		return
	# D1 + round 8: the Arrow needs a charge and the 0.3 s minimum spacing between shots.
	if spell.key == Player.ARROW_KEY and not player.arrow_ready():
		_cast_rejected.rpc_id(caster_id, spell.key, &"cooldown", player.stats.export_state())
		return
	player.set_look(atan2(-direction.x, -direction.z), asin(clampf(direction.normalized().y, -1.0, 1.0)))
	var params: Array = (player.get_node(^"SpellCaster") as SpellCaster).cast_params(spell)
	origin = params[0]
	direction = params[1]
	target = params[2]
	player.cast_lockout = SpellComposer.CAST_LOCKOUT
	if player.has_overcharge():
		player.overcharge_casts -= 1
	player.stats.spend_mana(cost)
	if spell.key == Player.ARROW_KEY:
		player.consume_arrow_charge()
	else:
		player.stats.start_cooldown(spell.key, player.cooldown_for(spell))
	player.composer.last_spell = spell
	_broadcast_spawn(caster_id, spell, origin, direction, target, -1.0 if is_recast else compose_seconds)


func _validate(player: Player, spell: ResolvedSpell, origin: Vector3, cost: float) -> StringName:
	if player.stats.is_dead:
		return &"dead"
	if player.frozen:
		return &"frozen"
	if player.stats.is_on_cooldown(spell.key):
		return &"cooldown"
	if not player.stats.can_afford(cost):
		return &"no_mana"
	if not origin.is_finite() or origin.distance_to(player.cast_origin.global_position) > MAX_ORIGIN_ERROR:
		return &"bad_origin"
	return &""


func _broadcast_spawn(caster_id: int, spell: ResolvedSpell, origin: Vector3, direction: Vector3, target: Vector3, compose_seconds: float = -1.0) -> void:
	MatchState.report_cast(caster_id, spell.form, compose_seconds)
	_cast_id += 1
	_spawn_spell.rpc(caster_id, spell.element, spell.form, spell.effect, origin, direction, target, _cast_id)


@rpc("authority", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _spawn_spell(caster_id: int, element: StringName, form: StringName, effect: StringName, origin: Vector3, direction: Vector3, target: Vector3, cast_id: int) -> void:
	var player: Player = _player(caster_id)
	var spell: ResolvedSpell = SpellDB.resolve(element, form, effect)
	if player == null or spell == null:
		return
	spell = spell.with_params({&"network_id": cast_id})
	# Cone is instant: the host rewinds targets to what the remote caster saw (spec 04 §6).
	var rewind: float = 0.0
	if Net.is_host() and caster_id != multiplayer.get_unique_id() and spell.key == &"area_direct":
		rewind = Net.rtt_ms(caster_id) / 2000.0 + NetSync.INTERP_DELAY + Net.sim_latency_ms / 1000.0
	(player.get_node(^"SpellCaster") as SpellCaster).spawn(spell, origin, direction, target, rewind)


@rpc("authority", "call_remote", "reliable", Net.CHANNEL_RELIABLE)
func _cast_rejected(spell_key: StringName, reason: StringName, state: Dictionary) -> void:
	var player: Player = _player(multiplayer.get_unique_id())
	if player != null:
		player.stats.import_state(state)
		player.composer.cast_rejected.emit(SpellDB.resolve(player.composer.element_id, StringName(spell_key.get_slice("_", 0)), StringName(spell_key.get_slice("_", 1))), reason)


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
	_bot_draft()
	# Poll the confirm request: at 60 Hz a per-frame RPC would flood the reliable channel.
	if MatchState.phase() == MatchFsm.Phase.DRAFT and fmod(_bot_clock, 0.5) < delta:
		MatchState.confirm_draft()
	_bot_aim(me)
	if me != null and not me.frozen and fmod(_bot_clock, 2.0) < delta:
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

func _unhandled_input(event: InputEvent) -> void:
	if _overlay != null and event.is_action_pressed(&"net_overlay"):
		_overlay.visible = not _overlay.visible


func _process(_delta: float) -> void:
	if _match_label == null:
		return  # C15: dedicated server, no presentation.
	_match_label.text = _match_text() + ("\n" + _spectator.mode_text() if _spectator != null else "")
	if not _overlay.visible:
		return
	var me: Player = _player(multiplayer.get_unique_id())
	var sync: NetSync = me.get_node_or_null(^"NetSync") as NetSync if me != null else null
	var ping: float = 0.0
	if Net.is_host():
		for id: int in Net.players:
			if id != 1:
				ping = Net.rtt_ms(id)
	else:
		ping = Net.rtt_ms(1)
	_overlay.text = "%s  ping %d ms  tick %d\nsim +%d±%d ms  perda %d%%\ncorreção %.2f m  jogadores %d" % [
		"HOST" if Net.is_host() else "CLIENTE", roundi(ping), _tick,
		roundi(Net.sim_latency_ms), roundi(Net.sim_jitter_ms), roundi(Net.sim_loss * 100.0),
		sync.last_correction if sync != null else 0.0, Net.players.size()]

# --- Match flow (M4) ------------------------------------------------------------------

func _on_match_changed() -> void:
	var paused: bool = MatchState.phase() == MatchFsm.Phase.PAUSED
	process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	if paused:
		_match_label.text = _match_text() + ("\n" + _spectator.mode_text() if _spectator != null else "")
		for child: Node in _players_root.get_children():
			(child as Player).frozen = true
		return
	var view: Dictionary = MatchState.view
	var round_number: int = int(view.get("round", 0))
	if round_number != _last_round and MatchState.phase() == MatchFsm.Phase.DRAFT:
		_last_round = round_number
		var layout: ArenaBuilder = _arena.get_node(^"Layout") as ArenaBuilder
		var arena_id: StringName = view.get("arena", &"A")
		if layout.variant != arena_id:
			layout.variant = arena_id  # setter rebuilds the greybox
		_start_round(int(view.get("north", 1)))
	var elements: Dictionary = view.get("elements", {})
	for id: Variant in elements:
		var player: Player = _player(int(id))
		if player != null:
			player.composer.element_id = elements[id]
	# Runes are revealed when the draft ends; apply them once per round at the countdown.
	if MatchState.phase() == MatchFsm.Phase.COUNTDOWN and _runes_applied_round != round_number:
		_runes_applied_round = round_number
		var runes: Dictionary = view.get("runes", {})
		for child: Node in _players_root.get_children():
			var p: Player = child as Player
			if p != null:
				p.apply_rune(runes.get(int(String(p.name)), &""))
	_update_core(view, round_number)
	if _hud != null:
		_hud.set_core_progress(float((view.get("core_progress", {}) as Dictionary).get(multiplayer.get_unique_id(), 0.0)))
	_update_overtime(view, round_number)
	_update_draft_panel(view)
	var frozen: bool = MatchState.is_frozen()
	for child: Node in _players_root.get_children():
		var player: Player = child as Player
		if player != null:
			player.frozen = frozen


## Round start: sides swap (north picks first), everyone respawns fresh.
func _start_round(north_id: int) -> void:
	for object: Node in get_children():
		if object is SpellNode or object is Wall:
			remove_child(object)
			object.queue_free()
	for child: Node in _players_root.get_children():
		var player: Player = child as Player
		if player == null:
			continue
		var id: int = int(String(player.name))
		var spawn: Marker3D = _arena.get_node(^"Layout/SpawnNorth" if id == north_id else ^"Layout/SpawnSouth") as Marker3D
		player.global_transform = spawn.global_transform
		player.reset_round()
		(player.get_node(^"NetSync") as NetSync).reset_transport(id)


func _unhandled_key_input(event: InputEvent) -> void:
	_scoreboard_input(event)
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or MatchState.phase() != MatchFsm.Phase.DRAFT:
		return
	if key.keycode == KEY_ENTER:
		MatchState.confirm_draft()
	var element_keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
	var rune_keys: Array[Key] = [KEY_5, KEY_6, KEY_7]
	if element_keys.has(key.keycode):
		MatchState.pick_element(MatchFsm.ELEMENTS[element_keys.find(key.keycode)])
	elif rune_keys.has(key.keycode):
		var offers: Array = (MatchState.view.get("rune_offers", {}) as Dictionary).get(multiplayer.get_unique_id(), [])
		var index: int = rune_keys.find(key.keycode)
		if index < offers.size():
			MatchState.pick_rune(offers[index])


func _match_text() -> String:
	var view: Dictionary = MatchState.view
	if view.is_empty():
		return "Aguardando oponente..."
	var me: int = multiplayer.get_unique_id()
	var score: Dictionary = view.get("score", {})
	var other: int = 0
	for id: Variant in score:
		if int(id) != me:
			other = int(id)
	var clock: String = "%d:%02d" % [int(view["time_left"]) / 60, int(view["time_left"]) % 60]
	var head: String = "Round %d   Você %d × %d Oponente   %s" % [int(view["round"]), int(score.get(me, 0)), int(score.get(other, 0)), clock]
	if Net.spectating or Net.dedicated:
		var names: PackedStringArray = PackedStringArray()
		for id: Variant in score:
			names.append("%s %d" % [Net.players.get(int(id), str(id)), int(score[id])])
		head = "Round %d   %s   %s" % [int(view["round"]), " × ".join(names), clock]
	match MatchState.phase():
		MatchFsm.Phase.DRAFT:
			var my_turn: bool = (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_A and int(view["north"]) == me) or (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_B and int(view["north"]) != me)
			var taken_names: PackedStringArray = PackedStringArray()
			for element: Variant in (view.get("elements", {}) as Dictionary).values():
				taken_names.append(Glossary.element(StringName(element)))
			var runes: Array = (view.get("rune_offers", {}) as Dictionary).get(me, [])
			var rune_line: String = "" if runes.is_empty() else "\nRuna (5-7): %s" % ", ".join(PackedStringArray(runes.map(func(r: Variant) -> String: return Glossary.rune(StringName(r)))))
			return "%s\nESCOLHA — %s  [escolhidos: %s]%s" % [head, "SUA VEZ: 1 Fogo · 2 Gelo · 3 Raio · 4 Vento" if my_turn else "oponente escolhendo...", ", ".join(taken_names), rune_line]
		MatchFsm.Phase.COUNTDOWN:
			return "%s\nPrepare-se..." % head
		MatchFsm.Phase.OVERTIME:
			return "%s\nPRORROGAÇÃO: %s" % [head, Glossary.overtime(StringName(view.get("overtime_rule", "")))]
		MatchFsm.Phase.ROUND_END:
			return "%s\nFim do round" % head
		MatchFsm.Phase.MATCH_END:
			return "%s\nFIM DE PARTIDA" % head
		MatchFsm.Phase.PAUSED:
			return "%s\nPAUSADO — oponente desconectado" % head
	return head

## Bot: pick the first free element when it is our turn, plus the first offered rune.
## Both are needed for `confirm_draft` to succeed, so a full match runs unattended.
func _bot_draft() -> void:
	var view: Dictionary = MatchState.view
	if MatchState.phase() != MatchFsm.Phase.DRAFT or view.is_empty():
		return
	var me: int = multiplayer.get_unique_id()
	var elements: Dictionary = view.get("elements", {})
	var offers: Array = (view.get("rune_offers", {}) as Dictionary).get(me, [])
	var runes: Dictionary = view.get("runes", {})
	if not offers.is_empty() and not runes.has(me):
		MatchState.pick_rune(StringName(offers[0]))
	var my_turn: bool = (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_A and int(view["north"]) == me) or (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_B and int(view["north"]) != me)
	if not my_turn or elements.has(me):
		return
	var taken: Array = elements.values()
	for element: StringName in MatchFsm.ELEMENTS:
		if not taken.has(element):
			MatchState.pick_element(element)
			return

## Spawns the Arcane Core at the arena centre when the host says so; grants Overcharge on capture.
func _update_core(view: Dictionary, round_number: int) -> void:
	var holder: int = int(view.get("core_holder", 0))
	var should_exist: bool = bool(view.get("core_spawned", false)) and holder == 0 \
			and (MatchState.phase() == MatchFsm.Phase.COMBAT or MatchState.phase() == MatchFsm.Phase.OVERTIME)
	if should_exist and _core == null:
		_core = ArcaneCore.create()
		add_child(_core)
		_core.global_position = Vector3(0, 3.0, 0)  # on top of Arena A's central pillar
		_core.captured.connect(MatchState.report_core)
	elif not should_exist and _core != null:
		_core.queue_free()
		_core = null
	if holder != 0 and _core_granted_round != round_number:
		_core_granted_round = round_number
		var player: Player = _player(holder)
		if player != null:
			player.grant_overcharge()

## Overtime rules (spec 02 §5). Sudden Death and Mana Surge fall back to Collapse after 30 s / 20 s.
func _update_overtime(view: Dictionary, round_number: int) -> void:
	var in_overtime: bool = MatchState.phase() == MatchFsm.Phase.OVERTIME
	if not in_overtime:
		if _collapse != null:
			_collapse.queue_free()
			_collapse = null
		if not _overtime_applied.is_empty():
			_overtime_applied.clear()
			_set_overtime_flags(false, false)
		return
	var rule: StringName = view.get("overtime_rule", &"")
	var elapsed: float = MatchFsm.OVERTIME_LIMIT - float(view.get("time_left", 0.0))
	if _overtime_applied.get("rule", -1) != round_number:
		_overtime_applied["rule"] = round_number
		if rule == &"sudden_death":
			for child: Node in _players_root.get_children():
				var player: Player = child as Player
				if player != null:
					player.stats.hp = 1.0
					player.stats.clear_shield()
			_set_overtime_flags(true, false)
		elif rule == &"mana_surge":
			_set_overtime_flags(false, true)
	var collapse_now: bool = rule == &"collapse" \
			or (rule == &"sudden_death" and elapsed >= 30.0) \
			or (rule == &"mana_surge" and elapsed >= 20.0)
	if rule == &"mana_surge" and elapsed >= 20.0:
		_set_overtime_flags(false, false)
	if collapse_now and _collapse == null:
		_collapse = CollapseZone.new()
		add_child(_collapse)


func _set_overtime_flags(sudden: bool, surge: bool) -> void:
	for child: Node in _players_root.get_children():
		var player: Player = child as Player
		if player != null:
			player.sudden_death = sudden
			player.mana_surge = surge

# --- Pause and results (spec 06 §1) ------------------------------------------------------

var _menu: Control
var _pause: PauseMenu
var _spectator: SpectatorCamera


func _on_round_ended(winner_id: int, reason: StringName) -> void:
	AudioBus.play_ui("bell", -8.0)
	if _hud == null:
		return
	var me: int = multiplayer.get_unique_id()
	if winner_id == 0:
		_hud.show_banner("Round empatado — %s" % Glossary.reason(reason), Color(0.9, 0.9, 0.9))
	elif winner_id == me:
		_hud.show_banner("Você venceu o round — %s" % Glossary.reason(reason), Color(0.6, 1.0, 0.6))
	else:
		_hud.show_banner("Oponente venceu o round — %s" % Glossary.reason(reason), Color(1.0, 0.55, 0.55))


func _show_results(winner_id: int, reason: StringName) -> void:
	if Net.dedicated:
		# Dedicated server: no UI; give players time to read the results, then back to the lobby.
		print("[server] match over: winner %d (%s); returning to lobby in %d s" % [winner_id, reason, RESULTS_TIME])
		await get_tree().create_timer(RESULTS_TIME).timeout
		Lobby.return_to_lobby()
		return
	_pause.close()
	if _menu != null:
		_menu.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var me: int = multiplayer.get_unique_id()
	if _hud != null:
		_hud.show_banner("Vitória!" if winner_id == me else ("Empate" if winner_id == 0 else "Derrota"), Color(0.6, 1.0, 0.6) if winner_id == me else Color(1.0, 0.55, 0.55))
	var title: String = "Vitória!" if winner_id == me else "Derrota"
	_menu = _panel(title)
	var column: VBoxContainer = _menu.get_node(^"Column") as VBoxContainer
	var score: Dictionary = MatchState.view.get("score", {})
	column.add_child(UiKit.label("Placar: %s   (%s)" % [" × ".join(PackedStringArray(score.values().map(func(v: Variant) -> String: return str(v)))), Glossary.reason(reason)], 20))
	for id: Variant in MatchState.stats:
		var s: Dictionary = MatchState.stats[id]
		var compose_text: String = "%.2f s" % ComposeMetrics.average(s) if int(s.get("compose_count", 0)) > 0 else "—"
		column.add_child(UiKit.label("%s · Composição média: %s" % [Net.players.get(int(id), str(id)), compose_text], 18))
		var casts: Dictionary = s.get("casts", {})
		var hits: Dictionary = s.get("hits", {})
		var accuracy: PackedStringArray = PackedStringArray()
		for form: Variant in casts:
			accuracy.append("%s %d%%" % [Glossary.form(StringName(form)), roundi(100.0 * float(hits.get(form, 0)) / maxf(float(casts[form]), 1.0))])
		column.add_child(UiKit.label("%s — dano causado %d, recebido %d, Núcleos %d\nprecisão: %s" % [
			Net.players.get(int(id), str(id)), roundi(float(s["dealt"])), roundi(float(s["taken"])), int(s["cores"]), ", ".join(accuracy)], 18))
	column.add_child(UiKit.button("Voltar ao lobby", func() -> void:
		MatchState.active = false
		Lobby.ready_flags.clear()
		SceneRouter.go_to(SceneRouter.LOBBY)))
	column.add_child(UiKit.button("Menu principal", func() -> void:
		Net.close()
		SceneRouter.go_to(SceneRouter.MAIN_MENU)))


func _panel(heading: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-320, -240)
	panel.custom_minimum_size = Vector2(640, 0)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	column.add_child(UiKit.title(heading, 40))
	_hud.add_child(panel)
	return panel

# --- Draft screen (spec 06 §1) --------------------------------------------------------------

var _draft_panel: Control
var _draft_title: Label
var _draft_cards: Array[Button] = []
var _draft_owned: Label
var _draft_rune_label: Label
var _draft_rune_row: HBoxContainer
var _draft_rune_buttons: Array[Button] = []
var _draft_rune_desc: Label
var _draft_timer: Label
var _draft_offers: Array = []


## C5: the panel is built once per draft and refreshed in place, so a 1 Hz state sync
## cannot destroy the button under the player's cursor.
func _update_draft_panel(view: Dictionary) -> void:
	if Net.dedicated or Net.spectating:
		return
	var drafting: bool = MatchState.phase() == MatchFsm.Phase.DRAFT
	if not drafting:
		if _draft_panel != null:
			_draft_panel.queue_free()
			_draft_panel = null
			_draft_cards.clear()
			_draft_rune_buttons.clear()
			if _menu == null and not PauseMenu.is_open:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	var me: int = multiplayer.get_unique_id()
	var my_turn: bool = (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_A and int(view["north"]) == me) \
			or (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_B and int(view["north"]) != me)
	var elements: Dictionary = view.get("elements", {})
	var taken: Array = elements.values()
	var offers: Array = (view.get("rune_offers", {}) as Dictionary).get(me, [])
	_draft_offers = offers
	if _draft_panel == null:
		_build_draft_panel()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_draft_title.text = "Escolha seu elemento" if my_turn else "Oponente escolhendo..."
	for i: int in _draft_cards.size():
		var element_id: StringName = MatchFsm.ELEMENTS[i]
		var card: Button = _draft_cards[i]
		card.disabled = not my_turn or taken.has(element_id) or elements.has(me)
		card.modulate = Color(0.65, 1.0, 0.65) if elements.get(me, &"") == element_id else Color(1, 1, 1)
	_draft_owned.visible = elements.has(me)
	if elements.has(me):
		_draft_owned.text = "Seu elemento: %s" % Glossary.element(elements[me])
	_draft_rune_label.visible = not offers.is_empty()
	_draft_rune_row.visible = not offers.is_empty()
	_draft_rune_desc.visible = not offers.is_empty()
	for i: int in _draft_rune_buttons.size():
		var button: Button = _draft_rune_buttons[i]
		button.visible = i < offers.size()
		if i < offers.size():
			var rune_id: StringName = StringName(offers[i])
			button.text = "%d %s" % [i + 5, Glossary.rune(rune_id)]
			button.tooltip_text = Glossary.rune_description(rune_id)
	if not offers.is_empty():
		var descriptions: PackedStringArray = PackedStringArray()
		for rune: Variant in offers:
			descriptions.append("%s: %s" % [Glossary.rune(StringName(rune)), Glossary.rune_description(StringName(rune))])
		_draft_rune_desc.text = "   ".join(descriptions)
	_draft_timer.text = "Tempo: %d s" % ceili(float(view.get("time_left", 0.0)))


func _build_draft_panel() -> void:
	_draft_panel = _panel("Escolha seu elemento")
	var column: VBoxContainer = _draft_panel.get_node(^"Column") as VBoxContainer
	_draft_title = column.get_child(0) as Label
	var cards: Array[Control] = []
	for element_id: StringName in MatchFsm.ELEMENTS:
		var element: ElementDef = SpellDB.elements.get(element_id)
		var card: Button = UiKit.button(element.display_name if element != null else Glossary.element(element_id), MatchState.pick_element.bind(element_id))
		card.custom_minimum_size = Vector2(130, 110)
		if element != null:
			card.add_theme_color_override(&"font_color", element.color)
		_draft_cards.append(card)
		cards.append(card)
	column.add_child(UiKit.row(cards))
	_draft_owned = UiKit.label("", 18)
	column.add_child(_draft_owned)
	_draft_rune_label = UiKit.label("Runa do round (perdeu o anterior):", 18)
	column.add_child(_draft_rune_label)
	_draft_rune_row = HBoxContainer.new()
	_draft_rune_row.add_theme_constant_override(&"separation", 12)
	column.add_child(_draft_rune_row)
	_draft_rune_buttons.clear()
	for i: int in 3:
		var button: Button = UiKit.button("", _pick_rune_index.bind(i))
		_draft_rune_row.add_child(button)
		_draft_rune_buttons.append(button)
	_draft_rune_desc = UiKit.label("", 16)
	_draft_rune_desc.modulate = Color(1, 1, 1, 0.7)
	_draft_rune_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_draft_rune_desc)
	_draft_timer = UiKit.label("", 18)
	column.add_child(_draft_timer)


func _pick_rune_index(index: int) -> void:
	if index < _draft_offers.size():
		MatchState.pick_rune(StringName(_draft_offers[index]))

## Host: capture progress ratios for the view (clients get them once per second).
func core_progress() -> Dictionary:
	var out: Dictionary = {}
	if _core != null:
		for id: int in Net.players:
			out[id] = _core.progress_ratio(id)
	return out


# --- Scoreboard (Tab) ---------------------------------------------------------------------

var _scoreboard: Control


func _scoreboard_input(event: InputEvent) -> void:
	if event.is_action(&"scoreboard"):
		if event.is_pressed() and _scoreboard == null:
			_scoreboard = _panel("Placar")
			var column: VBoxContainer = _scoreboard.get_node(^"Column") as VBoxContainer
			var view: Dictionary = MatchState.view
			var score: Dictionary = view.get("score", {})
			var elements: Dictionary = view.get("elements", {})
			var runes: Dictionary = view.get("runes", {})
			for id: int in Net.players:
				var player: Player = _player(id)
				column.add_child(UiKit.label("%s — %d rounds — %s%s — HP %d" % [
					Net.players[id], int(score.get(id, 0)), Glossary.element(StringName(elements.get(id, &""))),
					" + " + Glossary.rune(StringName(runes[id])) if runes.has(id) else "", roundi(player.stats.hp) if player else 0], 20))
			column.add_child(UiKit.label("Round %d · arena %s" % [int(view.get("round", 0)), String(view.get("arena", "A"))], 18))
			_add_spell_card(column)
		elif not event.is_pressed() and _scoreboard != null:
			_scoreboard.queue_free()
			_scoreboard = null

## Bot: face the opponent so its Bolts can actually land (full-match tests end by kills).
func _bot_aim(me: Player) -> void:
	if me == null or me.frozen:
		return
	for child: Node in _players_root.get_children():
		var other: Player = child as Player
		if other == null or other == me:
			continue
		var to: Vector3 = other.global_position - me.global_position
		me.set_look(atan2(-to.x, -to.z), 0.0)
		return

## C14: 3×3 card of the local player's spells for this round.
func _add_spell_card(column: VBoxContainer) -> void:
	var local: Player = _player(multiplayer.get_unique_id())
	if local == null:
		return
	var column_header: Label = UiKit.label("Seu grimório — %s" % Glossary.element(local.composer.element_id), 18)
	column.add_child(column_header)
	for form: StringName in SpellDB.FORMS:
		var cells: Array[Control] = []
		for effect: StringName in SpellDB.EFFECTS:
			var spell: ResolvedSpell = SpellDB.resolve(local.composer.element_id, form, effect)
			var name: String = spell.display_name if spell != null else "%s %s" % [Glossary.form(form), Glossary.effect(effect)]
			var mode: String = "rápida" if spell != null and spell.is_quick() else "confirmada"
			var cell: Label = UiKit.label("%s\n%s" % [name, mode], 14)
			cell.custom_minimum_size = Vector2(140, 0)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if spell != null:
				cell.add_theme_color_override(&"font_color", spell.color.lerp(Color.WHITE, 0.3))
			cells.append(cell)
		column.add_child(UiKit.row(cells))


## Players sorted by id (stable order for the spectator's 1/2 keys).
func _players_in_order() -> Array:
	var list: Array = []
	for child: Node in _players_root.get_children():
		if child is Player:
			list.append(child)
	list.sort_custom(func(a: Node, b: Node) -> bool: return int(String(a.name)) < int(String(b.name)))
	return list


func destroy_wall(wall_name: String) -> void:
	if Net.is_host():
		_destroy_wall.rpc(wall_name)


@rpc("authority", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _destroy_wall(wall_name: String) -> void:
	var wall: Wall = get_node_or_null(NodePath(wall_name)) as Wall
	if wall != null:
		wall.collision_layer = 0
		wall.queue_free()
