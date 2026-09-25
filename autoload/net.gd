## ENet host/join, LAN discovery and RPC channels. See docs/specs/04-networking.md.
extends Node

signal hosted
signal joined
signal connection_failed(reason: String)
signal peer_joined(peer_id: int, player_name: String)
signal peer_left(peer_id: int)
signal disconnected
signal lobbies_changed

const PROTOCOL_VERSION: int = 1
const GAME_TAG: String = "dynmagic"
const DEFAULT_PORT: int = 7777
const DISCOVERY_PORT: int = 7778
const BROADCAST_INTERVAL: float = 1.0
const LOBBY_TIMEOUT: float = 3.0
## Two players plus room for spectators later (spec 04 §1).
const MAX_CLIENTS: int = 5

## ENet channels (spec 04 §8).
const CHANNEL_RELIABLE: int = 0
const CHANNEL_INPUT: int = 1
const CHANNEL_SNAPSHOT: int = 2

var player_name: String = "Mago"
var lobby_name: String = ""
var port: int = DEFAULT_PORT
## peer id -> player name, host included (id 1). Only complete after the handshake.
var players: Dictionary[int, String] = {}
## "ip:port" -> {info..., "ip", "seen"} for lobbies heard on the LAN.
var lobbies: Dictionary[String, Dictionary] = {}

var _broadcaster: PacketPeerUDP
var _listener: PacketPeerUDP
var _broadcast_timer: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_parse_cli.call_deferred()


func _process(delta: float) -> void:
	_clock += delta
	if _broadcaster != null:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = BROADCAST_INTERVAL
			_broadcast()
	if _listener != null:
		_poll_discovery()


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func host(p_port: int = DEFAULT_PORT, p_lobby_name: String = "") -> Error:
	close()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(p_port, MAX_CLIENTS, 3)
	if err != OK:
		connection_failed.emit("Não foi possível abrir a porta %d (%s)" % [p_port, error_string(err)])
		return err
	port = p_port
	lobby_name = p_lobby_name if p_lobby_name != "" else "Sala de %s" % player_name
	multiplayer.multiplayer_peer = peer
	players = {1: player_name}
	_start_broadcast()
	_log("hosting on port %d as '%s'" % [port, lobby_name])
	hosted.emit()
	return OK


func join(address: String, p_port: int = DEFAULT_PORT) -> Error:
	close()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, p_port, 3)
	if err != OK:
		connection_failed.emit("Endereço inválido: %s" % address)
		return err
	port = p_port
	multiplayer.multiplayer_peer = peer
	_log("joining %s:%d" % [address, p_port])
	return OK


func close() -> void:
	_stop_broadcast()
	if multiplayer.multiplayer_peer != null and is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()


# --- Handshake (spec 04 §3) -------------------------------------------------

func _on_connected_to_server() -> void:
	_rpc_hello.rpc_id(1, PROTOCOL_VERSION, player_name)


