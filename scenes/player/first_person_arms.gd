extends Node
## Camera-local viewmodel composited over the world, below the HUD.
## An isolated World3D has no arena depth, so walls cannot clip the arms.
const ARMS_LAYER: int = 1 << 19
const CAST_FLASH: float = 0.12
## Resting placement tuned like CS2/TF2 viewmodels: own FOV (default 60, range 54-68),
## hands low in the bottom corners, roughly the lower quarter of the screen.
const REST_OFFSET: Vector3 = Vector3(0.0, -0.085, -0.16)
const ARMS_SCALE: float = 0.72
var player: Player
var source_camera: Camera3D
var view: SubViewport
var camera: Camera3D
var arms: Node3D
var overlay: CanvasLayer
var _flash: float = 0.0
var _time: float = 0.0


func setup(owner_player: Player, owner_camera: Camera3D) -> void:
	player = owner_player
	source_camera = owner_camera
	overlay = CanvasLayer.new()
	overlay.layer = -1
	add_child(overlay)
	var container: SubViewportContainer = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(container)
	view = SubViewport.new()
	view.name = "ArmsViewport"
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.handle_input_locally = false
	container.add_child(view)
	camera = Camera3D.new()
	camera.cull_mask = ARMS_LAYER
	camera.near = 0.01
	camera.far = 3.0
	camera.current = true
	view.add_child(camera)
	arms = preload("res://scenes/assets/fp_arms.tscn").instantiate() as Node3D
	camera.add_child(arms)
	for node: Node in arms.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		mesh.layers = ARMS_LAYER
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.light_cull_mask = ARMS_LAYER
	light.rotation_degrees = Vector3(-35, -30, 0)
	view.add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.65, .7, .85)
	environment.environment.ambient_light_energy = .4
	view.add_child(environment)
	player.spell_cast.connect(_on_cast)
	player.stats.died.connect(_on_died)
	_process(0.0)


func _on_cast(_spell: ResolvedSpell) -> void:
	_flash = CAST_FLASH


func _on_died() -> void:
	_flash = 0.0


func _process(delta: float) -> void:
	if arms == null:
		return
	_time += delta
	_flash = maxf(0.0, _flash - delta)
	camera.fov = Settings.viewmodel_fov
	camera.keep_aspect = source_camera.keep_aspect
	view.msaa_3d = player.get_viewport().msaa_3d
	overlay.visible = player.is_local and source_camera.current and not player.stats.is_dead and player.stats.hp > 0.0
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if overlay.visible else SubViewport.UPDATE_DISABLED
	var pose: String = "OpenPalm"
	if _flash > 0.0:
		pose = "Cast"
	elif player.composer.state in [SpellComposer.State.SLOT_EFFECT, SpellComposer.State.AIMING]:
		match player.composer.form:
			&"self": pose = "Fist"
			&"area": pose = "PalmDown"
			_: pose = "OpenPalm"
	arms.set("pose", pose)
	var aim: float = 1.0 if player.composer.state == SpellComposer.State.AIMING else 0.0
	var recoil: float = sin((_flash / CAST_FLASH) * PI) if _flash > 0.0 else 0.0
	arms.scale = Vector3.ONE * ARMS_SCALE
	arms.position = REST_OFFSET + Vector3(0.0, aim * .035 + sin(_time * 2.0) * .004, -aim * .045 - recoil * .08)
	arms.rotation.x = -aim * .05 - recoil * .08
