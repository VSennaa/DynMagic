class_name TrainingStress
extends Node3D
## Sustains 20 real zones and 20 real projectiles with all four particle palettes.
## Projectiles keep their gameplay speeds; expired/impacted nodes are replenished.

const COUNT: int = 20
const ELEMENTS: Array[StringName] = [&"fire", &"frost", &"storm", &"wind"]
const ZONE_SCENE: PackedScene = preload("res://scenes/spells/zone.tscn")
var caster: Player
var _zones: Array[Zone] = []
var _projectiles: Array[Projectile] = []
var _report_time: float = 0.0
var _spawn_index: int = 0


func _process(delta: float) -> void:
	for i: int in range(_zones.size() - 1, -1, -1):
		if not is_instance_valid(_zones[i]) or _zones[i].is_queued_for_deletion():
			_zones.remove_at(i)
	for i: int in range(_projectiles.size() - 1, -1, -1):
		if not is_instance_valid(_projectiles[i]) or _projectiles[i].is_queued_for_deletion():
			_projectiles.remove_at(i)
	while _zones.size() < COUNT:
		var index: int = _zones.size()
		var spell: ResolvedSpell = SpellDB.resolve(ELEMENTS[index % 4], &"projectile", &"lingering")
		var zone: Zone = ZONE_SCENE.instantiate() as Zone
		var point: Vector3 = Vector3((index % 5 - 2) * 4.0, 0.03, (index / 5 - 2) * 5.0)
		zone.setup(spell, caster, point, Vector3.FORWARD, point)
		add_child(zone)
		_zones.append(zone)
	while _projectiles.size() < COUNT:
		var index: int = _spawn_index % COUNT
		_spawn_index += 1
		var spell: ResolvedSpell = SpellDB.resolve(ELEMENTS[index % 4], &"projectile", &"direct")
		var projectile: Projectile = spell.scene.instantiate() as Projectile
		var point: Vector3 = Vector3((index % 5 - 2) * 3.0, 2.0 + (index % 3) * 0.4, 14.0)
		projectile.setup(spell, caster, point, Vector3.FORWARD, point + Vector3.FORWARD * 30.0)
		add_child(projectile)
		_projectiles.append(projectile)
	_report_time += delta
	if _report_time >= 2.0:
		_report_time = 0.0
		print("[stress] fps=%d zones=%d projectiles=%d renderer=%s" % [Engine.get_frames_per_second(), _zones.size(), _projectiles.size(), RenderingServer.get_current_rendering_method()])
