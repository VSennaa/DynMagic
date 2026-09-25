class_name SelfSpell
extends SpellNode
## Self-form spells act on the caster, then show a short visual attached to them.
##   direct    = Guard   (shield, duration)
##   burst     = Impulse (distance, dash_time, iframes, lift)
##   lingering = Aura    (duration; element bonuses read by Player)

var _life: float = 0.4

@onready var _shell: MeshInstance3D = $Shell


func _ready() -> void:
	var player: Player = caster as Player
	match spell.effect:
		&"direct":
			_life = float(spell.param(&"duration", 3.0))
			if player != null:
				player.stats.add_shield(float(spell.param(&"shield", 30.0)), _life)
		&"burst":
			_life = float(spell.param(&"dash_time", 0.18)) + 0.25
			if player != null:
				player.start_dash(float(spell.param(&"distance", 9.0)), float(spell.param(&"dash_time", 0.18)), float(spell.param(&"iframes", 0.1)), float(spell.param(&"lift", 0.0)))
		&"lingering":
			_life = float(spell.param(&"duration", 6.0))
			if player != null:
				player.stats.apply_status(&"aura", _life)
				player.active_aura = spell
	_style_shell()


func _process(delta: float) -> void:
	if caster != null and is_instance_valid(caster):
		global_position = caster.global_position + Vector3.UP * 0.9
	_life -= delta
	if _life <= 0.0:
		queue_free()
	elif spell.effect == &"direct" and caster is Player and (caster as Player).stats.shield <= 0.0:
		queue_free()  # shield broke early


func _style_shell() -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_FRONT  # visible from outside, not from the caster's camera
	var alpha: float = 0.3 if spell.effect == &"direct" else 0.15
	mat.albedo_color = Color(spell.color, alpha)
	_shell.material_override = mat
	if spell.effect == &"burst":
		_shell.scale = Vector3(0.6, 1.2, 0.6)
