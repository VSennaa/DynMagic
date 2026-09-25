extends Control
## Jogar LAN (spec 06 §1): host a lobby or join one found on the LAN / by IP.

const OVERTIME_OPTIONS: Array[StringName] = [&"random", &"collapse", &"sudden_death", &"mana_surge"]
const OVERTIME_LABELS: Array[String] = ["Aleatório", "Colapso", "Morte Súbita", "Maré de Mana"]
const ARENA_OPTIONS: Array[StringName] = [&"rotation", &"random", &"A", &"B", &"C"]
const ARENA_LABELS: Array[String] = ["Rotação", "Aleatória", "A Claustro", "B Pátio Partido", "C Espinha"]

var _name_edit: LineEdit
var _lobby_edit: LineEdit
var _overtime: OptionButton
var _arena: OptionButton
var _ip_edit: LineEdit
var _list: ItemList
var _status: Label
var _spectate: CheckBox


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var column: VBoxContainer = UiKit.screen(self)
	column.add_child(UiKit.title("Jogar LAN", 44))
	_name_edit = _line(Settings.player_name, "Seu nome")
	column.add_child(UiKit.row([UiKit.label("Nome", 20), _name_edit]))

	column.add_child(UiKit.header("Hospedar"))
	_lobby_edit = _line("", "Nome da sala")
	column.add_child(_lobby_edit)
	_overtime = _options(OVERTIME_LABELS)
	_arena = _options(ARENA_LABELS)
	column.add_child(UiKit.row([UiKit.label("Overtime", 18), _overtime, UiKit.label("Arena", 18), _arena]))
	column.add_child(UiKit.button("Criar sala", _host))

	column.add_child(UiKit.header("Entrar"))
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 140)
	_list.item_activated.connect(func(_i: int) -> void: _join_selected())
	column.add_child(_list)
	_ip_edit = _line("127.0.0.1", "IP do host")
	column.add_child(UiKit.row([_ip_edit, UiKit.button("Entrar por IP", _join_ip), UiKit.button("Entrar na selecionada", _join_selected)]))
	_spectate = CheckBox.new()
	_spectate.text = "Entrar como espectador"
	_spectate.add_theme_color_override(&"font_color", UiKit.CREAM)
	column.add_child(_spectate)
	_status = UiKit.label("", 18)
	column.add_child(_status)
	column.add_child(UiKit.button("Voltar", func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU)))

	Net.lobbies_changed.connect(_refresh_list)
	Net.connection_failed.connect(func(reason: String) -> void: _status.text = reason)
	Net.joined.connect(func() -> void: SceneRouter.go_to(SceneRouter.LOBBY))
	Net.start_discovery()


func _exit_tree() -> void:
	Net.stop_discovery()


func _host() -> void:
	Settings.player_name = _name_edit.text
	Settings.save_settings()
	if Net.host(Net.DEFAULT_PORT, _lobby_edit.text) == OK:
		Lobby.reset()
		Lobby.set_rules(OVERTIME_OPTIONS[_overtime.selected], ARENA_OPTIONS[_arena.selected])
		SceneRouter.go_to(SceneRouter.LOBBY)


func _join_ip() -> void:
	_join(_ip_edit.text.strip_edges(), Net.DEFAULT_PORT)


func _join_selected() -> void:
	var selected: PackedInt32Array = _list.get_selected_items()
	if selected.is_empty():
		_status.text = "Selecione uma sala."
		return
	var info: Dictionary = _list.get_item_metadata(selected[0])
	if not bool(info.get("compatible", false)):
		_status.text = "Versão diferente."
		return
	_join(str(info["ip"]), int(info.get("port", Net.DEFAULT_PORT)))


func _join(ip: String, port: int) -> void:
	Settings.player_name = _name_edit.text
	Settings.save_settings()
	_status.text = "Conectando a %s..." % ip
	Net.join(ip, port, _spectate.button_pressed)


func _refresh_list() -> void:
	_list.clear()
	for key: String in Net.lobbies:
		var info: Dictionary = Net.lobbies[key]
		var text: String = "%s — %s (%d/2)%s" % [info.get("name", "?"), key, int(info.get("players", 0)), "" if info.get("compatible", false) else "  [versão diferente]"]
		var index: int = _list.add_item(text)
		_list.set_item_metadata(index, info)
		_list.set_item_disabled(index, not bool(info.get("compatible", false)))


func _line(text: String, placeholder: String) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(240, 40)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return edit


func _options(labels: Array[String]) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	for text: String in labels:
		option.add_item(text)
	return option
