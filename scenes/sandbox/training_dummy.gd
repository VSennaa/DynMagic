class_name TrainingDummy
extends StaticBody3D
## Target with infinite HP. Shows floating damage numbers and a rolling DPS counter.

const DPS_WINDOW: float = 5.0
const NUMBER_LIFETIME: float = 0.9

var total_damage: float = 0.0
var last_hit_spell: StringName = &""
var statuses: Dictionary[StringName, float] = {}

## [time, amount] pairs inside the DPS window.
var _recent: Array[Vector2] = []
var _clock: float = 0.0

@onready var _dps_label: Label3D = $DpsLabel


func _ready() -> void:
	add_to_group(&"damageable")


func _process(delta: float) -> void:
	_clock += delta
	while not _recent.is_empty() and _clock - _recent[0].x > DPS_WINDOW:
		_recent.pop_front()
	for id: StringName in statuses.keys():
		statuses[id] -= delta
		if statuses[id] <= 0.0:
			statuses.erase(id)
	_dps_label.text = "DPS %.1f\nTotal %.0f%s" % [dps(), total_damage, _status_text()]


func receive_hit(amount: float, spell: ResolvedSpell, _source: Node) -> void:
	total_damage += amount
	_recent.append(Vector2(_clock, amount))
	if spell != null:
		last_hit_spell = spell.key
		if spell.status_id != &"" and bool(spell.param(&"applies_status", false)):
			statuses[spell.status_id] = spell.status_duration
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
