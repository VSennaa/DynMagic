class_name SpellGlyph
extends RefCounted
## Vector symbols for spell forms and effects, drawn with CanvasItem primitives so they stay
## crisp at any size. Shared by the crosshair wheel and the cooldown grid.
##   forms  : projectile = arrow · self = figure · area = ground ring
##   effects: direct = diamond (one hit) · burst = star · lingering = dotted ring (keeps going)

const FORMS: Array[StringName] = [&"projectile", &"self", &"area"]
const EFFECTS: Array[StringName] = [&"direct", &"burst", &"lingering"]
const NAMES: Dictionary[StringName, String] = {
	&"projectile": "Projétil", &"self": "Pessoal", &"area": "Área",
	&"direct": "Direto", &"burst": "Explosivo", &"lingering": "Contínuo",
}


## Draws `id` centred on `center` with a dark outline for legibility over the world.
static func draw(canvas: CanvasItem, id: StringName, center: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	_draw_shape(canvas, id, center, radius, Color(0, 0, 0, color.a * 0.75), width + 2.5)
	_draw_shape(canvas, id, center, radius, color, width)


static func _draw_shape(canvas: CanvasItem, id: StringName, c: Vector2, r: float, color: Color, w: float) -> void:
	match id:
		&"projectile":
			var tip: Vector2 = c + Vector2(r, -r) * 0.72
			var tail: Vector2 = c + Vector2(-r, r) * 0.72
			canvas.draw_line(tail, tip, color, w, true)
			canvas.draw_line(tip, tip + Vector2(-r * 0.62, 0.0), color, w, true)
			canvas.draw_line(tip, tip + Vector2(0.0, r * 0.62), color, w, true)
		&"self":
			canvas.draw_circle(c + Vector2(0.0, -r * 0.42), r * 0.3, color)
			canvas.draw_arc(c + Vector2(0.0, r * 0.62), r * 0.62, PI, TAU, 16, color, w, true)
		&"area":
			_ellipse(canvas, c + Vector2(0.0, r * 0.2), Vector2(r, r * 0.45), color, w)
			_ellipse(canvas, c + Vector2(0.0, r * 0.2), Vector2(r * 0.42, r * 0.19), color, w)
		&"direct":
			var points: PackedVector2Array = PackedVector2Array([
				c + Vector2(0, -r * 0.8), c + Vector2(r * 0.55, 0), c + Vector2(0, r * 0.8), c + Vector2(-r * 0.55, 0), c + Vector2(0, -r * 0.8)])
			canvas.draw_polyline(points, color, w, true)
			canvas.draw_circle(c, r * 0.18, color)
		&"burst":
			for i: int in 8:
				var dir: Vector2 = Vector2.from_angle(TAU * i / 8.0 - PI / 2.0)
				var outer: float = r if i % 2 == 0 else r * 0.7
				canvas.draw_line(c + dir * r * 0.34, c + dir * outer, color, w, true)
			canvas.draw_circle(c, r * 0.16, color)
		&"lingering":
			for i: int in 8:
				canvas.draw_circle(c + Vector2.from_angle(TAU * i / 8.0) * r * 0.8, maxf(w * 0.75, r * 0.13), color)
			canvas.draw_circle(c, r * 0.16, color)


static func _ellipse(canvas: CanvasItem, c: Vector2, radii: Vector2, color: Color, w: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 25:
		var a: float = TAU * i / 24.0
		points.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	canvas.draw_polyline(points, color, w, true)
