class_name Zone
extends SpellNode
## Lingering ground zone (Seed). Ticks every TICK seconds on targets inside the radius.
## Params: zone_radius, zone_duration, zone_dps, zone_applies_status.

const TICK: float = 0.5

var radius: float = 3.5
var duration: float = 4.0
var dps: float = 0.0

var _age: float = 0.0
var _tick_timer: float = 0.0

@onready var _disc: MeshInstance3D = $Disc


func _ready() -> void:
	radius = float(spell.param(&"zone_radius", 3.5))
	duration = float(spell.param(&"zone_duration", 4.0))
	dps = float(spell.param(&"zone_dps", 0.0))
	_disc.scale = Vector3(radius, 1.0, radius)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(spell.color, 0.35)
	_disc.material_override = mat


func _physics_process(delta: float) -> void:
	_age += delta
	_tick_timer += delta
	if _tick_timer >= TICK:
		_tick_timer -= TICK
		_apply_tick()
	if _age >= duration:
		queue_free()


func _apply_tick() -> void:
	var applies_status: bool = bool(spell.param(&"zone_applies_status", false))
	for target: Node in overlap_damageables(global_position + Vector3.UP * 0.9, radius):
		if dps > 0.0:
			hit_amount(target, dps * TICK)
		elif applies_status and target.has_method(&"receive_status"):
			target.call(&"receive_status", spell.status_id, spell.status_duration)
