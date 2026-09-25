extends Node3D
## Offline training: the player starts at the south spawn of the arena.


func _ready() -> void:
	var spawn: Marker3D = get_node(^"Arena/Layout/SpawnSouth") as Marker3D
	var player: Player = $Player as Player
	player.global_transform = spawn.global_transform
