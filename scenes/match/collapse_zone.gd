class_name CollapseZone
extends Node3D
## Overtime "Colapso" (docs/specs/02-match-loop.md section 5): a circle closing from the arena
## edge to a 5 m radius in 20 s. Outside it, players take 12 damage per second (host only).

const START_RADIUS: float = 24.0
const END_RADIUS: float = 5.0
const SHRINK_TIME: float = 20.0
const DPS: float = 12.0
const TICK: float = 0.5

var elapsed: float = 0.0
var _tick_timer: float = 0.0
var _wall: MeshInstance3D


func _ready() -> void:
	_wall = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 8.0
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	_wall.mesh = cylinder
	_wall.position.y = 4.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.85, 0.2, 0.3, 0.25)
	_wall.material_override = mat
	add_child(_wall)


func radius() -> float:
	return lerpf(START_RADIUS, END_RADIUS, clampf(elapsed / SHRINK_TIME, 0.0, 1.0))


func _process(delta: float) -> void:
	elapsed += delta
	var r: float = radius()
	_wall.scale = Vector3(r, 1.0, r)


## Host: damage everyone outside the circle.
func host_tick(delta: float, players: Array[Player]) -> void:
	_tick_timer += delta
	if _tick_timer < TICK:
		return
	_tick_timer -= TICK
	var r: float = radius()
	for player: Player in players:
		var flat: Vector3 = player.global_position - global_position
		flat.y = 0.0
		if flat.length() > r and not player.stats.is_dead:
			player.stats.take_damage(DPS * TICK)
