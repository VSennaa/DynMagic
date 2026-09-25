class_name Player
extends CharacterBody3D
## First-person player body: movement, crouch, jump and mouse look.
## See docs/specs/05-player-controller.md.

## Emitted after mana and cooldown are paid. Spell scenes subscribe here.
signal spell_cast(spell: ResolvedSpell)

const PITCH_LIMIT: float = deg_to_rad(89.0)

@export var tuning: PlayerTuning = preload("res://data/player_tuning.tres")
## Only the local player reads input. Remote players are driven by NetSync (M3).
@export var is_local: bool = true

## Set by the spell composer: sprint is blocked while composing a spell.
var sprint_blocked: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false

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
		return
	var input_dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	simulate(delta, input_dir, Input.is_action_pressed(&"jump"), Input.is_action_pressed(&"crouch"), Input.is_action_pressed(&"sprint"))


## One movement tick. Kept free of Input reads so the host can replay client inputs (M3).
func simulate(delta: float, input_dir: Vector2, want_jump: bool, want_crouch: bool, want_sprint: bool) -> void:
	_update_crouch(delta, want_crouch)

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
	wish = wish.normalized() * speed
	var accel: float = tuning.ground_acceleration if is_on_floor() else tuning.air_acceleration
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(wish, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var was_on_floor: bool = is_on_floor()
	var pre_move: Transform3D = global_transform
	var pre_velocity: Vector3 = velocity
	move_and_slide()
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
func receive_hit(amount: float, spell: ResolvedSpell, _source: Node) -> void:
	stats.take_damage(amount)
	if spell != null and spell.status_id != &"" and bool(spell.param(&"applies_status", false)):
		stats.apply_status(spell.status_id, spell.status_duration)


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
