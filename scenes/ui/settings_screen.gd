extends Control
## Configurações (spec 06 §3): video, audio, controls with rebinding, game. Saved on "Salvar".

const ACTION_LABELS: Dictionary = {
	&"move_forward": "Frente", &"move_back": "Trás", &"move_left": "Esquerda", &"move_right": "Direita",
	&"jump": "Pular", &"crouch": "Agachar", &"sprint": "Correr",
	&"slot_1": "Slot 1 (Q)", &"slot_2": "Slot 2 (E)", &"slot_3": "Slot 3 (R)", &"compose_cancel": "Cancelar",
	&"cast": "Conjurar", &"recast": "Repetir / cancelar mira", &"melee": "Golpe de cajado", &"precast": "Pré-conjurar", &"scoreboard": "Placar", &"net_overlay": "Overlay de rede",
}
const FPS_OPTIONS: Array[int] = [60, 120, 144, 240, 0]

## Last tab the player had open, remembered for the session (spec: reopen where they left off).
static var _last_tab: int = 0

var _waiting_action: StringName = &""
var _binding_buttons: Dictionary[StringName, Button] = {}
var _status: Label


## Builds a tab's content column, adding it to `tabs` under `title`. Wraps it in a
## ScrollContainer when the section has too many rows to fit 1280x720 flat (Controles).
func _tab(tabs: TabContainer, title: String, scrolling: bool = false) -> VBoxContainer:
	var body: VBoxContainer = VBoxContainer.new()
	body.name = title
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 10)
	if scrolling:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.name = title
		scroll.custom_minimum_size = Vector2(640, 420)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.name = "%s_body" % title
		body.custom_minimum_size.x = 620
		scroll.add_child(body)
		tabs.add_child(scroll)
	else:
		body.custom_minimum_size = Vector2(640, 420)
		tabs.add_child(body)
	return body


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var column: VBoxContainer = UiKit.screen(self)
	column.add_child(UiKit.title("Configurações", 40))
	var tabs: TabContainer = TabContainer.new()
	tabs.custom_minimum_size = Vector2(640, 440)
	column.add_child(tabs)

	var body: VBoxContainer = _tab(tabs, "Vídeo")
	body.add_child(_check("Tela cheia", Settings.fullscreen, func(v: bool) -> void: Settings.fullscreen = v))
	var resolutions: PackedStringArray = []
	for size: Vector2i in VideoSettings.RESOLUTIONS:
		resolutions.append("%d × %d" % [size.x, size.y])
	body.add_child(_option("Resolução", resolutions, VideoSettings.RESOLUTIONS.find(Settings.video.resolution), func(i: int) -> void: Settings.set_video(&"resolution", VideoSettings.RESOLUTIONS[i])))
	var scale_value: Label = UiKit.label("%d%%" % roundi(Settings.video.render_scale * 100.0), 18)
	scale_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	scale_value.custom_minimum_size.x = 56.0
	var scale_row: HBoxContainer = _slider("Escala de render", 50.0, 100.0, 5.0, Settings.video.render_scale * 100.0, func(v: float) -> void:
		Settings.set_video(&"render_scale", v / 100.0)
		scale_value.text = "%d%%" % roundi(v))
	scale_row.add_child(scale_value)
	body.add_child(scale_row)
	body.add_child(_option("Sombras", ["Baixa", "Média", "Alta"], Settings.video.shadow_quality, func(i: int) -> void: Settings.set_video(&"shadow_quality", i)))
	body.add_child(_option("Antialiasing", ["Off", "FXAA", "MSAA 2×", "MSAA 4×"], Settings.video.antialiasing, func(i: int) -> void: Settings.set_video(&"antialiasing", i)))
	body.add_child(_check("VSync", Settings.vsync, func(v: bool) -> void: Settings.vsync = v))
	body.add_child(_slider("FOV", 80.0, 110.0, 1.0, Settings.fov, func(v: float) -> void: Settings.fov = v))
	body.add_child(_slider("FOV das mãos", 54.0, 68.0, 1.0, Settings.viewmodel_fov, func(v: float) -> void: Settings.viewmodel_fov = v))
	var fps: OptionButton = OptionButton.new()
	for value: int in FPS_OPTIONS:
		fps.add_item("sem limite" if value == 0 else str(value))
	fps.selected = maxi(FPS_OPTIONS.find(Settings.max_fps), 0)
	fps.item_selected.connect(func(i: int) -> void: Settings.max_fps = FPS_OPTIONS[i])
	body.add_child(UiKit.row([UiKit.label("Limite de FPS", 18), fps]))

	body = _tab(tabs, "Áudio")
	for bus: String in Settings.volumes:
		body.add_child(_slider(bus, 0.0, 1.0, 0.05, Settings.volumes[bus], func(v: float) -> void: Settings.set_volume(bus, v)))

	body = _tab(tabs, "Controles", true)
	body.add_child(_slider("Sensibilidade", 0.0005, 0.008, 0.0001, Settings.mouse_sensitivity, func(v: float) -> void: Settings.mouse_sensitivity = v))
	body.add_child(_check("Inverter Y", Settings.invert_y, func(v: bool) -> void: Settings.invert_y = v))
	body.add_child(_check("Modo canhoto (cajado na mão esquerda)", Settings.left_handed, func(v: bool) -> void: Settings.left_handed = v))
	for action: StringName in Settings.REMAPPABLE:
		var button: Button = UiKit.button(_event_text(action), _start_rebind.bind(action))
		button.custom_minimum_size = Vector2(220, 36)
		_binding_buttons[action] = button
		body.add_child(UiKit.row([UiKit.label(ACTION_LABELS.get(action, String(action)), 18), button]))
	body.add_child(UiKit.button("Restaurar teclas padrão", func() -> void:
		Settings.restore_default_bindings()
		_refresh_bindings()))

	body = _tab(tabs, "Jogo")
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = Settings.player_name
	name_edit.text_changed.connect(func(t: String) -> void: Settings.player_name = t)
	name_edit.custom_minimum_size = Vector2(260, 36)
	body.add_child(UiKit.row([UiKit.label("Nome", 18), name_edit]))
	body.add_child(_check("Números de dano", Settings.show_damage_numbers, func(v: bool) -> void: Settings.show_damage_numbers = v))
	body.add_child(_check("Tremor de câmera ao levar dano", Settings.screen_shake, func(v: bool) -> void: Settings.screen_shake = v))
	var wheel: OptionButton = OptionButton.new()
	for text: String in ["Significado (símbolos)", "Atalhos (teclas)"]:
		wheel.add_item(text)
	wheel.selected = Settings.wheel_labels
	wheel.item_selected.connect(func(i: int) -> void: Settings.wheel_labels = i as Settings.WheelLabels)
	body.add_child(UiKit.row([UiKit.label("Roda de magias", 18), wheel]))
	body.add_child(_check("Mostrar FPS", Settings.show_fps, func(v: bool) -> void: Settings.show_fps = v))

	body = _tab(tabs, "Acessibilidade")
	var palette: OptionButton = OptionButton.new()
	for text: String in ["Padrão", "Deuteranopia", "Protanopia", "Tritanopia"]:
		palette.add_item(text)
	palette.selected = Settings.colorblind_mode
	body.add_child(_check("Legendas de sons de magia", Settings.sound_captions, func(v: bool) -> void: Settings.sound_captions = v))
	palette.item_selected.connect(func(i: int) -> void: Settings.colorblind_mode = i)
	body.add_child(UiKit.row([UiKit.label("Paleta de cores", 18), palette]))

	tabs.current_tab = clampi(_last_tab, 0, tabs.get_tab_count() - 1)
	tabs.tab_changed.connect(func(i: int) -> void: _last_tab = i)

	_status = UiKit.label("", 18)
	column.add_child(_status)
	column.add_child(UiKit.row([
		UiKit.button("Salvar", func() -> void:
			Settings.save_settings()
			_status.text = "Salvo."),
		UiKit.button("Voltar", func() -> void:
			Settings.save_settings()
			# Opened from the pause menu: just close the overlay.
			if has_meta(&"overlay"):
				queue_free()
			else:
				SceneRouter.go_to(SceneRouter.MAIN_MENU)),
	]))


