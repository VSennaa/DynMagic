class_name Player
extends CharacterBody3D
## First-person player body: movement, crouch, jump and mouse look.
## See docs/specs/05-player-controller.md.

## Emitted after mana and cooldown are paid. Spell scenes subscribe here.
signal spell_cast(spell: ResolvedSpell)

const PITCH_LIMIT: float = deg_to_rad(89.0)
const KNOCKBACK_DECAY: float = 18.0
const BURN_TICK: float = 0.5

@export var tuning: PlayerTuning = preload("res://data/player_tuning.tres")
## Only the local player reads input. Remote players are driven by NetSync (M3).
@export var is_local: bool = true

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

var _dash_velocity: Vector3 = Vector3.ZERO
## Knockback added on top of walking velocity; decays over time.
var _knockback: Vector3 = Vector3.ZERO
var _burn_dps: float = 0.0
var _burn_tick: float = 0.0
var _slow_strength: float = 0.0
var _nameplate: Label3D
var _shock_bonus: float = 0.2
var _dash_time: float = 0.0
var _coyote_timer: float = 0.0
var _current_height: float = 1.8
var _pitch: float = 0.0

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
	else:
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
	elif event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not is_local:
		# Offline stand-in until NetSync (M3) drives remote players: idle but still ticks statuses and knockback.
		simulate(delta, Vector2.ZERO, false, false, false)
		return
	var input_dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	simulate(delta, input_dir, Input.is_action_pressed(&"jump"), Input.is_action_pressed(&"crouch"), Input.is_action_pressed(&"sprint"))


## One movement tick. Kept free of Input reads so the host can replay client inputs (M3).
func simulate(delta: float, input_dir: Vector2, want_jump: bool, want_crouch: bool, want_sprint: bool) -> void:
	move_input = input_dir
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
		velocity.y -= tuning.gravity * delta

	if want_jump and _coyote_timer > 0.0 and not is_crouching:
		velocity.y = tuning.jump_velocity()
		_coyote_timer = 0.0

	# Sprint only while moving forward, standing, and not composing a spell.
	is_sprinting = want_sprint and not sprint_blocked and not is_crouching and input_dir.y < -0.1
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
	if invulnerable_time > 0.0:
		return
	# Shock: the next damage taken is increased, then the shock is consumed.
	if stats.has_status(&"shock") and amount > 0.0:
		amount *= 1.0 + _shock_bonus
		stats.clear_status(&"shock")
	stats.take_damage(amount)
	if spell != null and bool(spell.param(&"applies_status", false)):
		receive_status(spell, source)


## Applies the element status carried by a spell (spec 01 §3). Zones call this directly.
func receive_status(spell: ResolvedSpell, source: Node = null) -> void:
	if invulnerable_time > 0.0 or spell == null:
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


func apply_knockback(impulse: Vector3) -> void:
	_knockback += Vector3(impulse.x, 0.0, impulse.z)
	if impulse.y > 0.0:
		velocity.y = maxf(velocity.y, impulse.y)


func _update_statuses(delta: float) -> void:
	if stats.has_status(&"burn"):
		_burn_tick += delta
		if _burn_tick >= BURN_TICK:
			_burn_tick -= BURN_TICK
			stats.take_damage(_burn_dps * BURN_TICK)
	else:
		_burn_tick = 0.0
	if not stats.has_status(&"slow"):
		_slow_strength = 0.0

func _validate_cast(spell: ResolvedSpell) -> StringName:
	if stats.is_dead:
		return &"dead"
	if stats.is_on_cooldown(spell.key):
		return &"cooldown"
	if not stats.can_afford(spell.mana_cost):
		return &"no_mana"
	return &""


func _on_cast_requested(spell: ResolvedSpell) -> void:
	stats.spend_mana(spell.mana_cost)
	stats.start_cooldown(spell.key, spell.cooldown)
	spell_cast.emit(spell)


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
	return 1.0 + (float(active_aura.param(&"damage_bonus", 0.0)) if active_aura != null else 0.0)


## Movement speed multiplier (Aura, status effects later).
func speed_mult() -> float:
	var bonus: float = float(active_aura.param(&"move_speed_bonus", 0.0)) if active_aura != null else 0.0
	return (1.0 + bonus) * (1.0 - _slow_strength)


## Debug nameplate over non-local players: HP, shield and statuses. Replaced by the final HUD in M6.
func _add_nameplate() -> void:
	_nameplate = Label3D.new()
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = true
	_nameplate.font_size = 36
	_nameplate.outline_size = 8
	_nameplate.position = Vector3(0.0, 2.3, 0.0)
	add_child(_nameplate)
	# Remote players need a visible body until the character model exists (M7).
	var body: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = tuning.capsule_radius
	capsule.height = tuning.stand_height
	body.mesh = capsule
	body.position.y = tuning.stand_height * 0.5
	add_child(body)


func _process(_delta: float) -> void:
	if _nameplate == null:
		return
	var parts: PackedStringArray = PackedStringArray()
	for id: StringName in stats.active_statuses():
		parts.append(String(id))
	_nameplate.text = "HP %d%s\n%s" % [roundi(stats.hp), " +%d" % roundi(stats.shield) if stats.shield > 0.0 else "", " ".join(parts)]
