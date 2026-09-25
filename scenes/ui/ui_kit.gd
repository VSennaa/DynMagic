class_name UiKit
extends RefCounted
## Small builders for code-made menus in the DynMagic style (spec 06 §4):
## ink blue-black panels, cream text, element-coloured accents.

const INK: Color = Color("#11161F")
const CREAM: Color = Color("#F2E8D5")
const ACCENT: Color = Color("#C98BFF")


static func screen(root: Control) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(520, 0)
	column.add_theme_constant_override(&"separation", 14)
	center.add_child(column)
	return column


static func title(text: String, size: int = 56) -> Label:
	var heading: Label = label(text, size)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return heading


static func label(text: String, size: int = 20) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, on_pressed: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override(&"font_size", 22)
	var normal: StyleBoxFlat = _box(Color(CREAM, 0.08), Color(CREAM, 0.35))
	var hover: StyleBoxFlat = _box(Color(ACCENT, 0.25), ACCENT)
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", hover)
	b.add_theme_stylebox_override(&"focus", hover)
	b.add_theme_stylebox_override(&"pressed", _box(Color(ACCENT, 0.45), ACCENT))
	b.add_theme_color_override(&"font_color", CREAM)
	b.pressed.connect(func() -> void: AudioBus.play_ui("click"))
	b.mouse_entered.connect(func() -> void: AudioBus.play_ui("hover", -16.0))
	b.pressed.connect(on_pressed)
	return b


static func row(children: Array[Control]) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 12)
	for child: Control in children:
		# Word wrap inside a row collapses labels to one letter per line.
		if child is Label:
			(child as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
			child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(child)
	return h


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.content_margin_left = 16
	box.content_margin_right = 16
	return box
