extends SceneTree
## Builds res://ui/dynmagic_theme.tres, the project-wide UI theme (spec 06 §4: grimoire look —
## ink panels, gold trim, cream text, Cinzel titles, Alegreya Sans body).
## Run: godot --headless --path . --script res://tools/build_ui_theme.gd
## If textures exist in res://assets/ui/ (Codex art pack), they replace the flat styleboxes.

const INK: Color = Color("#11161F")
const INK_2: Color = Color("#1B2233")
const INK_3: Color = Color("#2A2240")
const CREAM: Color = Color("#F2E8D5")
const GOLD: Color = Color("#E8C170")
const GOLD_DIM: Color = Color("#8A7148")
const VIOLET: Color = Color("#C98BFF")


func _initialize() -> void:
	var theme: Theme = build()
	var err: Error = ResourceSaver.save(theme, "res://ui/dynmagic_theme.tres")
	print("theme saved: %s" % error_string(err))
	quit()


static func build() -> Theme:
	var theme: Theme = Theme.new()
	var body: FontFile = load("res://ui/fonts/AlegreyaSans-Regular.ttf") as FontFile
	var bold: FontFile = load("res://ui/fonts/AlegreyaSans-Bold.ttf") as FontFile
	var title: FontFile = load("res://ui/fonts/Cinzel.ttf") as FontFile
	theme.default_font = body
	theme.default_font_size = 20

	# Labels
	theme.set_color(&"font_color", &"Label", CREAM)
	theme.set_color(&"font_outline_color", &"Label", Color(0, 0, 0, 0.85))
	theme.set_constant(&"outline_size", &"Label", 4)
	# Title variation: Cinzel, gold, used by UiKit.title().
	theme.add_type(&"TitleLabel")
	theme.set_type_variation(&"TitleLabel", &"Label")
	theme.set_font(&"font", &"TitleLabel", title)
	theme.set_font_size(&"font_size", &"TitleLabel", 56)
	theme.set_color(&"font_color", &"TitleLabel", GOLD)
	theme.set_color(&"font_outline_color", &"TitleLabel", Color(0.05, 0.03, 0.08))
	theme.set_constant(&"outline_size", &"TitleLabel", 10)
	theme.set_color(&"font_shadow_color", &"TitleLabel", Color(0.6, 0.35, 0.9, 0.45))
	theme.set_constant(&"shadow_offset_y", &"TitleLabel", 3)
	# Section headers ("— Vídeo —").
	theme.add_type(&"HeaderLabel")
	theme.set_type_variation(&"HeaderLabel", &"Label")
	theme.set_font(&"font", &"HeaderLabel", title)
	theme.set_font_size(&"font_size", &"HeaderLabel", 22)
	theme.set_color(&"font_color", &"HeaderLabel", GOLD)

	# Buttons
	var textured: bool = ResourceLoader.exists("res://assets/ui/button_normal.png")
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(StringName(state), &"Button", _button_box(state, textured))
	theme.set_font(&"font", &"Button", bold)
	theme.set_font_size(&"font_size", &"Button", 22)
	theme.set_color(&"font_color", &"Button", CREAM)
	theme.set_color(&"font_hover_color", &"Button", GOLD)
	theme.set_color(&"font_pressed_color", &"Button", Color.WHITE)
	theme.set_color(&"font_focus_color", &"Button", GOLD)
	theme.set_color(&"font_disabled_color", &"Button", Color(CREAM, 0.35))
	theme.set_color(&"font_outline_color", &"Button", Color(0, 0, 0, 0.8))
	theme.set_constant(&"outline_size", &"Button", 3)

	# OptionButton / CheckBox reuse button colours.
	for type: StringName in [&"OptionButton", &"MenuButton"]:
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			theme.set_stylebox(StringName(state), type, _button_box(state, false, 14))
		theme.set_color(&"font_color", type, CREAM)
		theme.set_color(&"font_hover_color", type, GOLD)
		theme.set_font_size(&"font_size", type, 18)
	theme.set_color(&"font_color", &"CheckBox", CREAM)
	theme.set_color(&"font_hover_color", &"CheckBox", GOLD)
	theme.set_color(&"font_pressed_color", &"CheckBox", CREAM)
	theme.set_icon(&"unchecked", &"CheckBox", _check_icon(false))
	theme.set_icon(&"checked", &"CheckBox", _check_icon(true))
	theme.set_icon(&"unchecked_disabled", &"CheckBox", _check_icon(false))
	theme.set_icon(&"checked_disabled", &"CheckBox", _check_icon(true))
	theme.set_constant(&"h_separation", &"CheckBox", 10)
	theme.set_stylebox(&"normal", &"CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox(&"hover", &"CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox(&"pressed", &"CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox(&"focus", &"CheckBox", StyleBoxEmpty.new())

	# Panels
	var panel: StyleBox = _panel_box(textured)
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	theme.set_stylebox(&"panel", &"Panel", panel)
	var popup: StyleBoxFlat = _flat(INK_2, GOLD_DIM, 1, 4)
	theme.set_stylebox(&"panel", &"PopupMenu", popup)
	theme.set_color(&"font_color", &"PopupMenu", CREAM)
	theme.set_color(&"font_hover_color", &"PopupMenu", GOLD)
	theme.set_stylebox(&"hover", &"PopupMenu", _flat(INK_3, VIOLET, 0, 2))

	# Text fields and lists
	var field: StyleBoxFlat = _flat(Color(INK, 0.85), GOLD_DIM, 1, 4)
	field.content_margin_left = 10
	field.content_margin_right = 10
	theme.set_stylebox(&"normal", &"LineEdit", field)
	var field_focus: StyleBoxFlat = field.duplicate()
	field_focus.border_color = GOLD
	theme.set_stylebox(&"focus", &"LineEdit", field_focus)
	theme.set_color(&"font_color", &"LineEdit", CREAM)
	theme.set_color(&"font_placeholder_color", &"LineEdit", Color(CREAM, 0.4))
	theme.set_color(&"caret_color", &"LineEdit", GOLD)
	theme.set_stylebox(&"panel", &"ItemList", field)
	theme.set_color(&"font_color", &"ItemList", CREAM)
	theme.set_color(&"font_selected_color", &"ItemList", GOLD)
	theme.set_stylebox(&"selected", &"ItemList", _flat(INK_3, GOLD, 1, 2))
	theme.set_stylebox(&"selected_focus", &"ItemList", _flat(INK_3, GOLD, 1, 2))
	theme.set_stylebox(&"hovered", &"ItemList", _flat(Color(INK_3, 0.6), Color(0, 0, 0, 0), 0, 2))

	# Sliders, progress bars, scroll bars
	theme.set_stylebox(&"slider", &"HSlider", _flat(Color(INK, 0.9), GOLD_DIM, 1, 3, 6))
	theme.set_stylebox(&"grabber_area", &"HSlider", _flat(GOLD_DIM, Color(0, 0, 0, 0), 0, 3, 6))
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", _flat(GOLD, Color(0, 0, 0, 0), 0, 3, 6))
	theme.set_stylebox(&"background", &"ProgressBar", _flat(Color(0, 0, 0, 0.5), GOLD_DIM, 1, 3))
	theme.set_stylebox(&"fill", &"ProgressBar", _flat(VIOLET, Color(0, 0, 0, 0), 0, 3))
	theme.set_stylebox(&"scroll", &"VScrollBar", _flat(Color(INK, 0.6), Color(0, 0, 0, 0), 0, 3))
	theme.set_stylebox(&"grabber", &"VScrollBar", _flat(GOLD_DIM, Color(0, 0, 0, 0), 0, 3))
	theme.set_stylebox(&"grabber_highlight", &"VScrollBar", _flat(GOLD, Color(0, 0, 0, 0), 0, 3))
	theme.set_stylebox(&"grabber_pressed", &"VScrollBar", _flat(GOLD, Color(0, 0, 0, 0), 0, 3))
	return theme


static func _button_box(state: String, textured: bool, margin: int = 22) -> StyleBox:
	if textured:
		var file: String = "res://assets/ui/button_%s.png" % ("hover" if state == "focus" else state)
		if ResourceLoader.exists(file):
			var tex: StyleBoxTexture = StyleBoxTexture.new()
			# The art is 512x128 with 48/24 margins (spec 07 §6); drawn at half size so the
			# gold frame stays thin on 48 px buttons.
			var image: Image = (load(file) as Texture2D).get_image()
			image.resize(256, 64, Image.INTERPOLATE_LANCZOS)
			tex.texture = ImageTexture.create_from_image(image)
			tex.set_texture_margin(SIDE_LEFT, 24)
			tex.set_texture_margin(SIDE_RIGHT, 24)
			tex.set_texture_margin(SIDE_TOP, 12)
			tex.set_texture_margin(SIDE_BOTTOM, 12)
			tex.content_margin_left = margin + 12
			tex.content_margin_right = margin + 12
			tex.content_margin_top = 8
			tex.content_margin_bottom = 8
			return tex
	var fill: Color = INK_2
	var border: Color = GOLD_DIM
	match state:
		"hover", "focus":
			fill = INK_3
			border = GOLD
		"pressed":
			fill = Color("#3A2A55")
			border = VIOLET
		"disabled":
			fill = Color(INK_2, 0.5)
			border = Color(GOLD_DIM, 0.4)
	var box: StyleBoxFlat = _flat(fill, border, 2, 5)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	if state == "hover" or state == "focus":
		box.shadow_color = Color(VIOLET, 0.35)
		box.shadow_size = 6
	return box


## Gold-framed square; checked adds a violet rune dot. Drawn here so no extra art file is needed.
static func _check_icon(checked: bool) -> ImageTexture:
	const SIZE: int = 22
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(INK, 0.9))
	for i: int in SIZE:
		for w: int in 2:
			image.set_pixel(i, w, GOLD)
			image.set_pixel(i, SIZE - 1 - w, GOLD)
			image.set_pixel(w, i, GOLD)
			image.set_pixel(SIZE - 1 - w, i, GOLD)
	if checked:
		var c: Vector2 = Vector2(SIZE, SIZE) * 0.5
		for y: int in SIZE:
			for x: int in SIZE:
				if Vector2(x + 0.5, y + 0.5).distance_to(c) <= 5.5:
					image.set_pixel(x, y, VIOLET.lightened(0.2))
	return ImageTexture.create_from_image(image)


static func _panel_box(textured: bool) -> StyleBox:
	# The light parchment art is kept for future light pages; menus keep dark ink panels so the
	# cream text stays readable.
	if false and textured and ResourceLoader.exists("res://assets/ui/parchment_panel.png"):
		var tex: StyleBoxTexture = StyleBoxTexture.new()
		tex.texture = load("res://assets/ui/parchment_panel.png") as Texture2D
		for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			tex.set_texture_margin(side, 32)
			tex.set_content_margin(side, 30)
		return tex
	var box: StyleBoxFlat = _flat(Color(INK, 0.94), GOLD_DIM, 2, 8)
	box.set_content_margin_all(28)
	box.shadow_color = Color(0, 0, 0, 0.6)
	box.shadow_size = 12
	return box


static func _flat(fill: Color, border: Color, border_width: int, radius: int, height: int = 0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	if height > 0:
		box.content_margin_top = height * 0.5
		box.content_margin_bottom = height * 0.5
	return box
