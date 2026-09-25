class_name Player
extends CharacterBody3D
## First-person player body: movement, crouch, jump and mouse look.
## See docs/specs/05-player-controller.md.

## Emitted after mana and cooldown are paid. Spell scenes subscribe here.
signal spell_cast(spell: ResolvedSpell)
## Emitted by the local player after each movement tick (NetSync records it for prediction).
signal input_sampled(frame: Dictionary)

const PITCH_LIMIT: float = deg_to_rad(89.0)
const KNOCKBACK_DECAY: float = 18.0
const BURN_TICK: float = 0.5
const GLIDE_GRAVITY_SCALE: float = 0.25
## D1: the Arrow (projectile/direct) uses 3 charges instead of a per-cast cooldown.
const ARROW_KEY: StringName = &"projectile_direct"
const ARROW_CHARGES: int = 3
const ARROW_RECHARGE: float = 1.2

@export var tuning: PlayerTuning = preload("res://data/player_tuning.tres")
## Only the local player reads input. Remote players are driven by NetSync (M3).
@export var is_local: bool = true
## When true, NetSync moves this body (host replaying client inputs, or client interpolating).
var net_driven: bool = false
## Draft, countdown and round end: no walking or casting (spawn barriers, spec 02 §2).
var frozen: bool = false:
	set(value):
		frozen = value
		if composer != null:
			composer.read_input = is_local and not value
			if value:
				composer.clear()

## Set by the spell composer: sprint is blocked while composing a spell.
var sprint_blocked: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false

## Last movement input, used as the Impulse direction.
var move_input: Vector2 = Vector2.ZERO
## Seconds of damage immunity left (Impulse i-frames).
var invulnerable_time: float = 0.0
## Active Aura spell (self/lingering) while its status lasts.
var active_aura: ResolvedSpell
## Active Guard spell (self/direct) while its shield lasts.
var active_guard: ResolvedSpell
## Seconds of reduced gravity left (wind Impulse).
var glide_time: float = 0.0
## Rune picked in the draft for this round (spec 02 §3), or empty.
var rune: StringName = &""
## Overcharge from the Arcane Core: free spells with +20% damage for 10 s or 3 casts.
var overcharge_time: float = 0.0
var overcharge_casts: int = 0
## Overtime modifiers (spec 02 §5).
var sudden_death: bool = false
var mana_surge: bool = false

var _dash_velocity: Vector3 = Vector3.ZERO
## Knockback added on top of walking velocity; decays over time.
var _knockback: Vector3 = Vector3.ZERO
var _burn_dps: float = 0.0
var _burn_tick: float = 0.0
var _slow_strength: float = 0.0
var _nameplate: Label3D
var _jump_held: bool = false
var _air_jumps_used: int = 0
var _shock_bonus: float = 0.2
var _dash_time: float = 0.0
var _coyote_timer: float = 0.0
var _current_height: float = 1.8
var _pitch: float = 0.0
var cast_lockout: float = 0.0
## D1: Arrow charges and the 1.2 s recharge timer (replicated with the player runtime).
var _arrow_charges: int = ARROW_CHARGES
var _arrow_recharge: float = 0.0

@onready var stats: Stats = $Stats
@onready var composer: SpellComposer = $SpellComposer
@onready var cast_origin: Marker3D = $Head/Camera3D/CastOrigin
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	var capsule: CapsuleShape3D = _collision.shape as CapsuleShape3D
	capsule.radius = tuning.capsule_radius
	_current_height = tuning.stand_height
	_apply_height(_current_height)
	floor_snap_length = tuning.step_height
	_camera.current = is_local
	_camera.fov = Settings.fov
	Settings.changed.connect(_on_settings_changed)
	add_to_group(&"damageable")
	composer.read_input = is_local
	composer.validator = _validate_cast
	composer.cast_requested.connect(_on_cast_requested)
	composer.state_changed.connect(func(_s: SpellComposer.State) -> void: sprint_blocked = composer.is_composing())
	stats.died.connect(composer.reset)
	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Toon.add_outline(_camera)
		var arms: Node = preload("res://scenes/player/first_person_arms.gd").new()
		arms.name = "FirstPersonArms"
		_camera.add_child(arms)
		arms.setup(self, _camera)
	else:
		# C15: the dedicated server has no camera to look at, so skip the model/animation.
		if not Net.dedicated:
			_add_nameplate()


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var y_sign: float = 1.0 if Settings.invert_y else -1.0
		rotate_y(-motion.relative.x * Settings.mouse_sensitivity)
		_pitch = clampf(_pitch + y_sign * motion.relative.y * Settings.mouse_sensitivity, -PITCH_LIMIT, PITCH_LIMIT)
		_head.rotation.x = _pitch
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not PauseMenu.is_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if net_driven:
		return
	if not is_local:
		# Offline stand-in: idle but still ticks statuses and knockback.
		simulate(delta, Vector2.ZERO, false, false, false)
		return
	var frame: Dictionary = {
		"move": Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back"),
		"yaw": rotation.y,
		"pitch": _pitch,
		"buttons": _buttons(Input.is_action_pressed(&"jump"), Input.is_action_pressed(&"crouch"), Input.is_action_pressed(&"sprint")),
	}
	apply_input(delta, frame)
	input_sampled.emit(frame)


