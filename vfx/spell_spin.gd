class_name SpellSpin
extends Node3D
## Constant self-rotation for spell-body containers (frost crystal, wind vortex ribbons)
## so a static low-poly mesh reads as an active magical effect (gauntlet spell-body pass).

@export var speed: Vector3 = Vector3(0.0, 3.0, 0.0)


func _process(delta: float) -> void:
	rotate_x(speed.x * delta)
	rotate_y(speed.y * delta)
	rotate_z(speed.z * delta)
