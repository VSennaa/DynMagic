class_name Wall
extends StaticBody3D
## Temporary barrier (area/lingering). Blocks players and projectiles until its
## duration ends or its HP runs out. Params: width, height, duration, hp.

var spell: ResolvedSpell
var caster: Node3D
var hp: float = 120.0

var _life: float = 5.0

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $Mesh


func setup(p_spell: ResolvedSpell, p_caster: Node3D, origin: Vector3, _direction: Vector3, _target: Vector3) -> void:
	spell = p_spell
	caster = p_caster
	position = origin


func _ready() -> void:
	add_to_group(&"damageable")
	var width: float = float(spell.param(&"width", 6.0))
	var height: float = float(spell.param(&"height", 3.0))
	hp = float(spell.param(&"hp", 120.0))
	_life = float(spell.param(&"duration", 5.0))
	var size: Vector3 = Vector3(width, height, 0.5)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position.y = height * 0.5
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_mesh.mesh = mesh
	_mesh.position.y = height * 0.5
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(spell.color.lerp(Color.WHITE, 0.3), 0.7)
	mat.emission_enabled = true
	mat.emission = spell.color
	mat.emission_energy_multiplier = 0.6
	_mesh.material_override = mat


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()


func receive_hit(amount: float, _spell: ResolvedSpell, _source: Node) -> void:
	hp -= amount
	if hp <= 0.0:
		queue_free()
