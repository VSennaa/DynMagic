@tool
class_name Stats
extends Node
## HP, mana, shield, status timers and spell cooldowns for one player.
## Host-authoritative in multiplayer (docs/specs/04-networking.md section 4).
## See docs/specs/05-player-controller.md section 3.

signal hp_changed(hp: float, max_hp: float)
signal mana_changed(mana: float, max_mana: float)
signal shield_changed(shield: float)
signal died
signal status_applied(status_id: StringName, remaining: float)
signal status_expired(status_id: StringName)

## Status durations stack up to this multiple of the applied duration.
const STATUS_STACK_CAP: float = 2.0

@export var max_hp: float = 100.0
@export var max_mana: float = 100.0
@export var mana_regen: float = 12.0
## Mana regeneration pauses for this long after each cast.
@export var regen_pause: float = 0.5

var hp: float = 100.0
var mana: float = 100.0
var shield: float = 0.0
var shield_time_left: float = 0.0
var is_dead: bool = false

var _regen_pause_left: float = 0.0
## status id -> seconds left
var _statuses: Dictionary[StringName, float] = {}
## spell key (form_effect) -> seconds left
var _cooldowns: Dictionary[StringName, float] = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	reset()


func _physics_process(delta: float) -> void:
	# @tool only so editor tests can instantiate it; never tick inside the editor.
	if Engine.is_editor_hint():
		return
	tick(delta)


## Restores full HP and mana and clears shield, statuses and cooldowns (round start).
func reset() -> void:
	hp = max_hp
	mana = max_mana
	shield = 0.0
	shield_time_left = 0.0
	is_dead = false
	_regen_pause_left = 0.0
	_statuses.clear()
	_cooldowns.clear()
	hp_changed.emit(hp, max_hp)
	mana_changed.emit(mana, max_mana)
	shield_changed.emit(shield)


func tick(delta: float) -> void:
	if is_dead:
		return
	if _regen_pause_left > 0.0:
		_regen_pause_left = maxf(_regen_pause_left - delta, 0.0)
	elif mana < max_mana:
		mana = minf(mana + mana_regen * delta, max_mana)
		mana_changed.emit(mana, max_mana)

	if shield_time_left > 0.0:
		shield_time_left -= delta
		if shield_time_left <= 0.0:
			shield_time_left = 0.0
			shield = 0.0
			shield_changed.emit(shield)

	for id: StringName in _statuses.keys():
		_statuses[id] -= delta
		if _statuses[id] <= 0.0:
			_statuses.erase(id)
			status_expired.emit(id)

	for key: StringName in _cooldowns.keys():
		_cooldowns[key] -= delta
		if _cooldowns[key] <= 0.0:
			_cooldowns.erase(key)


## Applies damage through the shield first. Returns the HP actually lost.
func take_damage(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var remaining: float = amount
	if shield > 0.0:
		var absorbed: float = minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		if shield <= 0.0:
			shield = 0.0
			shield_time_left = 0.0
		shield_changed.emit(shield)
	var lost: float = minf(hp, remaining)
	hp -= lost
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		hp = 0.0
		is_dead = true
		died.emit()
	return lost


## Replaces the current shield when the new one is larger.
func add_shield(amount: float, duration: float) -> void:
	if amount >= shield:
		shield = amount
		shield_time_left = duration
		shield_changed.emit(shield)


func clear_shield() -> void:
	shield = 0.0
	shield_time_left = 0.0
	shield_changed.emit(shield)


func can_afford(cost: float) -> bool:
	return mana >= cost


## Spends mana and pauses regeneration. Returns false without spending when short.
func spend_mana(cost: float) -> bool:
	if not can_afford(cost):
		return false
	mana -= cost
	_regen_pause_left = regen_pause
	mana_changed.emit(mana, max_mana)
	return true


## Adds duration to a status. Durations stack up to STATUS_STACK_CAP × duration; intensity never stacks.
func apply_status(status_id: StringName, duration: float) -> void:
	var current: float = _statuses.get(status_id, 0.0)
	var total: float = minf(current + duration, duration * STATUS_STACK_CAP)
	_statuses[status_id] = maxf(total, current)
	status_applied.emit(status_id, _statuses[status_id])


func has_status(status_id: StringName) -> bool:
	return _statuses.has(status_id)


func status_time_left(status_id: StringName) -> float:
	return _statuses.get(status_id, 0.0)


## Copy of status id -> seconds left (for the HUD).
func active_statuses() -> Dictionary[StringName, float]:
	return _statuses.duplicate()


func clear_status(status_id: StringName) -> void:
	if _statuses.erase(status_id):
		status_expired.emit(status_id)


func start_cooldown(spell_key: StringName, seconds: float) -> void:
	if seconds > 0.0:
		_cooldowns[spell_key] = seconds


func cooldown_left(spell_key: StringName) -> float:
	return _cooldowns.get(spell_key, 0.0)


func is_on_cooldown(spell_key: StringName) -> bool:
	return _cooldowns.has(spell_key)
