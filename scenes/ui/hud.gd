class_name Hud
extends CanvasLayer
## Temporary M1 HUD: crosshair, composition trail, HP/shield/mana bars, 3×3 cooldown grid
## and active statuses. Final layout arrives in M6 (docs/specs/06-ui-settings.md section 2).

const SLOT_KEYS: Array[String] = ["Q", "E", "R"]
const FORM_NAMES: Dictionary = {&"projectile": "Projétil", &"self": "Pessoal", &"area": "Área"}
const EFFECT_NAMES: Dictionary = {&"direct": "Direto", &"burst": "Explosivo", &"lingering": "Persistente"}
const ELEMENT_NAMES: Dictionary = {&"fire": "Fogo", &"frost": "Gelo", &"storm": "Raio", &"wind": "Vento"}

var player: Player

var _trail: Label
var _hint: Label
var _hp_bar: ProgressBar
var _shield_bar: ProgressBar
var _mana_bar: ProgressBar
var _hp_label: Label
var _mana_label: Label
var _status_label: Label
var _cooldown_cells: Dictionary[StringName, Label] = {}


func _ready() -> void:
	_build()


func bind(p_player: Player) -> void:
	player = p_player


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var stats: Stats = player.stats
	_hp_bar.max_value = stats.max_hp
	_hp_bar.value = stats.hp
	_shield_bar.max_value = stats.max_hp
	_shield_bar.value = stats.shield
	_hp_label.text = "HP %d%s" % [roundi(stats.hp), "  +%d" % roundi(stats.shield) if stats.shield > 0.0 else ""]
	_mana_bar.max_value = stats.max_mana
	_mana_bar.value = stats.mana
	_mana_label.text = "MN %d" % roundi(stats.mana)
	_update_trail(player.composer)
	for key: StringName in _cooldown_cells:
		var left: float = stats.cooldown_left(key)
		var cell: Label = _cooldown_cells[key]
		cell.text = "%.1f" % left if left > 0.0 else "·"
		cell.modulate = Color(1, 1, 1, 0.45) if left > 0.0 else Color.WHITE
	var parts: PackedStringArray = PackedStringArray()
	for id: StringName in stats.active_statuses():
		parts.append("%s %.1fs" % [id, stats.status_time_left(id)])
	if player.invulnerable_time > 0.0:
		parts.append("invulnerável")
	if player.rune != &"":
		parts.append("runa: %s" % player.rune)
	if player.has_overcharge():
		parts.append("SOBRECARGA %d" % player.overcharge_casts)
	_status_label.text = "  ".join(parts)


func _update_trail(composer: SpellComposer) -> void:
	var element: String = ELEMENT_NAMES.get(composer.element_id, String(composer.element_id))
	var form: String = FORM_NAMES.get(composer.form, "_")
	match composer.state:
		SpellComposer.State.IDLE, SpellComposer.State.CASTING:
			_trail.text = "%s ▸ _ ▸ _" % element
			_hint.text = "Q Projétil · E Pessoal · R Área"
		SpellComposer.State.SLOT_EFFECT:
			_trail.text = "%s ▸ %s ▸ _" % [element, form]
			_hint.text = "Q Direto · E Explosivo · R Persistente"
		SpellComposer.State.AIMING:
			var effect: String = EFFECT_NAMES.get(composer.pending.effect, "?") if composer.pending != null else "?"
			_trail.text = "%s ▸ %s ▸ %s" % [element, form, effect]
			_hint.text = "LMB confirmar · RMB cancelar"


func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var crosshair: Label = _label("+", 28)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position -= Vector2(8, 20)
	root.add_child(crosshair)

	var trail_box: VBoxContainer = VBoxContainer.new()
	trail_box.set_anchors_preset(Control.PRESET_CENTER)
	trail_box.position = Vector2(-200, 40)
	trail_box.custom_minimum_size = Vector2(400, 0)
	root.add_child(trail_box)
	_trail = _label("", 22)
	_trail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trail_box.add_child(_trail)
	_hint = _label("", 16)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(1, 1, 1, 0.7)
	trail_box.add_child(_hint)

	var bars: VBoxContainer = VBoxContainer.new()
	bars.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bars.position = Vector2(32, -150)
	bars.custom_minimum_size = Vector2(320, 0)
	root.add_child(bars)
	_hp_label = _label("HP", 18)
	bars.add_child(_hp_label)
	_hp_bar = _bar(Color(0.85, 0.25, 0.25))
	bars.add_child(_hp_bar)
	_shield_bar = _bar(Color(0.95, 0.9, 0.5))
	_shield_bar.custom_minimum_size.y = 6
	bars.add_child(_shield_bar)
	_mana_label = _label("MN", 18)
	bars.add_child(_mana_label)
	_mana_bar = _bar(Color(0.3, 0.5, 0.95))
	bars.add_child(_mana_bar)
	_status_label = _label("", 16)
	bars.add_child(_status_label)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grid.position = Vector2(-340, -150)
	root.add_child(grid)
	grid.add_child(_label("", 14))
	for effect: StringName in [&"direct", &"burst", &"lingering"]:
		grid.add_child(_label(EFFECT_NAMES[effect], 14))
	for form: StringName in [&"projectile", &"self", &"area"]:
		grid.add_child(_label(FORM_NAMES[form], 14))
		for effect: StringName in [&"direct", &"burst", &"lingering"]:
			var cell: Label = _label("·", 18)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.custom_minimum_size = Vector2(70, 0)
			grid.add_child(cell)
			_cooldown_cells[SpellBase.make_key(form, effect)] = cell


func _label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _bar(color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(320, 14)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override(&"fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override(&"background", bg)
	return bar