## Runs one tick from a recorded or received input frame (prediction replay and host simulation).
func apply_input(delta: float, frame: Dictionary) -> void:
	set_look(float(frame["yaw"]), float(frame["pitch"]))
	var buttons: int = int(frame["buttons"])
	simulate(delta, frame["move"], buttons & NetCodec.InputButton.JUMP != 0, buttons & NetCodec.InputButton.CROUCH != 0, buttons & NetCodec.InputButton.SPRINT != 0)


func set_look(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)
	_head.rotation.x = _pitch


func get_pitch() -> float:
	return _pitch


static func _buttons(jump: bool, crouch: bool, sprint: bool) -> int:
	return (NetCodec.InputButton.JUMP if jump else 0) | (NetCodec.InputButton.CROUCH if crouch else 0) | (NetCodec.InputButton.SPRINT if sprint else 0)


## One movement tick. Kept free of Input reads so the host can replay client inputs (M3).
func simulate(delta: float, input_dir: Vector2, want_jump: bool, want_crouch: bool, want_sprint: bool) -> void:
	cast_lockout = maxf(0.0, cast_lockout - delta)
	if frozen or stats.is_dead:
		# Spawn barriers and the death freeze: the body keeps its place, statuses stop mattering.
		velocity = Vector3.ZERO
		return
	move_input = input_dir
	# D1: recharge one Arrow charge every 1.2 s up to 3.
	if _arrow_charges < ARROW_CHARGES:
		_arrow_recharge += delta
		if _arrow_recharge >= ARROW_RECHARGE:
			_arrow_recharge -= ARROW_RECHARGE
			_arrow_charges = mini(_arrow_charges + 1, ARROW_CHARGES)
	overcharge_time = maxf(overcharge_time - delta, 0.0)
	invulnerable_time = maxf(invulnerable_time - delta, 0.0)
	if active_aura != null and not stats.has_status(&"aura"):
		active_aura = null
	_update_statuses(delta)
	_update_crouch(delta, want_crouch)
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_velocity
		move_and_slide()
		if _dash_time <= 0.0:
			velocity = _dash_velocity.normalized() * tuning.walk_speed
		return

	if is_on_floor():
		_coyote_timer = tuning.coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		# Wind Impulse glide: reduced gravity while falling.
		var gravity_scale: float = GLIDE_GRAVITY_SCALE if glide_time > 0.0 and velocity.y < 0.0 else 1.0
		velocity.y -= tuning.gravity * gravity_scale * delta
	glide_time = maxf(glide_time - delta, 0.0)
	if is_on_floor():
		_air_jumps_used = 0

	var jump_edge: bool = want_jump and not _jump_held
	_jump_held = want_jump
	if want_jump and _coyote_timer > 0.0 and not is_crouching:
		velocity.y = tuning.jump_velocity()
		_coyote_timer = 0.0
	elif jump_edge and not is_on_floor() and _air_jumps_used == 0 and active_aura != null and bool(active_aura.param(&"double_jump", false)):
		# Wind Aura: one extra jump in the air.
		velocity.y = tuning.jump_velocity()
		_air_jumps_used = 1

	# Sprint only while moving forward, standing, and not composing a spell.
	is_sprinting = want_sprint and not sprint_blocked and not _guard_blocks_sprint() and not is_crouching and input_dir.y < -0.1
	var speed: float = tuning.walk_speed
	if is_crouching:
		speed = tuning.crouch_speed
	elif is_sprinting:
		speed = tuning.sprint_speed

	var wish: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	wish.y = 0.0
	wish = wish.normalized() * speed * speed_mult()
	var accel: float = tuning.ground_acceleration if is_on_floor() else tuning.air_acceleration
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(wish, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var was_on_floor: bool = is_on_floor()
	var pre_move: Transform3D = global_transform
	var pre_velocity: Vector3 = velocity
	velocity += _knockback
	move_and_slide()
	velocity -= _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	if was_on_floor and is_on_wall() and horizontal.length() > 0.1:
		_try_step_up(pre_move, pre_velocity, delta)


## Retries a blocked ground move from step_height higher, then snaps down onto the step.
func _try_step_up(from: Transform3D, move_velocity: Vector3, delta: float) -> void:
	var up: Vector3 = Vector3.UP * tuning.step_height
	if test_move(from, up):
		return
	var raised: Transform3D = from.translated(up)
	var forward: Vector3 = Vector3(move_velocity.x, 0.0, move_velocity.z) * delta
	if test_move(raised, forward):
		return
	var moved: Transform3D = raised.translated(forward)
	var down_collision: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(moved, -up, down_collision):
		return
	var landing: Vector3 = moved.origin - up + down_collision.get_travel()
	if landing.y - from.origin.y < 0.01:
		return
	global_position = landing
	velocity.x = move_velocity.x
	velocity.z = move_velocity.z


func _update_crouch(delta: float, want_crouch: bool) -> void:
	if want_crouch:
		is_crouching = true
	elif is_crouching:
		# Stand up only when there is headroom.
		var headroom: Vector3 = Vector3.UP * (tuning.stand_height - _current_height + 0.05)
		if not test_move(global_transform, headroom):
			is_crouching = false
	var target: float = tuning.crouch_height if is_crouching else tuning.stand_height
	if not is_equal_approx(_current_height, target):
		var rate: float = (tuning.stand_height - tuning.crouch_height) / maxf(tuning.crouch_transition_time, 0.001)
		_current_height = move_toward(_current_height, target, rate * delta)
		_apply_height(_current_height)


## Keeps the feet at the body origin: the capsule and head are offset upward.
func _apply_height(height: float) -> void:
	var capsule: CapsuleShape3D = _collision.shape as CapsuleShape3D
	capsule.height = height
	_collision.position.y = height * 0.5
	_head.position.y = height * tuning.eye_height_ratio


func _on_settings_changed(key: StringName) -> void:
	if key == &"fov":
		_camera.fov = Settings.fov


func get_aim_camera() -> Camera3D:
	return _camera



## Entry point for spell damage (group "damageable"). Host-only in multiplayer.
func receive_hit(amount: float, spell: ResolvedSpell, source: Node) -> void:
	if invulnerable_time > 0.0 or stats.is_dead or (MatchState.active and MatchState.is_frozen()) or (Net.is_online() and not Net.is_host()):
		return
	# Shock: the next damage taken is increased, then the shock is consumed.
	if stats.has_status(&"shock") and amount > 0.0:
		amount *= 1.0 + _shock_bonus
		stats.clear_status(&"shock")
	if active_guard != null and stats.shield <= 0.0:
		active_guard = null
	if active_guard != null and spell != null and spell.form == &"projectile" and bool(active_guard.param(&"deflect_next", false)):
		# Wind Guard: the next projectile is deflected entirely, once.
		active_guard = null
		stats.clear_shield()
		return
	var had_shield: bool = stats.shield > 0.0
	stats.take_damage(amount)
	if MatchState.active and Net.is_host():
		MatchState.report_damage(int(String(source.name)) if source is Player else 0, int(String(name)), amount, spell.form if spell != null else &"")
	if active_guard != null:
		_guard_reactions(amount, source, had_shield)
	if spell != null and bool(spell.param(&"applies_status", false)):
		receive_status(spell, source)


## Applies the element status carried by a spell (spec 01 §3). Zones call this directly.
func receive_status(spell: ResolvedSpell, source: Node = null) -> void:
	if invulnerable_time > 0.0 or spell == null or stats.is_dead or (MatchState.active and MatchState.is_frozen()) or (Net.is_online() and not Net.is_host()):
		return
	match spell.status_id:
		&"burn":
			_burn_dps = float(spell.status_params.get("dps", 4.0))
			stats.apply_status(&"burn", spell.status_duration)
		&"slow":
			if active_aura != null and bool(active_aura.param(&"slow_immune", false)):
				return
			var strength: float = float(spell.param(&"slow_override", spell.status_params.get("slow", 0.3)))
			_slow_strength = strength if not stats.has_status(&"slow") else maxf(_slow_strength, strength)
			stats.apply_status(&"slow", spell.status_duration)
		&"shock":
			_shock_bonus = float(spell.status_params.get("bonus", 0.2))
			stats.apply_status(&"shock", spell.status_duration)
		&"knockback":
			var force: float = float(spell.param(&"knockback_override", spell.status_params.get("force", 5.0)))
			var from: Vector3 = (source as Node3D).global_position if source is Node3D else global_position - global_basis.z
			var away: Vector3 = global_position - from
			away.y = 0.0
			apply_knockback(away.normalized() * force if away.length() > 0.01 else Vector3.ZERO)


## Fire Guard reflects part of the damage; storm Guard shocks the attacker when it breaks.
func _guard_reactions(amount: float, source: Node, had_shield: bool) -> void:
	var guard: ResolvedSpell = active_guard
	var reflect: float = float(guard.param(&"reflect_ratio", 0.0))
	if reflect > 0.0 and source != null and source != self and source.has_method(&"receive_hit"):
		source.call(&"receive_hit", amount * reflect, null, self)
	if had_shield and stats.shield <= 0.0:
		active_guard = null
		if bool(guard.param(&"shock_on_break", false)) and source != null and source != self and source.has_method(&"receive_status"):
			source.call(&"receive_status", guard, self)


func _guard_blocks_sprint() -> bool:
	return active_guard != null and stats.shield > 0.0 and bool(active_guard.param(&"no_sprint", false))


## Storm Impulse: instant blink up to distance along the movement input, stopping at walls.
func teleport(distance: float) -> void:
	var input: Vector2 = move_input if move_input.length() > 0.1 else Vector2(0.0, -1.0)
	var dir: Vector3 = transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	var motion: Vector3 = dir.normalized() * distance
	var collision: KinematicCollision3D = KinematicCollision3D.new()
	if test_move(global_transform, motion, collision):
		motion = collision.get_travel()
	global_position += motion


func apply_knockback(impulse: Vector3) -> void:
	_knockback += Vector3(impulse.x, 0.0, impulse.z)
	if impulse.y > 0.0:
		velocity.y = maxf(velocity.y, impulse.y)


func _update_statuses(delta: float) -> void:
	if stats.has_status(&"burn") and not sudden_death and (not Net.is_online() or Net.is_host()):
		_burn_tick += delta
		if _burn_tick >= BURN_TICK:
			_burn_tick -= BURN_TICK
			stats.take_damage(_burn_dps * BURN_TICK)
	else:
		_burn_tick = 0.0
	if not stats.has_status(&"slow"):
		_slow_strength = 0.0

func _validate_cast(spell: ResolvedSpell) -> StringName:
	if cast_lockout > 0.0:
		return &"lockout"
	if stats.is_dead:
		return &"dead"
	if frozen:
		return &"frozen"
	if spell.key == ARROW_KEY and _arrow_charges <= 0:
		return &"cooldown"
	if stats.is_on_cooldown(spell.key):
		return &"cooldown"
	# D1: RMB only repeats confirmed spells; quick spells are cast with their keys.
	if composer.is_recasting and spell.is_quick():
		return &"invalid"
	if not stats.can_afford(mana_cost_for(spell, composer.is_recasting)):
		return &"no_mana"
	return &""


func _on_cast_requested(spell: ResolvedSpell) -> void:
	cast_lockout = SpellComposer.CAST_LOCKOUT
	stats.spend_mana(mana_cost_for(spell, composer.is_recasting))
	if spell.key == ARROW_KEY:
		consume_arrow_charge()
	else:
		stats.start_cooldown(spell.key, cooldown_for(spell))
	if has_overcharge():
		overcharge_casts -= 1
	spell_cast.emit(spell)


## D1: how many Arrow shots are ready right now (host validation and HUD).
func arrow_charges() -> int:
	return _arrow_charges


func consume_arrow_charge() -> void:
	if _arrow_charges <= 0:
		return
	if _arrow_charges == ARROW_CHARGES:
		_arrow_recharge = 0.0
	_arrow_charges -= 1


## Impulse: dash along the movement input (forward when idle) over dash_time seconds.
func start_dash(distance: float, duration: float, iframes: float, lift: float = 0.0) -> void:
	var input: Vector2 = move_input if move_input.length() > 0.1 else Vector2(0.0, -1.0)
	var dir: Vector3 = (transform.basis * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	_dash_velocity = dir.normalized() * (distance / maxf(duration, 0.01)) + Vector3.UP * lift
	_dash_time = duration
	invulnerable_time = maxf(invulnerable_time, iframes)


## Outgoing damage multiplier (Aura, runes later).
func damage_mult() -> float:
	var mult: float = 1.0 + (float(active_aura.param(&"damage_bonus", 0.0)) if active_aura != null else 0.0)
	if rune == &"cold_blood" and stats.hp < 30.0:
		mult *= 1.2
	if has_overcharge():
		mult *= 1.2
	return mult


## Movement speed multiplier (Aura, status effects later).
func speed_mult() -> float:
	var bonus: float = float(active_aura.param(&"move_speed_bonus", 0.0)) if active_aura != null else 0.0
	var rune_bonus: float = 0.12 if rune == &"light_step" else 0.0
	return (1.0 + bonus + rune_bonus) * (1.0 - _slow_strength)


## Debug nameplate over non-local players: HP, shield and statuses. Replaced by the final HUD in M6.
func _add_nameplate() -> void:
	_nameplate = Label3D.new()
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = false
	_nameplate.font_size = 36
	_nameplate.outline_size = 8
	_nameplate.position = Vector3(0.0, 2.3, 0.0)
	add_child(_nameplate)
	var body: Node3D = preload("res://scenes/assets/mage.tscn").instantiate() as Node3D
	body.name = "ThirdPersonModel"
	add_child(body)
	var animation: Node = preload("res://scenes/player/mage_animation.gd").new()
	animation.name = "MageAnimation"
	add_child(animation)
	animation.setup(self, body)


func _process(_delta: float) -> void:
	if _nameplate == null:
		return
	var parts: PackedStringArray = PackedStringArray()
	for id: StringName in stats.active_statuses():
		parts.append(String(id))
	_nameplate.text = " ".join(parts)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position, global_position + Vector3.UP * 1.5, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		_nameplate.visible = hit.is_empty() or hit.get("collider") == self

## Applies a round's rune (spec 02 §3). Called after Stats.reset() at round start.
func apply_rune(p_rune: StringName) -> void:
	rune = p_rune
	stats.max_mana = 130.0 if rune == &"breath" else 100.0
	stats.mana = stats.max_mana
	if rune == &"husk":
		stats.add_shield(25.0, 999.0)


## Mana cost after runes (Echo makes recasts cheaper).
func mana_cost_for(spell: ResolvedSpell, is_recast: bool) -> float:
	if has_overcharge() or mana_surge:
		return 0.0
	return spell.mana_cost * (0.7 if is_recast and rune == &"echo" else 1.0)


func grant_overcharge() -> void:
	overcharge_time = 10.0
	overcharge_casts = 3


func has_overcharge() -> bool:
	return overcharge_time > 0.0 and overcharge_casts > 0

## Cooldown after Aura (storm), Haste rune and Mana Surge reductions. Used by the caster and the host.
func cooldown_for(spell: ResolvedSpell) -> float:
	var cdr: float = float(active_aura.param(&"cooldown_reduction", 0.0)) if active_aura != null else 0.0
	if rune == &"haste":
		cdr = 1.0 - (1.0 - cdr) * 0.8
	if mana_surge:
		cdr = 1.0 - (1.0 - cdr) * 0.5
	return spell.cooldown * (1.0 - cdr)


func reset_round() -> void:
	stats.max_mana = 100.0
	stats.reset()
	composer.reset()
	active_aura = null
	active_guard = null
	rune = &""
	velocity = Vector3.ZERO
	move_input = Vector2.ZERO
	_dash_velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_dash_time = 0.0
	invulnerable_time = 0.0
	glide_time = 0.0
	overcharge_time = 0.0
	overcharge_casts = 0
	cast_lockout = 0.0
	_arrow_charges = ARROW_CHARGES
	_arrow_recharge = 0.0
	_burn_dps = 0.0
	_burn_tick = 0.0
	_slow_strength = 0.0
	_coyote_timer = 0.0
	_air_jumps_used = 0
	_jump_held = false
	sudden_death = false
	mana_surge = false
	is_sprinting = false
	is_crouching = false
	_current_height = tuning.stand_height
	_apply_height(_current_height)