@rpc("any_peer", "call_remote", "reliable", CHANNEL_RELIABLE)
func _rpc_hello(version: int, name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if version != PROTOCOL_VERSION:
		_rpc_reject.rpc_id(peer_id, "Versão diferente (host %d, você %d)" % [PROTOCOL_VERSION, version])
		_kick_later(peer_id)
		return
	if players.size() >= 2:
		_rpc_reject.rpc_id(peer_id, "Sala cheia")
		_kick_later(peer_id)
		return
	players[peer_id] = name.strip_edges().left(24) if name.strip_edges() != "" else "Mago %d" % peer_id
	_log("peer %d joined as '%s'" % [peer_id, players[peer_id]])
	_rpc_welcome.rpc(players)
	peer_joined.emit(peer_id, players[peer_id])


@rpc("authority", "call_remote", "reliable", CHANNEL_RELIABLE)
func _rpc_welcome(all_players: Dictionary) -> void:
	var first_time: bool = players.is_empty()
	players.clear()
	for id: Variant in all_players:
		players[int(id)] = str(all_players[id])
	if first_time:
		_log("joined; players %s" % [players])
		joined.emit()


@rpc("authority", "call_remote", "reliable", CHANNEL_RELIABLE)
func _rpc_reject(reason: String) -> void:
	_log("rejected: %s" % reason)
	connection_failed.emit(reason)
	close.call_deferred()


func _kick_later(peer_id: int) -> void:
	# Give the reject RPC time to leave before dropping the peer.
	await get_tree().create_timer(0.3).timeout
	var enet: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null and multiplayer.get_peers().has(peer_id):
		enet.disconnect_peer(peer_id)


func _on_peer_connected(_peer_id: int) -> void:
	pass  # Players are registered after _rpc_hello.


func _on_peer_disconnected(peer_id: int) -> void:
	if players.erase(peer_id):
		_log("peer %d left" % peer_id)
		peer_left.emit(peer_id)
		if multiplayer.is_server():
			_rpc_welcome.rpc(players)


func _on_connection_failed() -> void:
	close()
	connection_failed.emit("Não foi possível conectar")


func _on_server_disconnected() -> void:
	_log("host closed the connection")
	close()
	disconnected.emit()


# --- LAN discovery (spec 04 §2) ---------------------------------------------

func start_discovery() -> void:
	stop_discovery()
	_listener = PacketPeerUDP.new()
	var err: Error = _listener.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("Net: discovery port %d busy (%s)" % [DISCOVERY_PORT, error_string(err)])
		_listener = null


func stop_discovery() -> void:
	if _listener != null:
		_listener.close()
		_listener = null
	lobbies.clear()


func _start_broadcast() -> void:
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	_broadcaster.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_broadcast_timer = 0.0


func _stop_broadcast() -> void:
	if _broadcaster != null:
		_broadcaster.close()
		_broadcaster = null


func _broadcast() -> void:
	var info: Dictionary = {
		"g": GAME_TAG,
		"v": PROTOCOL_VERSION,
		"name": lobby_name,
		"port": port,
		"players": players.size(),
		"state": "lobby",
	}
	_broadcaster.put_packet(JSON.stringify(info).to_utf8_buffer())


func _poll_discovery() -> void:
	var changed: bool = false
	while _listener.get_available_packet_count() > 0:
		var packet: PackedByteArray = _listener.get_packet()
		var ip: String = _listener.get_packet_ip()
		var info: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if not (info is Dictionary) or (info as Dictionary).get("g", "") != GAME_TAG:
			continue
		var entry: Dictionary = info
		entry["ip"] = ip
		entry["seen"] = _clock
		entry["compatible"] = int(entry.get("v", -1)) == PROTOCOL_VERSION
		var key: String = "%s:%d" % [ip, int(entry.get("port", DEFAULT_PORT))]
		changed = changed or not lobbies.has(key)
		lobbies[key] = entry
	for key: String in lobbies.keys():
		if _clock - float(lobbies[key]["seen"]) > LOBBY_TIMEOUT:
			lobbies.erase(key)
			changed = true
	if changed:
		lobbies_changed.emit()


# --- CLI (spec 08 §4): --host | --join <ip> [--port N] [--name X] [--discover] ---

func _parse_cli() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	var action: String = ""
	var address: String = "127.0.0.1"
	while i < args.size():
		match args[i]:
			"--host":
				action = "host"
			"--join":
				action = "join"
				if i + 1 < args.size() and not args[i + 1].begins_with("--"):
					address = args[i + 1]
					i += 1
			"--port":
				if i + 1 < args.size():
					port = int(args[i + 1])
					i += 1
			"--name":
				if i + 1 < args.size():
					player_name = args[i + 1]
					i += 1
			"--discover":
				start_discovery()
				lobbies_changed.connect(func() -> void: _log("lobbies %s" % [lobbies.keys()]))
		i += 1
	if action == "host":
		host(port)
	elif action == "join":
		join(address, port)


func _log(message: String) -> void:
	print("[net] %s" % message)
