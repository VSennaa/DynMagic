@tool
extends McpTestSuite
## Spell resolution against docs/specs/01-spell-system.md sections 2, 2.1 and 3.

const SPELL_DB: GDScript = preload("res://autoload/spell_db.gd")

## key -> [base damage, mana, cooldown, cast mode]
const EXPECTED_BASES: Dictionary = {
	&"projectile_direct": [16.0, 12.0, 0.35, SpellBase.CastMode.QUICK],
	&"projectile_burst": [28.0, 30.0, 2.0, SpellBase.CastMode.CONFIRM],
	&"projectile_lingering": [0.0, 22.0, 5.0, SpellBase.CastMode.CONFIRM],
	&"self_direct": [0.0, 25.0, 8.0, SpellBase.CastMode.QUICK],
	&"self_burst": [0.0, 20.0, 4.0, SpellBase.CastMode.QUICK],
	&"self_lingering": [0.0, 30.0, 14.0, SpellBase.CastMode.QUICK],
	&"area_direct": [20.0, 18.0, 1.2, SpellBase.CastMode.QUICK],
	&"area_burst": [38.0, 35.0, 6.0, SpellBase.CastMode.CONFIRM],
	&"area_lingering": [0.0, 30.0, 10.0, SpellBase.CastMode.CONFIRM],
}

## element id -> damage multiplier
const EXPECTED_MULTS: Dictionary = {
	&"fire": 1.15,
}

var db: Node


func suite_name() -> String:
	return "spell_resolution"


func setup() -> void:
	db = SPELL_DB.new()
	db.call(&"load_all")


func teardown() -> void:
	db.free()


func test_all_nine_bases_loaded() -> void:
	var bases: Dictionary = db.get(&"bases")
	assert_eq(bases.size(), 9)
	for key: StringName in EXPECTED_BASES.keys():
		assert_true(bases.has(key), "missing base %s" % key)


func test_every_combination_resolves() -> void:
	for element_id: StringName in EXPECTED_MULTS.keys():
		var mult: float = EXPECTED_MULTS[element_id]
		for form: StringName in SPELL_DB.FORMS:
			for effect: StringName in SPELL_DB.EFFECTS:
				var spell: ResolvedSpell = db.call(&"resolve", element_id, form, effect)
				var key: StringName = SpellBase.make_key(form, effect)
				var expected: Array = EXPECTED_BASES[key]
				assert_true(spell != null, "%s/%s did not resolve" % [element_id, key])
				assert_true(absf(spell.damage - float(expected[0]) * mult) < 0.001, "%s/%s damage %f" % [element_id, key, spell.damage])
				assert_eq(spell.mana_cost, expected[1], "%s/%s mana" % [element_id, key])
				assert_eq(spell.cooldown, expected[2], "%s/%s cooldown" % [element_id, key])
				assert_eq(spell.cast_mode, expected[3], "%s/%s cast mode" % [element_id, key])
				assert_eq(spell.key, key)
				assert_eq(spell.element, element_id)


func test_fire_variants_merge_into_params() -> void:
	var cone: ResolvedSpell = db.call(&"resolve", &"fire", &"area", &"direct")
	assert_eq(cone.param(&"range"), 7.0, "fire cone reaches 7 m")
	assert_eq(cone.param(&"angle_deg"), 50.0, "base params survive the merge")
	var seed: ResolvedSpell = db.call(&"resolve", &"fire", &"projectile", &"lingering")
	assert_eq(seed.param(&"zone_dps"), 8.0)
	assert_eq(seed.status_id, &"burn")


func test_resolution_does_not_mutate_base() -> void:
	db.call(&"resolve", &"fire", &"area", &"direct")
	var bases: Dictionary = db.get(&"bases")
	var base: SpellBase = bases[&"area_direct"]
	assert_eq(base.params["range"], 6.0)


func test_slot_index_mapping() -> void:
	assert_eq(SPELL_DB.form_at(0), &"projectile")
	assert_eq(SPELL_DB.form_at(1), &"self")
	assert_eq(SPELL_DB.form_at(2), &"area")
	assert_eq(SPELL_DB.effect_at(0), &"direct")
	assert_eq(SPELL_DB.effect_at(1), &"burst")
	assert_eq(SPELL_DB.effect_at(2), &"lingering")
	assert_eq(SPELL_DB.form_at(3), &"")
