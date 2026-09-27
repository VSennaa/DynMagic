class_name ArcaneCore
extends Node3D
## Arcane Core: visible pedestal at 0 s, announcement at 20 s, one capture from 30 s.
## Standing within RADIUS for CAPTURE_TIME without taking damage captures it.
## After a one-second exit grace progress decays; enemies contest, damage resets. Host only.

signal captured(player_id: int)

const RADIUS: float = 2.0
const CAPTURE_TIME: float = 2.5

## player id -> seconds of capture progress
var progress: Dictionary[int, float] = {}
var _damage_seen: Dictionary[int, int] = {}
var _done: bool = false
var capture_enabled: bool = true
var contested: bool = false
var _absent: Dictionary[int, float] = {}

@onready var _mesh: Node3D = $Model.find_child("Crystal", true, false) as Node3D
@onready var _ring: MeshInstance3D = $Ring


static func create() -> ArcaneCore:
	var core: ArcaneCore = ArcaneCore.new()
	build_visuals(core)
	return core


## Shared with `ControlCore` (M12 decision 4: the point reuses the Core's visuals).
static func build_visuals(core: ArcaneCore) -> void:
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


func _process(delta: float) -> void:
	_mesh.rotate_y(delta * 1.5)
	_mesh.position.y = sin(Time.get_ticks_msec() / 400.0) * 0.1


## Host: advance capture for the given players ({id: Player}).
func host_tick(delta: float, players: Dictionary, teams: Dictionary = {}) -> void:
	if _done or not capture_enabled:
		return
	var occupants: Array[int] = []
	var sides: Dictionary = {}
	var damaged: Array[int] = []
	for id: int in players:
		var player: Player = players[id]
		if player == null or player.stats.is_dead:
			continue
		var revision: int = player.stats.damage_revision
		if revision != int(_damage_seen.get(id, revision)):
			damaged.append(id)
		_damage_seen[id] = revision
		if SpatialContract.on_floor(player.global_position, global_position, RADIUS):
			occupants.append(id)
			sides[teams.get(id, id)] = true
	advance_capture(delta, occupants, sides.size() > 1, damaged)


## Pure occupancy step, shared by runtime and deterministic regression tests.
func advance_capture(delta: float, occupants: Array[int], is_contested: bool, damaged: Array[int] = []) -> void:
	if _done or not capture_enabled:
		return
	contested = is_contested
	for id: int in damaged:
		progress[id] = 0.0
	for id: int in occupants:
		_absent[id] = 0.0
		if not contested and not damaged.has(id):
			progress[id] = progress.get(id, 0.0) + delta
			if progress[id] >= CAPTURE_TIME:
				_done = true
				captured.emit(id)
				return
	for id: int in progress:
		if occupants.has(id):
			continue
		var before: float = _absent.get(id, 0.0)
		_absent[id] = before + delta
		var decay: float = maxf(_absent[id] - 1.0, 0.0) - maxf(before - 1.0, 0.0)
		progress[id] = maxf(0.0, progress[id] - decay)


func set_stage(announced: bool, active: bool, paused: bool = false) -> void:
	capture_enabled = active
	_ring.visible = announced
	_mesh.visible = active
	var material: StandardMaterial3D = _ring.material_override as StandardMaterial3D
	material.albedo_color = Color(1.0, 0.45, 0.2) if paused else (Color(0.8, 0.6, 1.0) if active else Color(1.0, 0.8, 0.3))


func progress_ratio(id: int) -> float:
	return clampf(progress.get(id, 0.0) / CAPTURE_TIME, 0.0, 1.0)


func replace_player(old_id: int, new_id: int) -> void:
	for mapping: Dictionary in [progress, _damage_seen, _absent]:
		if mapping.has(old_id):
			mapping[new_id] = mapping[old_id]
			mapping.erase(old_id)
