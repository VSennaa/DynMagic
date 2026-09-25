class_name UiKit
extends RefCounted
## Small builders for code-made menus. Visual style lives in the project theme
## (res://ui/dynmagic_theme.tres, built by tools/build_ui_theme.gd): ink panels, gold trim,
## cream text, Cinzel titles. These helpers only add layout, the backdrop and sounds.

const INK: Color = Color("#11161F")
const CREAM: Color = Color("#F2E8D5")
const GOLD: Color = Color("#E8C170")
const ACCENT: Color = Color("#C98BFF")
const BACKDROP_SHADER: Shader = preload("res://ui/menu_backdrop.gdshader")


## Full-screen menu: animated grimoire backdrop + a framed panel in the centre.
## Returns the column to fill.
static func screen(root: Control, min_width: float = 560.0) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop())
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(min_width, 0)
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	return column


static func backdrop() -> ColorRect:
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = BACKDROP_SHADER
	bg.material = mat
	return bg


static func title(text: String, size: int = 56) -> Label:
	var heading: Label = Label.new()
	heading.text = text
	heading.theme_type_variation = &"TitleLabel"
	heading.add_theme_font_size_override(&"font_size", size)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return heading


## Section header in the title font, framed by small rune marks.
static func header(text: String) -> Label:
	var label_node: Label = Label.new()
	label_node.text = "◆  %s  ◆" % text
	label_node.theme_type_variation = &"HeaderLabel"
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label_node


static func label(text: String, size: int = 20) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, on_pressed: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
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
