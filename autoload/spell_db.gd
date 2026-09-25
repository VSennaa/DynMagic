## Spell data registry and pure spell resolution. See docs/specs/01-spell-system.md.
@tool
extends Node

const FORMS: Array[StringName] = [&"projectile", &"self", &"area"]
const EFFECTS: Array[StringName] = [&"direct", &"burst", &"lingering"]
const BASES_DIR: String = "res://data/spells/"
const ELEMENTS_DIR: String = "res://data/elements/"

var bases: Dictionary[StringName, SpellBase] = {}
var elements: Dictionary[StringName, ElementDef] = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	bases.clear()
	elements.clear()
	for res: Resource in _load_dir(BASES_DIR):
		var base: SpellBase = res as SpellBase
		if base != null:
			bases[base.key()] = base
	for res: Resource in _load_dir(ELEMENTS_DIR):
		var element: ElementDef = res as ElementDef
		if element != null:
			elements[element.id] = element


## Slot index (0, 1, 2 for Q, E, R) to form or effect id.
static func form_at(index: int) -> StringName:
	return FORMS[index] if index >= 0 and index < FORMS.size() else &""


static func effect_at(index: int) -> StringName:
	return EFFECTS[index] if index >= 0 and index < EFFECTS.size() else &""


func resolve(element_id: StringName, form: StringName, effect: StringName) -> ResolvedSpell:
	var base: SpellBase = bases.get(SpellBase.make_key(form, effect))
	var element: ElementDef = elements.get(element_id)
	if base == null or element == null:
		push_error("SpellDB: cannot resolve %s/%s/%s" % [element_id, form, effect])
		return null
	return resolve_with(base, element)


## Pure function: base numbers × element multiplier + element variant params.
static func resolve_with(base: SpellBase, element: ElementDef) -> ResolvedSpell:
	var spell: ResolvedSpell = ResolvedSpell.new()
	spell.element = element.id
	spell.form = base.form
	spell.effect = base.effect
	spell.key = base.key()
	spell.display_name = base.display_name
	spell.cast_mode = base.cast_mode
	spell.scene = base.scene
	spell.color = element.color
	spell.base_damage = base.damage
	spell.damage = base.damage * element.damage_mult
	spell.mana_cost = base.mana_cost
	spell.cooldown = base.cooldown
	spell.params = base.params.duplicate(true)
	spell.params.merge(element.variant_for(spell.key), true)
	spell.status_id = element.status_id
	spell.status_duration = element.status_duration
	spell.status_params = element.status_params.duplicate(true)
	return spell


func _load_dir(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	for file: String in ResourceLoader.list_directory(dir_path):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res: Resource = load(dir_path + file)
			if res != null:
				out.append(res)
	return out
