class_name Footsteps
extends Node
## Plays CC0 stone footsteps for a Player from its actual ground movement, so it works for
## the local player, host-simulated players and interpolated remote players alike.

const STEP_DISTANCE: float = 2.1
const MIN_SPEED: float = 1.2

var _body: Node3D
var _last: Vector3
var _travel: float = 0.0


func _ready() -> void:
	_body = get_parent() as Node3D
	_last = _body.global_position


func _physics_process(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var now: Vector3 = _body.global_position
	var step: Vector3 = now - _last
	_last = now
	var vertical: float = absf(step.y)
	step.y = 0.0
	var speed: float = step.length() / maxf(delta, 0.0001)
	# Airborne or teleporting (respawn, storm blink): no steps.
	if speed < MIN_SPEED or speed > 20.0 or vertical > 0.08:
		return
	_travel += step.length()
	if _travel >= STEP_DISTANCE:
		_travel = 0.0
		var local: bool = _body is Player and (_body as Player).is_local
		AudioBus.play_sample_at("footstep", now, _body.get_parent(), -10.0 if local else -4.0)
