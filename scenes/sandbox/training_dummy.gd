class_name TrainingDummy
extends AnimatableBody3D
## Target with infinite HP. Shows floating damage numbers and a rolling DPS counter,
## wobbles when hit and can patrol side to side (strafing target).

const DPS_WINDOW: float = 5.0
const NUMBER_LIFETIME: float = 0.9

## Side-to-side patrol distance in metres (0 = stands still) and speed in m/s.
@export var patrol_distance: float = 0.0
@export var patrol_speed: float = 3.0

var total_damage: float = 0.0
var last_hit_spell: StringName = &""
var statuses: Dictionary[StringName, float] = {}

## [time, amount] pairs inside the DPS window.
var _recent: Array[Vector2] = []
var _clock: float = 0.0
var _origin: Vector3
var _wobble: float = 0.0

@onready var _dps_label: Label3D = $DpsLabel
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(&"damageable")
	_origin = position


func _physics_process(delta: float) -> void:
	if patrol_distance > 0.0:
		var side: Vector3 = global_basis.x
		position = _origin + side * sin(_clock * patrol_speed / maxf(patrol_distance, 0.01)) * patrol_distance
	# Hit wobble: a damped sway of the visual only (collision stays upright).
	_wobble = move_toward(_wobble, 0.0, delta * 2.5)
	_visual.rotation.z = sin(_clock * 22.0) * 0.18 * _wobble


func _process(delta: float) -> void:
	_clock += delta
	while not _recent.is_empty() and _clock - _recent[0].x > DPS_WINDOW:
		_recent.pop_front()
	for id: StringName in statuses.keys():
		statuses[id] -= delta
		if statuses[id] <= 0.0:
			statuses.erase(id)
	# Only show numbers while the dummy is being worked on (keeps the arena clean).
	_dps_label.visible = not _recent.is_empty() or not statuses.is_empty()
	_dps_label.text = "DPS %.1f  ·  %.0f%s" % [dps(), total_damage, _status_text()]


func receive_hit(amount: float, spell: ResolvedSpell, _source: Node) -> void:
	total_damage += amount
	_recent.append(Vector2(_clock, amount))
	if spell != null:
		last_hit_spell = spell.key
		if spell.status_id != &"" and bool(spell.param(&"applies_status", false)):
			statuses[spell.status_id] = spell.status_duration
	_wobble = 1.0
	if Settings.show_damage_numbers:
		_spawn_number(amount, spell.color if spell != null else Color.WHITE)


func receive_status(spell: ResolvedSpell, _source: Node = null) -> void:
	if spell != null and spell.status_id != &"":
		statuses[spell.status_id] = maxf(spell.status_duration, 0.3)


func dps() -> float:
	var sum: float = 0.0
	for entry: Vector2 in _recent:
		sum += entry.y
	return sum / DPS_WINDOW


func _status_text() -> String:
	return "" if statuses.is_empty() else "\n" + ", ".join(statuses.keys())


func _spawn_number(amount: float, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.text = "%.0f" % amount
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 64
	label.outline_size = 12
	label.position = Vector3(randf_range(-0.3, 0.3), 2.1, 0.0)
	add_child(label)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, ^"position:y", label.position.y + 0.8, NUMBER_LIFETIME)
	tween.tween_property(label, ^"modulate:a", 0.0, NUMBER_LIFETIME)
	tween.chain().tween_callback(label.queue_free)
