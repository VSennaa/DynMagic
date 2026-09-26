extends Control
## Grimório (spec 06 §1): reference table of the 9 spells of each element —
## shortcut, spell, effect and cast mode — instead of an explorer.

const SLOT_ACTIONS: Array[StringName] = [&"slot_1", &"slot_2", &"slot_3"]

var _element: int = 0
var _table: GridContainer
var _title: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var column: VBoxContainer = UiKit.screen(self, 900.0)
	column.add_child(UiKit.title("Grimório", 44))
	var elements: Array[Control] = []
	for i: int in MatchFsm.ELEMENTS.size():
		var element: ElementDef = SpellDB.elements.get(MatchFsm.ELEMENTS[i])
		var button: Button = UiKit.button(Glossary.element(MatchFsm.ELEMENTS[i]), _pick.bind(i))
		if element != null:
			button.add_theme_color_override(&"font_color", element.color)
		elements.append(button)
	column.add_child(UiKit.row(elements))
	_title = UiKit.label("", 18)
	column.add_child(_title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(880, 460)
	column.add_child(scroll)
	_table = GridContainer.new()
	_table.columns = 4
	_table.add_theme_constant_override(&"h_separation", 24)
	_table.add_theme_constant_override(&"v_separation", 10)
	scroll.add_child(_table)
	column.add_child(UiKit.button("Voltar", func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU)))
	_refresh()


func _pick(index: int) -> void:
	AudioBus.play_ui("page", -6.0)
	_element = index
	_refresh()


func _refresh() -> void:
	for child: Node in _table.get_children():
		child.queue_free()
	var element_id: StringName = MatchFsm.ELEMENTS[_element]
	var element: ElementDef = SpellDB.elements.get(element_id)
	_title.text = "%s — status: %s. Aperte a forma e depois o efeito." % [Glossary.element(element_id), Glossary.status(element.status_id) if element != null else ""]
	for header: String in ["Atalho", "Magia", "Efeito", "Conjuração"]:
		var cell: Label = UiKit.label(header, 18)
		cell.add_theme_color_override(&"font_color", UiKit.GOLD)
		_table.add_child(cell)
	for f: int in 3:
		for e: int in 3:
			var spell: ResolvedSpell = SpellDB.resolve(element_id, SpellDB.form_at(f), SpellDB.effect_at(e))
			if spell == null:
				continue
			_cell("%s + %s" % [CrosshairWheel.key_text(SLOT_ACTIONS[f]), CrosshairWheel.key_text(SLOT_ACTIONS[e])], 150)
			var name_cell: Label = _cell("%s\n%s · %s" % [spell.display_name, Glossary.form(spell.form), Glossary.effect(spell.effect)], 200)
			name_cell.add_theme_color_override(&"font_color", spell.color.lerp(Color.WHITE, 0.3))
			_cell(_effect_text(spell), 330)
			_cell("rápida (na tecla)" if spell.is_quick() else "confirmada (mira + LMB)", 170)


func _effect_text(spell: ResolvedSpell) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if spell.damage > 0.0:
		parts.append("dano %d" % roundi(spell.damage))
	parts.append("mana %d" % roundi(spell.mana_cost))
	parts.append("3 cargas" if spell.key == Player.ARROW_KEY else "recarga %.1f s" % spell.cooldown)
	if spell.status_id != &"" and bool(spell.param(&"applies_status", false)):
		parts.append("%s %.1f s" % [Glossary.status(spell.status_id), spell.status_duration])
	return " · ".join(parts)


func _cell(text: String, width: float) -> Label:
	var cell: Label = UiKit.label(text, 16)
	cell.custom_minimum_size = Vector2(width, 0)
	_table.add_child(cell)
	return cell
