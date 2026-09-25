@tool
extends McpTestSuite
## SpellComposer state machine (docs/specs/01-spell-system.md section 1).

const SPELL_DB: GDScript = preload("res://autoload/spell_db.gd")

var db: Node
var composer: SpellComposer
var casts: Array[ResolvedSpell] = []
var rejections: Array[StringName] = []
var reject_reason: StringName = &""


func suite_name() -> String:
	return "spell_composer"


func setup() -> void:
	db = SPELL_DB.new()
	db.call(&"load_all")
	composer = SpellComposer.new()
	composer.read_input = false
	composer.element_id = &"fire"
	composer.resolver = Callable(db, &"resolve")
	composer.validator = func(_spell: ResolvedSpell) -> StringName: return reject_reason
	composer.cast_requested.connect(func(spell: ResolvedSpell) -> void: casts.append(spell))
	composer.cast_rejected.connect(func(_spell: ResolvedSpell, reason: StringName) -> void: rejections.append(reason))
	casts.clear()
	rejections.clear()
	reject_reason = &""


func teardown() -> void:
	composer.free()
	db.free()


func test_quick_spell_fires_on_effect_key() -> void:
	composer.press_slot(0)  # projectile
	assert_eq(composer.state, SpellComposer.State.SLOT_EFFECT)
	assert_eq(casts.size(), 0, "incomplete sequence never casts")
	composer.press_slot(0)  # direct = Bolt (quick)
	assert_eq(casts.size(), 1)
	assert_eq(casts[0].key, &"projectile_direct")
	assert_eq(composer.state, SpellComposer.State.CASTING)


func test_cast_click_with_incomplete_sequence_does_nothing() -> void:
	composer.press_cast()
	composer.press_slot(2)
	composer.press_cast()
	assert_eq(casts.size(), 0)


func test_confirm_spell_waits_for_click() -> void:
	composer.press_slot(2)  # area
	composer.press_slot(1)  # burst = Mark (confirm)
	assert_eq(composer.state, SpellComposer.State.AIMING)
	assert_eq(casts.size(), 0)
	composer.press_cast()
	assert_eq(casts.size(), 1)
	assert_eq(casts[0].key, &"area_burst")


func test_rmb_cancels_aim_without_casting() -> void:
	composer.press_slot(2)
	composer.press_slot(2)  # Wall (confirm)
	composer.press_recast()
	assert_eq(composer.state, SpellComposer.State.IDLE)
	assert_eq(casts.size(), 0)


func test_cancel_key_clears_sequence() -> void:
	composer.press_slot(0)
	composer.press_cancel()
	assert_eq(composer.state, SpellComposer.State.IDLE)
	assert_eq(composer.form, &"")


func test_sequence_times_out() -> void:
	composer.press_slot(0)
	composer.tick(2.4)
	assert_eq(composer.state, SpellComposer.State.SLOT_EFFECT)
	composer.tick(0.2)
	assert_eq(composer.state, SpellComposer.State.IDLE)


func test_aim_times_out_without_casting() -> void:
	composer.press_slot(0)
	composer.press_slot(1)  # Orb (confirm)
	composer.tick(4.1)
	assert_eq(composer.state, SpellComposer.State.IDLE)
	assert_eq(casts.size(), 0)


func test_recast_ignores_quick_spells() -> void:
	composer.press_slot(1)
	composer.press_slot(1)  # Impulse (quick)
	composer.tick(0.2)
	composer.press_recast()
	assert_eq(casts.size(), 1, "D1: RMB never repeats a quick spell")
	assert_eq(composer.state, SpellComposer.State.IDLE)


func test_recast_of_confirm_spell_enters_aiming() -> void:
	composer.press_slot(0)
	composer.press_slot(2)  # Seed (confirm)
	composer.press_cast()
	composer.tick(0.2)
	composer.press_recast()
	assert_eq(composer.state, SpellComposer.State.AIMING)
	assert_eq(casts.size(), 1)


func test_validator_rejects_and_resets() -> void:
	reject_reason = &"no_mana"
	composer.press_slot(0)
	composer.press_slot(0)
	assert_eq(casts.size(), 0)
	assert_eq(rejections, [&"no_mana"] as Array[StringName])
	assert_eq(composer.state, SpellComposer.State.IDLE)


func test_rejected_confirm_spell_never_enters_aiming() -> void:
	reject_reason = &"cooldown"
	composer.press_slot(2)
	composer.press_slot(1)
	assert_eq(composer.state, SpellComposer.State.IDLE)


func test_key_during_lockout_is_buffered() -> void:
	composer.press_slot(0)
	composer.press_slot(0)  # Bolt, lockout starts
	composer.press_slot(2)  # buffered: area
	composer.tick(0.16)
	assert_eq(composer.state, SpellComposer.State.SLOT_EFFECT)
	assert_eq(composer.form, &"area")


func test_clear_on_death_or_round_end() -> void:
	composer.press_slot(2)
	composer.press_slot(1)
	composer.reset()
	assert_eq(composer.state, SpellComposer.State.IDLE)
	assert_true(composer.last_spell == null)


func test_is_composing_blocks_sprint() -> void:
	assert_false(composer.is_composing())
	composer.press_slot(0)
	assert_true(composer.is_composing())


func test_compose_duration_includes_aim_and_excludes_recast() -> void:
	composer.press_slot(0)
	composer.tick(0.5)
	composer.press_slot(1)
	composer.tick(1.0)
	composer.press_cast()
	assert_eq(composer.compose_seconds, 1.5)
	composer.tick(0.2)
	composer.press_recast()
	composer.tick(0.5)
	composer.press_cast()
	assert_eq(composer.compose_seconds, -1.0)


func test_cancel_reject_and_timeout_restart_measurement() -> void:
	composer.press_slot(0)
	composer.tick(0.5)
	composer.press_cancel()
	composer.press_slot(0)
	composer.tick(0.25)
	composer.press_slot(0)
	assert_eq(composer.compose_seconds, 0.25)
	composer.tick(0.2)
	reject_reason = &"cooldown"
	composer.press_slot(0)
	composer.press_slot(0)
	assert_eq(composer.compose_seconds, -1.0)
	reject_reason = &""
	composer.press_slot(0)
	composer.tick(3.0)
	composer.press_slot(0)
	composer.tick(0.5)
	composer.press_slot(0)
	assert_eq(composer.compose_seconds, 0.5)


func test_buffered_first_key_counts_lockout_wait() -> void:
	composer.press_slot(0)
	composer.press_slot(0)
	composer.press_slot(2)
	composer.tick(0.16)
	composer.tick(0.2)
	composer.press_slot(0)
	assert_true(absf(composer.compose_seconds - 0.36) < 0.001)