func _input(event: InputEvent) -> void:
	if _waiting_action == &"":
		return
	var usable: bool = (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if not usable:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		_waiting_action = &""
		_refresh_bindings()
		return
	var conflict: StringName = Settings.rebind(_waiting_action, event)
	if conflict != &"":
		# Swap: the other action loses this key; tell the player to rebind it.
		InputMap.action_erase_events(conflict)
		_status.text = "\"%s\" ficou sem tecla (conflito). Defina outra." % ACTION_LABELS.get(conflict, String(conflict))
	_waiting_action = &""
	_refresh_bindings()


func _start_rebind(action: StringName) -> void:
	_waiting_action = action
	_binding_buttons[action].text = "pressione uma tecla... (Esc cancela)"


func _refresh_bindings() -> void:
	for action: StringName in _binding_buttons:
		_binding_buttons[action].text = _event_text(action)


func _event_text(action: StringName) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	return events[0].as_text().replace(" (Physical)", "") if not events.is_empty() else "—"


func _check(text: String, value: bool, on_toggle: Callable) -> CheckBox:
	var box: CheckBox = CheckBox.new()
	box.text = text
	box.button_pressed = value
	box.add_theme_color_override(&"font_color", UiKit.CREAM)
	box.toggled.connect(on_toggle)
	return box


func _option(text: String, items: PackedStringArray, selected: int, on_select: Callable) -> HBoxContainer:
	var option: OptionButton = OptionButton.new()
	for item: String in items:
		option.add_item(item)
	option.selected = selected
	option.item_selected.connect(on_select)
	return UiKit.row([UiKit.label(text, 18), option])


func _slider(text: String, min_value: float, max_value: float, step: float, value: float, on_change: Callable) -> HBoxContainer:
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(280, 24)
	slider.value_changed.connect(on_change)
	return UiKit.row([UiKit.label(text, 18), slider])
