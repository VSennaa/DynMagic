class_name PlayerTuning
extends Resource
## Movement and body parameters for the first-person player.
## Values come from docs/specs/05-player-controller.md section 2.

@export_group("Body")
@export var capsule_radius: float = 0.35
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.2
## Camera height above the feet, as a fraction of the current capsule height.
@export var eye_height_ratio: float = 0.89

@export_group("Speed")
@export var walk_speed: float = 5.5
@export var sprint_speed: float = 7.5
@export var crouch_speed: float = 3.0
@export var ground_acceleration: float = 60.0
@export var air_acceleration: float = 15.0

@export_group("Jump")
@export var jump_height: float = 1.2
@export var gravity: float = 22.0
@export var coyote_time: float = 0.1

@export_group("Stairs")
@export var step_height: float = 0.35

@export_group("Crouch")
## Seconds to blend between standing and crouched heights.
@export var crouch_transition_time: float = 0.12


func jump_velocity() -> float:
	return sqrt(2.0 * gravity * jump_height)
