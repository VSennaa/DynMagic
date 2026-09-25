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
	_bot = OS.get_cmdline_user_args().has("--bot")
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
	MatchState.changed.connect(_on_match_changed)
	_overlay = Label.new()
	_overlay.position = Vector2(16, 16)
	_overlay.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override(&"outline_size", 6)
	_overlay.visible = false
	_hud.add_child(_overlay)
	_sync_players()


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
		if Net.is_host():
			player.stats.died.connect(MatchState.report_death.bind(id))
	if Net.players.size() >= 2 and not _loaded_sent and _players_root.get_child_count() >= 2:
		_loaded_sent = true
		if Net.is_host() and not MatchState.active:
			MatchState.start_match(Lobby.overtime_setting, Lobby.arena_setting)
		MatchState.mark_loaded()


func get_player(id: int) -> Player:
	return _player(id)


func _player(id: int) -> Player:
	return _players_root.get_node_or_null(str(id)) as Player


# --- Snapshots (host -> clients) -------------------------------------------------

func _send_snapshot() -> void:
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
	MatchState.report_cast(caster_id, spell.form)
	_spawn_spell.rpc(caster_id, spell.element, spell.form, spell.effect, origin, direction, target)


@rpc("authority", "call_local", "reliable", Net.CHANNEL_RELIABLE)
func _spawn_spell(caster_id: int, element: StringName, form: StringName, effect: StringName, origin: Vector3, direction: Vector3, target: Vector3) -> void:
	var player: Player = _player(caster_id)
	var spell: ResolvedSpell = SpellDB.resolve(element, form, effect)
	if player == null or spell == null:
		return
	# Cone is instant: the host rewinds targets to what the remote caster saw (spec 04 §6).
	var rewind: float = 0.0
	if Net.is_host() and caster_id != multiplayer.get_unique_id() and spell.key == &"area_direct":
		rewind = Net.rtt_ms(caster_id) / 2000.0 + NetSync.INTERP_DELAY + Net.sim_latency_ms / 1000.0
	(player.get_node(^"SpellCaster") as SpellCaster).spawn(spell, origin, direction, target, rewind)


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
	_bot_draft()
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
	if event.is_action_pressed(&"net_overlay"):
		_overlay.visible = not _overlay.visible
	elif event.is_action_pressed(&"pause"):
		_toggle_pause_menu()


func _process(_delta: float) -> void:
	_match_label.text = _match_text()
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
	_update_overtime(view, round_number)
	_update_draft_panel(view)
	var frozen: bool = MatchState.is_frozen()
	for child: Node in _players_root.get_children():
		var player: Player = child as Player
		if player != null:
			player.frozen = frozen


## Round start: sides swap (north picks first), everyone respawns fresh.
func _start_round(north_id: int) -> void:
	for child: Node in _players_root.get_children():
		var player: Player = child as Player
		if player == null:
			continue
		var id: int = int(String(player.name))
		var spawn: Marker3D = _arena.get_node(^"Layout/SpawnNorth" if id == north_id else ^"Layout/SpawnSouth") as Marker3D
		player.global_transform = spawn.global_transform
		player.velocity = Vector3.ZERO
		player.stats.reset()
		player.composer.reset()
		player.active_aura = null
		player.active_guard = null


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or MatchState.phase() != MatchFsm.Phase.DRAFT:
		return
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
	match MatchState.phase():
		MatchFsm.Phase.DRAFT:
			var my_turn: bool = (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_A and int(view["north"]) == me) or (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_B and int(view["north"]) != me)
			var taken: String = ", ".join(PackedStringArray((view.get("elements", {}) as Dictionary).values().map(func(e: Variant) -> String: return String(e))))
			var runes: Array = (view.get("rune_offers", {}) as Dictionary).get(me, [])
			var rune_line: String = "" if runes.is_empty() else "\nRuna (5-7): %s" % ", ".join(PackedStringArray(runes.map(func(r: Variant) -> String: return String(r))))
			return "%s\nDRAFT 0:00 — %s  [escolhidos: %s]%s" % [head, "SUA VEZ: 1 Fogo · 2 Gelo · 3 Raio · 4 Vento" if my_turn else "oponente escolhendo...", taken, rune_line]
		MatchFsm.Phase.COUNTDOWN:
			return "%s\nPrepare-se..." % head
		MatchFsm.Phase.OVERTIME:
			return "%s\nOVERTIME: %s" % [head, String(view.get("overtime_rule", ""))]
		MatchFsm.Phase.ROUND_END:
			return "%s\nFim do round" % head
		MatchFsm.Phase.MATCH_END:
			return "%s\nFIM DE PARTIDA" % head
		MatchFsm.Phase.PAUSED:
			return "%s\nPAUSADO — oponente desconectado" % head
	return head

