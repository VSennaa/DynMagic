class_name PauseMenu
extends CanvasLayer
## Esc menu shared by training and the networked match (spec 06 §1).
## Online the match keeps running; the menu only frees the mouse and blocks casting.

signal closed

## True while any pause menu is open (Player uses it to avoid recapturing the mouse).
static var is_open: bool = false

## Extra entry shown above "Sair" (e.g. "Desistir" in the match). Empty = hidden.
var leave_text: String = "Sair para o menu"
## Called when the player confirms leaving. Defaults to going back to the main menu.
var on_leave: Callable

var _panel: PanelContainer
var _column: VBoxContainer
var _confirming: bool = false


func _ready() -> void:
	layer = 50
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible:
		return
	_build()
	visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not visible:
		return
	visible = false
	is_open = false
	_confirming = false
	if _panel != null:
		_panel.queue_free()
		_panel = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _exit_tree() -> void:
	is_open = false


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(420, 0)
	_panel.position = Vector2(-210, -170)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 12)
	_panel.add_child(_column)
	_column.add_child(UiKit.title("Pausa", 40))
	var resume: Button = UiKit.button("Voltar ao jogo", close)
	_column.add_child(resume)
	_column.add_child(UiKit.button("Configurações", _open_settings))
	_column.add_child(UiKit.button(leave_text, _ask_leave))
	add_child(_panel)
	resume.grab_focus()


func _ask_leave() -> void:
	if _confirming:
		return
	_confirming = true
	_column.add_child(UiKit.label("Tem certeza?", 18))
	_column.add_child(UiKit.button("Sim, " + leave_text.to_lower(), _leave))


func _leave() -> void:
	is_open = false
	if on_leave.is_valid():
		on_leave.call()
	else:
		Net.close()
		SceneRouter.go_to(SceneRouter.MAIN_MENU)


## Settings as an overlay: the settings screen closes itself instead of leaving the match.
func _open_settings() -> void:
	var settings: Control = (load(SceneRouter.SETTINGS) as PackedScene).instantiate() as Control
	settings.set_meta(&"overlay", true)
	_panel.visible = false
	add_child(settings)
	settings.tree_exited.connect(func() -> void:
		if _panel != null:
			_panel.visible = true)
