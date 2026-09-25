class_name Wall
extends StaticBody3D
## Temporary barrier (area/lingering). Params: width, height, duration, hp.
## Element variants (spec 01 §3):
##   fire  contact_burn    burns anyone touching it
##   frost hp 180, opaque
##   storm contact_dps     no collision at all; damages anyone inside it
##   wind  blocks_players  false: stops projectiles only

## Layer 2 holds barriers that stop projectiles but not players (players only mask layer 1).
const PROJECTILE_ONLY_LAYER: int = 2
const CONTACT_TICK: float = 0.5
const CONTACT_MARGIN: float = 0.6

var spell: ResolvedSpell
var caster: Node3D
var hp: float = 120.0

var _life: float = 5.0
var _size: Vector3 = Vector3(6.0, 3.0, 0.5)
var _contact_timer: float = 0.0

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $Mesh


func setup(p_spell: ResolvedSpell, p_caster: Node3D, origin: Vector3, _direction: Vector3, _target: Vector3) -> void:
	spell = p_spell
	caster = p_caster
	position = origin


func _ready() -> void:
	add_to_group(&"damageable")
	_size = Vector3(float(spell.param(&"width", 6.0)), float(spell.param(&"height", 3.0)), 0.5)
	hp = float(spell.param(&"hp", 120.0))
	_life = float(spell.param(&"duration", 5.0))
	var box: BoxShape3D = BoxShape3D.new()
	box.size = _size
	_shape.shape = box
	_shape.position.y = _size.y * 0.5
	if float(spell.param(&"contact_dps", 0.0)) > 0.0:
		collision_layer = 0
		remove_from_group(&"damageable")
	elif not bool(spell.param(&"blocks_players", true)):
		collision_layer = 1 << (PROJECTILE_ONLY_LAYER - 1)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = _size
	_mesh.mesh = mesh
	_mesh.position.y = _size.y * 0.5
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var alpha: float = 1.0 if bool(spell.param(&"opaque", false)) else (0.35 if bool(spell.param(&"transparent", false)) else 0.7)
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(spell.color.lerp(Color.WHITE, 0.3), alpha)
	mat.emission_enabled = true
	mat.emission = spell.color
	mat.emission_energy_multiplier = 0.6
	_mesh.material_override = mat
	AudioBus.play_sample_at("stone", global_position, get_parent(), -2.0)


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_destroy()
		return
	_contact_timer += delta
	if _contact_timer >= CONTACT_TICK:
		_contact_timer -= CONTACT_TICK
		_contact_tick()


func receive_hit(amount: float, _spell: ResolvedSpell, _source: Node) -> void:
	hp -= amount
	if hp <= 0.0:
		_destroy()


## Fire burns and storm shocks-and-damages anyone touching or standing inside the wall.
func _contact_tick() -> void:
	var dps: float = float(spell.param(&"contact_dps", 0.0))
	var burns: bool = bool(spell.param(&"contact_burn", false))
	if (dps <= 0.0 and not burns) or not SpellNode.has_authority():
		return
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = _size + Vector3(CONTACT_MARGIN, 0.0, CONTACT_MARGIN) * 2.0
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(global_basis, global_position + Vector3.UP * _size.y * 0.5)
	query.exclude = [get_rid()]
	var seen: Array[Node] = []
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var target: Node = SpellNode.find_damageable(result["collider"])
		if target == null or target == caster or target == self or seen.has(target):
			continue
		seen.append(target)
		if dps > 0.0:
			target.call(&"receive_hit", dps * CONTACT_TICK, spell, caster)
		if burns and target.has_method(&"receive_status"):
			target.call(&"receive_status", spell, caster)


func _destroy() -> void:
	if Net.is_online():
		if Net.is_host():
			get_parent().call(&"destroy_wall", String(name))
	else:
		queue_free()
