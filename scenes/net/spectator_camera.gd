class_name SpectatorCamera
extends Camera3D
## Spectator view (joined with "Entrar como espectador" / --spectate).
##   1 / 2      follow player 1 / 2 in third person (orbit with the mouse)
##   0          free camera: WASD fly, Space/Ctrl up/down, Shift faster
## Starts following the first player so the animated mage is visible right away.

const FREE_SPEED: float = 9.0
const FAST_MULT: float = 3.0
const FOLLOW_DISTANCE: float = 4.2
const FOLLOW_HEIGHT: float = 1.9
const SENSITIVITY: float = 0.0025

## Returns the players to follow, in join order (set by NetMatch).
var players_provider: Callable

var _target_index: int = 0
var _yaw: float = PI
var _pitch: float = -0.25


func _ready() -> void:
	current = true
	fov = Settings.fov
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	position = Vector3(0, 12, 26)


func _unhandled_input(event: InputEvent) -> void:
	if PauseMenu.is_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_yaw -= motion.relative.x * SENSITIVITY
		_pitch = clampf(_pitch - motion.relative.y * SENSITIVITY, -1.4, 1.2)
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_1: _target_index = 0
			KEY_2: _target_index = 1
			KEY_0: _target_index = -1


func _process(delta: float) -> void:
	var target: Node3D = _target()
	if target != null:
		# Third-person orbit around the followed player.
		var pivot: Vector3 = target.global_position + Vector3.UP * FOLLOW_HEIGHT
		var offset: Vector3 = Basis.from_euler(Vector3(_pitch, _yaw, 0.0)) * Vector3(0, 0, FOLLOW_DISTANCE)
		global_position = pivot + offset
		look_at(pivot, Vector3.UP)
		return
	rotation = Vector3(_pitch, _yaw, 0.0)
	if PauseMenu.is_open:
		return
	var input: Vector3 = Vector3(
		Input.get_axis(&"move_left", &"move_right"),
		(1.0 if Input.is_action_pressed(&"jump") else 0.0) - (1.0 if Input.is_action_pressed(&"crouch") else 0.0),
		Input.get_axis(&"move_forward", &"move_back"))
	var speed: float = FREE_SPEED * (FAST_MULT if Input.is_action_pressed(&"sprint") else 1.0)
	global_position += (global_basis * Vector3(input.x, 0.0, input.z) + Vector3.UP * input.y) * speed * delta


func _target() -> Node3D:
	if _target_index < 0 or not players_provider.is_valid():
		return null
	var list: Array = players_provider.call()
	return list[_target_index] as Node3D if _target_index < list.size() else null


## Short label for the HUD.
func mode_text() -> String:
	var target: Node3D = _target()
	if target == null:
		return "ESPECTADOR — câmera livre  ·  1/2 seguir jogador"
	return "ESPECTADOR — seguindo %s  ·  1/2 trocar · 0 câmera livre" % Net.players.get(int(String(target.name)), target.name)
