@tool
class_name SpellComposer
extends Node
## Turns hotkey sequences into spells: element (fixed per round) + form key + effect key.
## Quick spells fire on the effect key; confirm spells enter aiming and fire on `cast`.
## See docs/specs/01-spell-system.md section 1.

enum State { IDLE, SLOT_EFFECT, AIMING, CASTING }

## Emitted when a spell should be cast now. The caster spawns it.
signal cast_requested(spell: ResolvedSpell)
## Emitted when the validator refuses a spell (no mana, on cooldown...).
signal cast_rejected(spell: ResolvedSpell, reason: StringName)
signal aim_started(spell: ResolvedSpell)
signal aim_ended
signal state_changed(state: State)

const SPELL_DB: GDScript = preload("res://autoload/spell_db.gd")
const SEQUENCE_TIMEOUT: float = 2.5
const AIM_TIMEOUT: float = 4.0
const CAST_LOCKOUT: float = 0.15
const INPUT_BUFFER: float = 0.15

## Element drafted for this round.
@export var element_id: StringName = &"fire"
## Only the local player reads keyboard/mouse. Tests and the network drive the press_* API.
@export var read_input: bool = true

## (element, form, effect) -> ResolvedSpell. Defaults to SpellDB.resolve.
var resolver: Callable
## (spell) -> StringName: empty when the spell may be cast, else a rejection reason.
var validator: Callable

var state: State = State.IDLE
var form: StringName = &""
var pending: ResolvedSpell
var last_spell: ResolvedSpell
## True while the spell being validated or cast came from RMB (Echo rune discount).
var is_recasting: bool = false
## Duration of the current successful request, including aiming and buffered input.
var compose_seconds: float = -1.0
var _compose_elapsed: float = 0.0

var _timer: float = 0.0
var _buffered_slot: int = -1
var _buffer_age: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not resolver.is_valid():
		var db: Node = get_node_or_null(^"/root/SpellDB")
		if db != null:
			resolver = Callable(db, &"resolve")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if read_input and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_poll_input()
	tick(delta)


## Polled (not event-driven) so the same path works for real keys and injected action state.
func _poll_input() -> void:
	if Input.is_action_just_pressed(&"slot_1"):
		press_slot(0)
	if Input.is_action_just_pressed(&"slot_2"):
		press_slot(1)
	if Input.is_action_just_pressed(&"slot_3"):
		press_slot(2)
	if Input.is_action_just_pressed(&"compose_cancel"):
		press_cancel()
	if Input.is_action_just_pressed(&"cast"):
		press_cast()
	if Input.is_action_just_pressed(&"recast"):
		press_recast()


func tick(delta: float) -> void:
	if is_composing():
		_compose_elapsed += delta
	match state:
		State.SLOT_EFFECT:
			_timer -= delta
			if _timer <= 0.0:
				clear()
		State.AIMING:
			_timer -= delta
			if _timer <= 0.0:
				clear()
		State.CASTING:
			_timer -= delta
			if _buffered_slot >= 0:
				_buffer_age += delta
			if _timer <= 0.0:
				_set_state(State.IDLE)
				var slot: int = _buffered_slot
				_buffered_slot = -1
				if slot >= 0 and _buffer_age <= INPUT_BUFFER + CAST_LOCKOUT:
					press_slot(slot)
					_compose_elapsed = _buffer_age


## Q/E/R = slot 0/1/2. First press picks the form, second picks the effect.
func press_slot(index: int) -> void:
	match state:
		State.IDLE:
			form = SPELL_DB.form_at(index)
			if form == &"":
				return
			_timer = SEQUENCE_TIMEOUT
			_compose_elapsed = 0.0
			_set_state(State.SLOT_EFFECT)
		State.SLOT_EFFECT:
			var effect: StringName = SPELL_DB.effect_at(index)
			if effect == &"":
				return
			var spell: ResolvedSpell = _resolve(form, effect)
			if spell == null:
				clear()
				return
			_begin(spell)
		State.CASTING:
			_buffered_slot = index
			_buffer_age = 0.0
		State.AIMING:
			pass


func press_cast() -> void:
	if state == State.AIMING and pending != null:
		_fire(pending)


## RMB: cancels aiming, otherwise repeats the last confirmed spell (D1; never a quick one).
func press_recast() -> void:
	match state:
		State.AIMING:
			clear()
		State.IDLE:
			if last_spell != null and not last_spell.is_quick():
				is_recasting = true
				_begin(last_spell)
				is_recasting = state == State.AIMING


func press_cancel() -> void:
	if state == State.SLOT_EFFECT or state == State.AIMING:
		clear()


## Drops the sequence and any aim. Called on F, timeouts, death and round end.
func clear() -> void:
	is_recasting = false
	_compose_elapsed = 0.0
	compose_seconds = -1.0
	var was_aiming: bool = state == State.AIMING
	form = &""
	pending = null
	_buffered_slot = -1
	_timer = 0.0
	_set_state(State.IDLE)
	if was_aiming:
		aim_ended.emit()


## Forgets the last spell too (round start: the element may have changed).
func reset() -> void:
	clear()
	last_spell = null


func is_composing() -> bool:
	return state == State.SLOT_EFFECT or state == State.AIMING


func _begin(spell: ResolvedSpell) -> void:
	form = spell.form
	if spell.is_quick():
		_fire(spell)
	else:
		var reason: StringName = _validate(spell)
		if reason != &"":
			cast_rejected.emit(spell, reason)
			clear()
			return
		pending = spell
		_timer = AIM_TIMEOUT
		_set_state(State.AIMING)
		aim_started.emit(spell)


func _fire(spell: ResolvedSpell) -> void:
	var reason: StringName = _validate(spell)
	var was_aiming: bool = state == State.AIMING
	if reason != &"":
		cast_rejected.emit(spell, reason)
		clear()
		return
	last_spell = spell
	compose_seconds = -1.0 if is_recasting else _compose_elapsed
	pending = null
	# A recast that went through aiming still counts as a recast when confirmed.
	form = &""
	_timer = CAST_LOCKOUT
	_set_state(State.CASTING)
	if was_aiming:
		aim_ended.emit()
	cast_requested.emit(spell)
	is_recasting = false


func _resolve(form_id: StringName, effect_id: StringName) -> ResolvedSpell:
	if not resolver.is_valid():
		push_error("SpellComposer: no resolver")
		return null
	return resolver.call(element_id, form_id, effect_id) as ResolvedSpell


func _validate(spell: ResolvedSpell) -> StringName:
	if not validator.is_valid():
		return &""
	return validator.call(spell) as StringName


func _set_state(new_state: State) -> void:
	if state != new_state:
		state = new_state
		state_changed.emit(state)
