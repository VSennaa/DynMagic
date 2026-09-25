class_name CooldownGrid
extends Control
## 3×3 spell cooldowns (spec 06 §2): effect symbols across the top, form symbols down the side.
## A ready cell glows in the element colour; a cell on cooldown darkens, a clock sweep empties
## as it recovers and the seconds left are printed on it.

const CELL: float = 42.0
const GAP: float = 5.0
const HEADER: float = 34.0

var player: Player

var _font: Font
## Longest remaining time seen per spell since it went on cooldown (the sweep's 100%).
var _totals: Dictionary[StringName, float] = {}


func _init() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(HEADER + 3.0 * (CELL + GAP), HEADER + 3.0 * (CELL + GAP))
	size = custom_minimum_size


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var element: ElementDef = SpellDB.elements.get(player.composer.element_id)
	var color: Color = element.color if element != null else Color.WHITE
	var cream: Color = Color(0.95, 0.91, 0.84, 0.9)
	for i: int in 3:
		var column_center: Vector2 = Vector2(HEADER + i * (CELL + GAP) + CELL * 0.5, HEADER * 0.45)
		SpellGlyph.draw(self, SpellGlyph.EFFECTS[i], column_center, 11.0, cream, 2.0)
		var row_center: Vector2 = Vector2(HEADER * 0.45, HEADER + i * (CELL + GAP) + CELL * 0.5)
		SpellGlyph.draw(self, SpellGlyph.FORMS[i], row_center, 11.0, cream, 2.0)
	for row: int in 3:
		for column: int in 3:
			var key: StringName = SpellBase.make_key(SpellGlyph.FORMS[row], SpellGlyph.EFFECTS[column])
			var rect: Rect2 = Rect2(Vector2(HEADER + column * (CELL + GAP), HEADER + row * (CELL + GAP)), Vector2(CELL, CELL))
			_draw_cell(rect, key, color)


func _draw_cell(rect: Rect2, key: StringName, color: Color) -> void:
	var left: float = player.stats.cooldown_left(key)
	if left <= 0.0:
		_totals.erase(key)
		draw_rect(rect, Color(color, 0.45))
		draw_rect(rect, color.lightened(0.35), false, 2.0)
		return
	var total: float = maxf(_totals.get(key, 0.0), left)
	_totals[key] = total
	draw_rect(rect, Color(0.05, 0.06, 0.09, 0.75))
	# Clock sweep: the dark wedge that remains shrinks clockwise from 12 o'clock.
	var center: Vector2 = rect.get_center()
	var fraction: float = clampf(left / total, 0.0, 1.0)
	var points: PackedVector2Array = PackedVector2Array([center])
	var steps: int = maxi(2, ceili(24.0 * fraction))
	for i: int in steps + 1:
		var angle: float = -PI / 2.0 + TAU * (1.0 - fraction) + TAU * fraction * i / steps
		points.append(center + Vector2.from_angle(angle) * CELL * 0.4)
	draw_colored_polygon(points, Color(color, 0.35))
	draw_rect(rect, Color(color, 0.5), false, 1.0)
	var text: String = "%.1f" % left if left < 10.0 else "%d" % ceili(left)
	var text_size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var baseline: Vector2 = center + Vector2(-text_size.x * 0.5, text_size.y * 0.3)
	draw_string_outline(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
