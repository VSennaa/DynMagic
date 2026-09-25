extends Control
## Lobby (spec 06 §1): two player cards with ready flags, the host's rules, Ready / Start / Leave.

var _players: VBoxContainer
var _rules: Label
var _ready_button: Button
var _start_button: Button
var _is_ready: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# --bot clients (load tests against a dedicated server) ready up on their own.
	if OS.get_cmdline_user_args().has("--bot") and not Net.is_host():
		Lobby.set_ready.call_deferred(true)
	var column: VBoxContainer = UiKit.screen(self)
	column.add_child(UiKit.title(Net.lobby_name if Net.is_host() else "Sala", 40))
	_players = VBoxContainer.new()
	column.add_child(_players)
	_rules = UiKit.label("", 18)
	column.add_child(_rules)
	_ready_button = UiKit.button("Pronto", _toggle_ready)
	column.add_child(_ready_button)
	_start_button = UiKit.button("Iniciar partida", Lobby.start_match)
	_start_button.visible = Net.is_host()
	column.add_child(_start_button)
	column.add_child(UiKit.button("Sair", _leave))
	Lobby.changed.connect(_refresh)
	Net.peer_joined.connect(func(_id: int, _n: String) -> void: _refresh())
	Net.peer_left.connect(func(_id: int) -> void: _refresh())
	Net.disconnected.connect(func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU))
	_refresh()
	if OS.get_cmdline_user_args().has("--bot"):
		# Headless UI-flow tests: mark ready once the handshake finished.
		while Net.players.size() < 2:
			await get_tree().create_timer(0.5).timeout
		_toggle_ready()


func _refresh() -> void:
	for child: Node in _players.get_children():
		child.queue_free()
	var ids: Array = Net.players.keys()
	ids.sort()
	for id: int in ids:
		var tag: String = " (host)" if id == 1 else ""
		var you: String = " — você" if id == multiplayer.get_unique_id() else ""
		var state: String = "PRONTO" if Lobby.ready_flags.get(id, false) else "aguardando"
		_players.add_child(UiKit.label("%s%s%s   [%s]" % [Net.players[id], tag, you, state], 22))
	for spec_id: int in Net.spectators:
		var me_tag: String = " — você" if spec_id == multiplayer.get_unique_id() else ""
		_players.add_child(UiKit.label("%s%s   [espectador]" % [Net.spectators[spec_id], me_tag], 18))
	_ready_button.visible = not Net.spectating
	if ids.size() < 2:
		_players.add_child(UiKit.label("Aguardando oponente...", 18))
	_rules.text = "Prorrogação: %s   Arena: %s" % [Glossary.overtime(Lobby.overtime_setting), Glossary.arena(Lobby.arena_setting)]
	if Net.is_host():
		_rules.text += "\nSeu IP na rede: %s" % Net.local_ip()
	elif Net.host_address != "":
		_rules.text += "\nConectado a %s" % Net.host_address
	_start_button.disabled = not Lobby.can_start()
	if Lobby.dedicated:
		_rules.text += "\n\nServidor dedicado: a partida começa sozinha quando os dois estiverem prontos."
	_rules.text += "\nO anfitrião grava telemetria local da partida (user://telemetry), sem envio à internet."


func _toggle_ready() -> void:
	_is_ready = not _is_ready
	_ready_button.text = "Cancelar pronto" if _is_ready else "Pronto"
	Lobby.set_ready(_is_ready)


func _leave() -> void:
	Net.close()
	SceneRouter.go_to(SceneRouter.MAIN_MENU)
