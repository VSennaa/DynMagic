class_name CrosshairWheel
extends Control
## Composition wheel around the crosshair. Three sectors follow the key layout:
## Q on top, E bottom-left, R bottom-right. Letters are the option initials:
##   form step  : P Projétil · S Pessoal (self) · A Área
##   effect step: D Direto · X Explosivo · P Persistente
## Colour = element. Sectors dim while that spell is on cooldown. While aiming,
## the chosen letters sit in the centre and the ring pulses.

const RADIUS: float = 46.0
const BAND: float = 16.0
const SECTOR_SPAN: float = deg_to_rad(96.0)
## Sector centre angles (screen space, 0 = right, clockwise): Q top, E bottom-left, R bottom-right.
const ANGLES: Array[float] = [-PI / 2.0, PI * 5.0 / 6.0, PI / 6.0]
const FORM_LETTERS: Array[String] = ["P", "S", "A"]
const EFFECT_LETTERS: Array[String] = ["D", "X", "P"]
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
			_draw_sectors(center, color, FORM_LETTERS, 0.28, -1, &"")
		SpellComposer.State.SLOT_EFFECT:
			var form_index: int = FORMS.find(composer.form)
			_draw_sectors(center, color, EFFECT_LETTERS, 0.95, -1, composer.form)
			_draw_center_text(center, FORM_LETTERS[form_index] if form_index >= 0 else "", color)
		SpellComposer.State.AIMING:
			var spell: ResolvedSpell = composer.pending
			if spell != null:
				var pulse: float = 0.5 + 0.5 * sin(_pulse * 8.0)
				draw_arc(center, RADIUS, 0.0, TAU, 64, Color(color, 0.35 + 0.4 * pulse), 3.0, true)
				_draw_center_text(center, "%s·%s" % [FORM_LETTERS[FORMS.find(spell.form)], EFFECT_LETTERS[EFFECTS.find(spell.effect)]], color)


func _draw_sectors(center: Vector2, color: Color, letters: Array[String], alpha: float, _highlight: int, form: StringName) -> void:
	for i: int in 3:
		var sector_alpha: float = alpha
		# Effect step: dim options whose spell (form + effect) is on cooldown or unaffordable.
		if form != &"":
			var key: StringName = SpellBase.make_key(form, EFFECTS[i])
			if player.stats.is_on_cooldown(key):
				sector_alpha *= 0.3
		var start: float = ANGLES[i] - SECTOR_SPAN * 0.5
		var end: float = ANGLES[i] + SECTOR_SPAN * 0.5
		draw_arc(center, RADIUS, start, end, 24, Color(color, sector_alpha * 0.55), BAND, true)
		draw_arc(center, RADIUS + BAND * 0.5, start, end, 24, Color(color.lightened(0.3), sector_alpha), 1.5, true)
		var letter_pos: Vector2 = center + Vector2.from_angle(ANGLES[i]) * RADIUS
		_draw_letter(letter_pos, letters[i], Color(1, 1, 1, clampf(sector_alpha + 0.1, 0.0, 1.0)), 16)


func _draw_center_text(center: Vector2, text: String, color: Color) -> void:
	_draw_letter(center + Vector2(0, -22), text, color.lightened(0.35), 15)


func _draw_letter(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var text_size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline: Vector2 = pos + Vector2(-text_size.x * 0.5, text_size.y * 0.3)
	draw_string_outline(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, color.a * 0.8))
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
