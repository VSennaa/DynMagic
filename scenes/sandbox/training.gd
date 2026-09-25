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
var _stress: TrainingStress


func _ready() -> void:
	var spawn: Marker3D = get_node(^"Arena/Layout/SpawnSouth") as Marker3D
	player.global_transform = spawn.global_transform
	var hud: Hud = Hud.new()
	add_child(hud)
	hud.bind(player)
	add_child(PauseMenu.new())
	player.add_child(Footsteps.new())
	_spawn_dummies()


## Dummy layout on Arena A, facing the south spawn: close, mid-range, strafing, behind
## cover, on the west balcony and far across the arena.
const DUMMY_SCENE: PackedScene = preload("res://scenes/sandbox/training_dummy.tscn")
const DUMMIES: Array[Dictionary] = [
	{"pos": Vector3(0, 0, 14), "patrol": 0.0},
	{"pos": Vector3(-5, 0, 9), "patrol": 0.0},
	{"pos": Vector3(4, 0, 6), "patrol": 3.0},
	{"pos": Vector3(0, 0, -4), "patrol": 0.0},
	{"pos": Vector3(-12.5, 1.5, 2), "patrol": 0.0},
	{"pos": Vector3(6, 0, -12), "patrol": 2.0},
]


func _spawn_dummies() -> void:
	var root: Node3D = $Dummies as Node3D
	for entry: Dictionary in DUMMIES:
		var dummy: TrainingDummy = DUMMY_SCENE.instantiate() as TrainingDummy
		dummy.patrol_distance = float(entry["patrol"])
		dummy.position = entry["pos"]
		dummy.rotation.y = PI  # the model faces -Z; turn it toward the south spawn
		root.add_child(dummy)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if OS.is_debug_build() and key.keycode == KEY_F8:
		toggle_stress()
		get_viewport().set_input_as_handled()
		return
	if ELEMENT_KEYS.has(key.keycode):
		set_element(ELEMENT_KEYS[key.keycode])
		get_viewport().set_input_as_handled()


func set_element(element_id: StringName) -> void:
	player.composer.element_id = element_id
	player.composer.reset()


## Debug-only sustained particle/zone load. F8 again removes the entire workload.
func toggle_stress() -> void:
	if not OS.is_debug_build():
		return
	if is_instance_valid(_stress):
		_stress.queue_free()
		_stress = null
		print("[stress] stopped")
		return
	_stress = TrainingStress.new()
	_stress.caster = player
	add_child(_stress)
