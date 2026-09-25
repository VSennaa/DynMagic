extends Node3D
## Offline training: the player starts at the south spawn of the arena.
## Keys 1-4 pick the element (the real pick happens in the draft, M4).

const ELEMENT_KEYS: Dictionary = {
	KEY_1: &"fire",
	KEY_2: &"frost",
	KEY_3: &"storm",
	KEY_4: &"wind",
}

@onready var player: Player = $Player as Player


func _ready() -> void:
	var spawn: Marker3D = get_node(^"Arena/Layout/SpawnSouth") as Marker3D
	player.global_transform = spawn.global_transform
	var hud: Hud = Hud.new()
	add_child(hud)
	hud.bind(player)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if ELEMENT_KEYS.has(key.keycode):
		set_element(ELEMENT_KEYS[key.keycode])
		get_viewport().set_input_as_handled()


func set_element(element_id: StringName) -> void:
	player.composer.element_id = element_id
	player.composer.reset()