## Bot: pick the first free element when it is our turn in the draft.
func _bot_draft() -> void:
	var view: Dictionary = MatchState.view
	if MatchState.phase() != MatchFsm.Phase.DRAFT or view.is_empty():
		return
	var me: int = multiplayer.get_unique_id()
	var my_turn: bool = (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_A and int(view["north"]) == me) or (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_B and int(view["north"]) != me)
	if not my_turn or (view.get("elements", {}) as Dictionary).has(me):
		return
	var taken: Array = (view.get("elements", {}) as Dictionary).values()
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


## Esc: the match keeps running online; the menu only frees the mouse.
func _toggle_pause_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu = _panel("Pausa")
	var column: VBoxContainer = _menu.get_node(^"Column") as VBoxContainer
	column.add_child(UiKit.button("Voltar ao jogo", _toggle_pause_menu))
	column.add_child(UiKit.button("Desistir", _confirm_forfeit))


func _confirm_forfeit() -> void:
	var column: VBoxContainer = _menu.get_node(^"Column") as VBoxContainer
	column.add_child(UiKit.label("Desistir encerra a partida para você. Confirmar?", 18))
	column.add_child(UiKit.button("Sim, desistir", func() -> void:
		Net.close()
		SceneRouter.go_to(SceneRouter.MAIN_MENU)))


func _show_results(winner_id: int, reason: StringName) -> void:
	if _menu != null:
		_menu.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var me: int = multiplayer.get_unique_id()
	_menu = _panel("Vitória!" if winner_id == me else "Derrota")
	var column: VBoxContainer = _menu.get_node(^"Column") as VBoxContainer
	var score: Dictionary = MatchState.view.get("score", {})
	column.add_child(UiKit.label("Placar: %s   (%s)" % [" × ".join(PackedStringArray(score.values().map(func(v: Variant) -> String: return str(v)))), String(reason)], 20))
	for id: Variant in MatchState.stats:
		var s: Dictionary = MatchState.stats[id]
		var casts: Dictionary = s.get("casts", {})
		var hits: Dictionary = s.get("hits", {})
		var accuracy: PackedStringArray = PackedStringArray()
		for form: Variant in casts:
			accuracy.append("%s %d%%" % [form, roundi(100.0 * float(hits.get(form, 0)) / maxf(float(casts[form]), 1.0))])
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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(UiKit.INK, 0.92)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override(&"panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	column.add_child(UiKit.title(heading, 40))
	_hud.add_child(panel)
	return panel

# --- Draft screen (spec 06 §1) --------------------------------------------------------------

var _draft_panel: Control


## Four element cards (taken/other-turn cards disabled) plus the rune offer, over the frozen arena.
func _update_draft_panel(view: Dictionary) -> void:
	var drafting: bool = MatchState.phase() == MatchFsm.Phase.DRAFT
	if not drafting:
		if _draft_panel != null:
			_draft_panel.queue_free()
			_draft_panel = null
			if _menu == null:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if _draft_panel != null:
		_draft_panel.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var me: int = multiplayer.get_unique_id()
	var my_turn: bool = (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_A and int(view["north"]) == me) \
			or (int(view["draft_step"]) == MatchFsm.DraftStep.SIDE_B and int(view["north"]) != me)
	var elements: Dictionary = view.get("elements", {})
	var taken: Array = elements.values()
	_draft_panel = _panel("Escolha seu elemento" if my_turn else "Oponente escolhendo...")
	var column: VBoxContainer = _draft_panel.get_node(^"Column") as VBoxContainer
	var cards: Array[Control] = []
	for element_id: StringName in MatchFsm.ELEMENTS:
		var element: ElementDef = SpellDB.elements.get(element_id)
		var card: Button = UiKit.button(element.display_name if element != null else String(element_id), MatchState.pick_element.bind(element_id))
		card.custom_minimum_size = Vector2(130, 110)
		if element != null:
			card.add_theme_color_override(&"font_color", element.color)
		card.disabled = not my_turn or taken.has(element_id) or elements.has(me)
		cards.append(card)
	column.add_child(UiKit.row(cards))
	if elements.has(me):
		column.add_child(UiKit.label("Seu elemento: %s" % String(elements[me]), 18))
	var offers: Array = (view.get("rune_offers", {}) as Dictionary).get(me, [])
	if not offers.is_empty():
		column.add_child(UiKit.label("Runa do round (perdeu o anterior):", 18))
		var rune_buttons: Array[Control] = []
		for rune: Variant in offers:
			rune_buttons.append(UiKit.button(String(rune), MatchState.pick_rune.bind(StringName(rune))))
		column.add_child(UiKit.row(rune_buttons))
	column.add_child(UiKit.label("Tempo: %d s" % ceili(float(view.get("time_left", 0.0))), 18))
