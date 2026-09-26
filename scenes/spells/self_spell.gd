class_name SelfSpell
extends SpellNode
## Self-form spells act on the caster, then show a short visual attached to them.
##   direct    = Guard   (shield, duration; element reactions live in Player)
##   burst     = Impulse (distance, dash_time, iframes; storm teleport, wind lift + glide, fire trail)
##   lingering = Aura    (duration; element bonuses read by Player and spells)

const ZONE_SCENE: PackedScene = preload("res://scenes/spells/zone.tscn")
const TRAIL_POINTS: int = 3

var _life: float = 0.4
var restoring: bool = false
var _trail_last: Vector3
var _trail_active: bool = false
var _teleport_delay: float = 0.0
var _teleport_destination: Vector3
var _destination_marker: MeshInstance3D

@onready var _shell: MeshInstance3D = $Shell


func _ready() -> void:
	if restoring:
		_style_shell()
		return
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
				if bool(spell.param(&"seed_strip", false)):
					player.stats.apply_status(&"seed_ready", _life)
				var shield_bonus: float = float(spell.param(&"shield_regen", 0.0))
				if shield_bonus > 0.0:
					player.stats.add_shield(shield_bonus, _life)
	_style_shell()


func _impulse(player: Player) -> void:
	AudioBus.play_sample_at("cloth", player.global_position, player.get_parent(), 0.0)
	var start: Vector3 = player.global_position
	var distance: float = float(spell.param(&"distance", 9.0))
	if bool(spell.param(&"teleport", false)):
		_teleport_destination = player.teleport_destination(distance)
		_teleport_delay = 0.12
		_destination_marker = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.45
		mesh.bottom_radius = 0.45
		mesh.height = 0.06
		_destination_marker.mesh = mesh
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = spell.color
		_destination_marker.material_override = material
		get_parent().add_child(_destination_marker)
		_destination_marker.global_position = _teleport_destination + Vector3.UP * 0.04
	else:
		player.start_dash(distance, float(spell.param(&"dash_time", 0.18)), float(spell.param(&"iframes", 0.1)), float(spell.param(&"lift", 0.0)))
		player.glide_time = float(spell.param(&"glide_time", 0.0))
	var trail: float = float(spell.param(&"trail_duration", 0.0))
	if trail > 0.0:
		_trail_last = start
		_trail_active = true


## Fire Impulse: small burning zones along the dash path.
func _leave_trail(point: Vector3, duration: float) -> void:
	var trail_spell: ResolvedSpell = spell.with_params({"zone_radius": 1.2, "zone_duration": duration, "zone_dps": 8.0})
	var zone: Zone = ZONE_SCENE.instantiate() as Zone
	zone.setup(trail_spell, caster, floor_below(point), direction, point)
	get_parent().add_child(zone)


func _physics_process(delta: float) -> void:
	var player: Player = caster as Player
	if player == null or restoring or player.stats.is_dead:
		return
	if _teleport_delay > 0.0:
		_teleport_delay -= delta
		if _teleport_delay <= 0.0:
			var collision: KinematicCollision3D = KinematicCollision3D.new()
			var motion: Vector3 = _teleport_destination - player.global_position
			if player.test_move(player.global_transform, motion, collision):
				motion = collision.get_travel()
			player.global_position += motion
			player.invulnerable_time = maxf(player.invulnerable_time, float(spell.param(&"iframes", 0.1)))
			_destination_marker.queue_free()
	if _trail_active:
		if player.global_position.distance_to(_trail_last) >= 1.0:
			_leave_trail(player.global_position, float(spell.param(&"trail_duration", 2.0)))
			_trail_last = player.global_position
		_trail_active = player._dash_time > 0.0


func _exit_tree() -> void:
	if is_instance_valid(_destination_marker):
		_destination_marker.queue_free()


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
