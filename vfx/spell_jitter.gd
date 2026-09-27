class_name SpellJitter
extends Node3D
## Small orbiting jitter for the storm orb's lightning-arc quads (gauntlet spell-body pass):
## each arc drifts around the plasma core on its own phase so the arcs read as crackling
## and independent rather than static child meshes.

@export var radius: float = 0.2
@export var seed_offset: float = 0.0


func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0 + seed_offset
	position = Vector3(sin(t * 13.0) * radius, sin(t * 17.0 + 1.3) * radius * 0.7, cos(t * 11.0) * radius)
	look_at(global_position + Vector3(sin(t * 5.0), cos(t * 6.0) * 0.3, 1.0), Vector3.UP)
