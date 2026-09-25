extends Control
## Grimório (spec 06 §1): pick element, form and effect to read any of the 36 spells.

const FORM_NAMES: Array[String] = ["Projétil", "Pessoal", "Área"]
const EFFECT_NAMES: Array[String] = ["Direto", "Explosivo", "Contínuo"]

var _element: int = 0
var _form: int = 0
var _effect: int = 0
var _details: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var column: VBoxContainer = UiKit.screen(self)
	column.add_child(UiKit.title("Grimório", 44))
	var elements: Array[Control] = []
	for i: int in MatchFsm.ELEMENTS.size():
		var element: ElementDef = SpellDB.elements.get(MatchFsm.ELEMENTS[i])
		elements.append(UiKit.button(element.display_name if element != null else String(MatchFsm.ELEMENTS[i]), _pick.bind(0, i)))
	column.add_child(UiKit.row(elements))
	var forms: Array[Control] = []
	for i: int in 3:
		forms.append(UiKit.button("%s %s" % [["Q", "E", "R"][i], FORM_NAMES[i]], _pick.bind(1, i)))
	column.add_child(UiKit.row(forms))
	var effects: Array[Control] = []
	for i: int in 3:
		effects.append(UiKit.button("%s %s" % [["Q", "E", "R"][i], EFFECT_NAMES[i]], _pick.bind(2, i)))
	column.add_child(UiKit.row(effects))
	_details = UiKit.label("", 20)
	_details.custom_minimum_size = Vector2(620, 260)
	column.add_child(_details)
	column.add_child(UiKit.button("Voltar", func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU)))
	_refresh()


func _pick(slot: int, index: int) -> void:
	AudioBus.play_ui("page", -6.0)
	match slot:
		0: _element = index
		1: _form = index
		2: _effect = index
	_refresh()


func _refresh() -> void:
	var spell: ResolvedSpell = SpellDB.resolve(MatchFsm.ELEMENTS[_element], SpellDB.form_at(_form), SpellDB.effect_at(_effect))
	if spell == null:
		_details.text = "?"
		return
	var extras: PackedStringArray = PackedStringArray()
	for key: Variant in spell.params:
		extras.append("%s: %s" % [key, spell.params[key]])
	_details.modulate = spell.color.lerp(Color.WHITE, 0.4)
	_details.text = "%s de %s  —  %s ▸ %s\nConjuração: %s\nDano %.1f   Mana %d   Recarga %.2f s\nStatus do elemento: %s (%.1f s)\n\n%s" % [
		spell.display_name, (SpellDB.elements[spell.element] as ElementDef).display_name,
		FORM_NAMES[_form], EFFECT_NAMES[_effect],
		"rápida (dispara na tecla)" if spell.is_quick() else "confirmada (mira + LMB)",
		spell.damage, roundi(spell.mana_cost), spell.cooldown,
		Glossary.status(spell.status_id), spell.status_duration, "\n".join(extras)]
