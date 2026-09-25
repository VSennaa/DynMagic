class_name ArcaneCore
extends Node3D
## Arcane Core (docs/specs/02-match-loop.md section 4). Spawns once per round at 30 s of combat.
## Standing within RADIUS for CAPTURE_TIME without taking damage captures it. Progress is kept
## when leaving, and reset for a player who takes damage. Only the host counts progress.

signal captured(player_id: int)

const RADIUS: float = 2.0
const CAPTURE_TIME: float = 2.5

## player id -> seconds of capture progress
var progress: Dictionary[int, float] = {}
var _hp_seen: Dictionary[int, float] = {}
var _done: bool = false

@onready var _mesh: Node3D = $Model.find_child("Crystal", true, false) as Node3D
@onready var _ring: MeshInstance3D = $Ring


static func create() -> ArcaneCore:
	var core: ArcaneCore = ArcaneCore.new()
	core.name = "ArcaneCore"
	var mesh: Node3D = preload("res://scenes/assets/arcane_core.tscn").instantiate() as Node3D
	mesh.name = "Model"
	core.add_child(mesh)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = RADIUS - 0.08
	torus.outer_radius = RADIUS
	ring.mesh = torus
	ring.position.y = 0.05
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.8, 0.6, 1.0)
	ring.material_override = ring_mat
	core.add_child(ring)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.8, 0.6, 1.0)
	light.omni_range = 5.0
	light.position.y = 1.4
	core.add_child(light)
	return core


func _process(delta: float) -> void:
	_mesh.rotate_y(delta * 1.5)
	_mesh.position.y = sin(Time.get_ticks_msec() / 400.0) * 0.1


## Host: advance capture for the given players ({id: Player}).
func host_tick(delta: float, players: Dictionary) -> void:
	if _done:
		return
	for id: int in players:
		var player: Player = players[id]
		if player == null or player.stats.is_dead:
			continue
		var hp: float = player.stats.hp + player.stats.shield
		if _hp_seen.has(id) and hp < _hp_seen[id]:
			progress[id] = 0.0  # damage resets this player's progress
		_hp_seen[id] = hp
		var flat: Vector3 = player.global_position - global_position
		flat.y = 0.0
		if flat.length() <= RADIUS:
			progress[id] = progress.get(id, 0.0) + delta
			if progress[id] >= CAPTURE_TIME:
				_done = true
				captured.emit(id)
				return


func progress_ratio(id: int) -> float:
	return clampf(progress.get(id, 0.0) / CAPTURE_TIME, 0.0, 1.0)


func replace_player(old_id: int, new_id: int) -> void:
	for mapping: Dictionary in [progress, _hp_seen]:
		if mapping.has(old_id):
			mapping[new_id] = mapping[old_id]
			mapping.erase(old_id)
