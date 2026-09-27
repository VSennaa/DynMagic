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
const PAINTING: String = "res://assets/ui/menu_backdrop.webp"
const TITLE_BANNER: String = "res://assets/ui/title_banner.png"
const CORNERS: Array[String] = ["tl", "tr", "bl", "br"]
const CORNER_SIZE: float = 56.0


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
	add_corners(panel)
	return column


## Rune ornaments on the four corners of a panel (Codex art pack).
static func add_corners(panel: PanelContainer) -> void:
	# A plain Control is not laid out by the container logic of its own children,
	# so the ornaments keep their size and sit on the frame corners.
	var decor: Control = Control.new()
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(decor)
	for key: String in CORNERS:
		var path: String = "res://assets/ui/rune_corner_%s.png" % key
		if not ResourceLoader.exists(path):
			continue
		var corner: TextureRect = TextureRect.new()
		corner.texture = load(path) as Texture2D
		corner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decor.add_child(corner)
		corner.size = Vector2.ONE * CORNER_SIZE
		var inset: float = -30.0  # reach past the panel content margin onto the frame
		var x: float = inset if key.ends_with("l") else -CORNER_SIZE - inset
		var y: float = inset if key.begins_with("t") else -CORNER_SIZE - inset
		corner.position = Vector2(x, y) + Vector2(0.0 if key.ends_with("l") else 1.0, 0.0 if key.begins_with("t") else 1.0) * decor.size
		decor.resized.connect(func() -> void:
			corner.position = Vector2(x, y) + Vector2(0.0 if key.ends_with("l") else 1.0, 0.0 if key.begins_with("t") else 1.0) * decor.size)


## Painted courtyard (Codex art pack) under a translucent ink layer with the turning arcane circle.
static func backdrop() -> Control:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var has_painting: bool = ResourceLoader.exists(PAINTING)
	if has_painting:
		var painting: TextureRect = TextureRect.new()
		painting.texture = load(PAINTING) as Texture2D
		painting.set_anchors_preset(Control.PRESET_FULL_RECT)
		painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(painting)
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = BACKDROP_SHADER
	mat.set_shader_parameter(&"base_alpha", 0.8 if has_painting else 1.0)
	bg.material = mat
	root.add_child(bg)
	return root


static func title(text: String, size: int = 56) -> Control:
	var heading: Label = Label.new()
	heading.text = text
	heading.theme_type_variation = &"TitleLabel"
	heading.add_theme_font_size_override(&"font_size", size)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if size < 56 or not ResourceLoader.exists(TITLE_BANNER):
		return heading
	# Large titles sit on the painted title banner (spec 07 §8: 1024x256, margins 128/64).
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(0, size * 2 + 24)
	var banner: NinePatchRect = NinePatchRect.new()
	banner.texture = load(TITLE_BANNER) as Texture2D
	banner.patch_margin_left = 128
	banner.patch_margin_top = 64
	banner.patch_margin_right = 128
	banner.patch_margin_bottom = 64
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(banner)
	heading.set_anchors_preset(Control.PRESET_FULL_RECT)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(heading)
	return holder


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
