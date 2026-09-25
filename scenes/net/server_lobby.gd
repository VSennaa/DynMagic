extends Node
## Dedicated server idle scene (M9): no UI, only logs. Lobby starts the match when both
## connected players are ready; after the results everyone comes back here.


func _ready() -> void:
	Lobby.changed.connect(_log_state)
	Net.peer_joined.connect(func(id: int, player_name: String) -> void: print("[server] %s joined (%d)" % [player_name, id]))
	Net.peer_left.connect(func(id: int) -> void: print("[server] peer %d left" % id))
	print("[server] lobby '%s' on UDP %d (discovery %d); waiting for 2 players" % [Net.lobby_name, Net.port, Net.DISCOVERY_PORT])
	_log_state()


func _log_state() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for id: int in Net.players:
		parts.append("%s[%s]" % [Net.players[id], "pronto" if Lobby.ready_flags.get(id, false) else "aguardando"])
	print("[server] players: %s" % (", ".join(parts) if not parts.is_empty() else "none"))
