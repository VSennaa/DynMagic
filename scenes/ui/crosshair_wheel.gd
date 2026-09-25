class_name CrosshairWheel
extends Control
## Composition wheel around the crosshair. D6: the three sectors form a Q-E-R arc
## (left to right) in keyboard order. Settings.wheel_labels picks what each sector shows:
## the SpellGlyph symbol of the option (meaning) or the bound key (shortcuts).
## Colour = element. Sectors dim while that spell is on cooldown; a ring marks
## confirmed (aim + LMB) spells and a dot marks quick ones. While aiming,
## the chosen letters sit in the centre and the ring pulses.

const RADIUS: float = 46.0
const BAND: float = 16.0
const SECTOR_SPAN: float = deg_to_rad(96.0)
## Sector centre angles (screen space, 0 = right, clockwise): Q upper-left, E top, R upper-right.
const ANGLES: Array[float] = [-PI * 0.75, -PI * 0.5, -PI * 0.25]
const SLOT_ACTIONS: Array[StringName] = [&"slot_1", &"slot_2", &"slot_3"]
const GLYPH_RADIUS: float = 10.5
const FORMS: Array[StringName] = [&"projectile", &"self", &"area"]
const EFFECTS: Array[StringName] = [&"direct", &"burst", &"lingering"]

var player: Player

var _font: Font
var _pulse: float = 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(RADIUS + BAND, RADIUS + BAND) * 2.4
	size = custom_minimum_size


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	# Crosshair dot.
	draw_circle(center, 2.5, Color(1, 1, 1, 0.9))
	if player == null or not is_instance_valid(player):
		return
	var composer: SpellComposer = player.composer
	var element: ElementDef = SpellDB.elements.get(composer.element_id)
	var color: Color = element.color if element != null else Color.WHITE
	match composer.state:
		SpellComposer.State.IDLE, SpellComposer.State.CASTING:
			# Resting: faint form options, so the screen stays clean.
			_draw_sectors(center, color, FORMS, 0.28, &"")
		SpellComposer.State.SLOT_EFFECT:
			_draw_sectors(center, color, EFFECTS, 0.95, composer.form)
			_draw_center(center, [composer.form], color)
		SpellComposer.State.AIMING:
			var spell: ResolvedSpell = composer.pending
			if spell != null:
				var pulse: float = 0.5 + 0.5 * sin(_pulse * 8.0)
				draw_arc(center, RADIUS, 0.0, TAU, 64, Color(color, 0.35 + 0.4 * pulse), 3.0, true)
				_draw_center(center, [spell.form, spell.effect], color)


func _draw_sectors(center: Vector2, color: Color, options: Array[StringName], alpha: float, form: StringName) -> void:
	for i: int in 3:
		var sector_alpha: float = alpha
		# Effect step: dim options whose spell (form + effect) is on cooldown.
		if form != &"":
			var key: StringName = SpellBase.make_key(form, EFFECTS[i])
			if player.stats.is_on_cooldown(key):
				sector_alpha *= 0.3
		var start: float = ANGLES[i] - SECTOR_SPAN * 0.5
		var end: float = ANGLES[i] + SECTOR_SPAN * 0.5
		draw_arc(center, RADIUS, start, end, 24, Color(color, sector_alpha * 0.55), BAND, true)
		draw_arc(center, RADIUS + BAND * 0.5, start, end, 24, Color(color.lightened(0.3), sector_alpha), 1.5, true)
		var pos: Vector2 = center + Vector2.from_angle(ANGLES[i]) * RADIUS
		_draw_option(pos, options[i], Color(1, 1, 1, clampf(sector_alpha + 0.1, 0.0, 1.0)), 1.0)
		# D6: quick spells get a dot, confirmed spells (aim + LMB) an outer ring.
		if form != &"":
			var spell: ResolvedSpell = SpellDB.resolve(player.composer.element_id, form, EFFECTS[i])
			var mark_pos: Vector2 = center + Vector2.from_angle(ANGLES[i]) * (RADIUS + BAND * 0.5 + 6.0)
			var mark_color: Color = Color(1, 1, 1, clampf(sector_alpha, 0.0, 1.0))
			if spell != null and not spell.is_quick():
				draw_arc(mark_pos, 3.5, 0.0, TAU, 12, mark_color, 1.5, true)
			else:
				draw_circle(mark_pos, 2.0, mark_color)


## Chosen options above the crosshair: symbols, or the keys that picked them.
func _draw_center(center: Vector2, chosen: Array[StringName], color: Color) -> void:
	var tint: Color = color.lightened(0.35)
	var step: float = GLYPH_RADIUS * 2.6
	var origin: Vector2 = center + Vector2(-step * (chosen.size() - 1) * 0.5, -24.0)
	for i: int in chosen.size():
		_draw_option(origin + Vector2(step * i, 0.0), chosen[i], tint, 0.9)


func _draw_option(pos: Vector2, id: StringName, color: Color, scale_factor: float) -> void:
	if Settings.wheel_labels == Settings.WheelLabels.KEYS:
		var index: int = maxi(FORMS.find(id), EFFECTS.find(id))
		_draw_letter(pos, key_text(SLOT_ACTIONS[index]), color, roundi(16 * scale_factor))
	else:
		SpellGlyph.draw(self, id, pos, GLYPH_RADIUS * scale_factor, color, 2.0)


## Short label of the first key bound to `action` ("Q", "Mouse 4"...).
static func key_text(action: StringName) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	return events[0].as_text().replace(" (Physical)", "") if not events.is_empty() else "?"


func _draw_letter(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var text_size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline: Vector2 = pos + Vector2(-text_size.x * 0.5, text_size.y * 0.3)
	draw_string_outline(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, color.a * 0.8))
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
