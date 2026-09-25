class_name SelfSpell
extends SpellNode
## Self-form spells act on the caster, then show a short visual attached to them.
##   direct    = Guard   (shield, duration; element reactions live in Player)
##   burst     = Impulse (distance, dash_time, iframes; storm teleport, wind lift + glide, fire trail)
##   lingering = Aura    (duration; element bonuses read by Player and spells)

const ZONE_SCENE: PackedScene = preload("res://scenes/spells/zone.tscn")
const TRAIL_POINTS: int = 3

var _life: float = 0.4

@onready var _shell: MeshInstance3D = $Shell


func _ready() -> void:
	var player: Player = caster as Player
	match spell.effect:
		&"direct":
			_life = float(spell.param(&"duration", 3.0))
			if player != null:
				player.stats.add_shield(float(spell.param(&"shield", 30.0)), _life)
				player.active_guard = spell
		&"burst":
			_life = float(spell.param(&"dash_time", 0.18)) + 0.25
			if player != null:
				_impulse(player)
		&"lingering":
			_life = float(spell.param(&"duration", 6.0))
			if player != null:
				player.stats.apply_status(&"aura", _life)
				player.active_aura = spell
				var shield_bonus: float = float(spell.param(&"shield_regen", 0.0))
				if shield_bonus > 0.0:
					player.stats.add_shield(shield_bonus, _life)
	_style_shell()


func _impulse(player: Player) -> void:
	var start: Vector3 = player.global_position
	var distance: float = float(spell.param(&"distance", 9.0))
	if bool(spell.param(&"teleport", false)):
		player.teleport(distance)
		player.invulnerable_time = maxf(player.invulnerable_time, float(spell.param(&"iframes", 0.1)))
	else:
		player.start_dash(distance, float(spell.param(&"dash_time", 0.18)), float(spell.param(&"iframes", 0.1)), float(spell.param(&"lift", 0.0)))
		player.glide_time = float(spell.param(&"glide_time", 0.0))
	var trail: float = float(spell.param(&"trail_duration", 0.0))
	if trail > 0.0:
		_leave_trail(start, player, distance, trail)


## Fire Impulse: small burning zones along the dash path.
func _leave_trail(start: Vector3, player: Player, distance: float, duration: float) -> void:
	var input: Vector2 = player.move_input if player.move_input.length() > 0.1 else Vector2(0.0, -1.0)
	var dir: Vector3 = player.transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	dir = dir.normalized()
	var trail_spell: ResolvedSpell = spell.with_params({"zone_radius": 1.2, "zone_duration": duration, "zone_dps": 8.0})
	for i: int in TRAIL_POINTS:
		var zone: Zone = ZONE_SCENE.instantiate() as Zone
		zone.setup(trail_spell, caster, start + dir * distance * (float(i) + 0.5) / TRAIL_POINTS, dir, start)
		get_parent().add_child(zone)


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
	mat.cull_mode = BaseMaterial3D.CULL_BACK  # the caster's camera is inside the shell: only outside faces render
	var alpha: float = 0.3 if spell.effect == &"direct" else 0.15
	mat.albedo_color = Color(spell.color, alpha)
	_shell.material_override = mat
	if spell.effect == &"burst":
		_shell.scale = Vector3(0.6, 1.2, 0.6)
