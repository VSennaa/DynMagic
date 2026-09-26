class_name LingeringProjectile
extends Projectile
## Seed: lobbed projectile (gravity) that plants a Zone where it lands.

const ZONE_SCENE: PackedScene = preload("res://scenes/spells/zone.tscn")


func _ready() -> void:
	var player: Player = caster as Player
	if spell.element == &"fire" and player != null and player.stats.has_status(&"seed_ready"):
		spell = spell.with_params({"strip": true, "zone_radius": 3.2})
		player.stats.clear_status(&"seed_ready")
	super._ready()


func _on_impact(point: Vector3, _normal: Vector3, _collider: Object) -> void:
	_plant(point)


func _on_expire() -> void:
	_plant(global_position)


func _plant(point: Vector3) -> void:
	var zone: Zone = ZONE_SCENE.instantiate() as Zone
	zone.setup(spell, caster, floor_below(point), direction, point)
	get_parent().add_child(zone)
	queue_free()
