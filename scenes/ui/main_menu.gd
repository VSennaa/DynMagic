extends Control
## Main menu (spec 06 §1): Jogar LAN, Treino, Grimório, Configurações, Sair,
## over Arena A seen from a slowly orbiting camera.

const ARENA: PackedScene = preload("res://scenes/arena/arena_a.tscn")

var _pivot: Node3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Net.close()
	MatchState.active = false
	_build_background()
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	column.position = Vector2(96, -220)
	column.custom_minimum_size = Vector2(420, 0)
	column.add_theme_constant_override(&"separation", 14)
	add_child(column)
	var heading: Label = UiKit.title("DynMagic", 72)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(heading)
	column.add_child(UiKit.label("Arena 1v1 de magia dinâmica", 20))
	column.add_child(UiKit.button("Jogar LAN", func() -> void: SceneRouter.go_to(SceneRouter.PLAY_LAN)))
	column.add_child(UiKit.button("Treino", func() -> void: SceneRouter.go_to(SceneRouter.TRAINING)))
	column.add_child(UiKit.button("Grimório", func() -> void: SceneRouter.go_to(SceneRouter.GRIMOIRE)))
	column.add_child(UiKit.button("Configurações", func() -> void: SceneRouter.go_to(SceneRouter.SETTINGS)))
	column.add_child(UiKit.button("Sair", func() -> void: get_tree().quit()))
	(column.get_child(2) as Button).grab_focus()


func _build_background() -> void:
	var viewport_container: SubViewportContainer = SubViewportContainer.new()
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)
	var viewport: SubViewport = SubViewport.new()
	viewport_container.add_child(viewport)
	viewport.add_child(ARENA.instantiate())
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0, 16, 26)
	camera.rotation_degrees = Vector3(-30, 0, 0)
	_pivot.add_child(camera)
	camera.current = true
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiKit.INK, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _process(delta: float) -> void:
	_pivot.rotate_y(delta * 0.08)
