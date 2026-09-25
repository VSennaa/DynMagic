class_name SpellCaster
extends Node
## Spawns the scene of each cast spell at the player's cast origin, aimed at the crosshair.

const AIM_DISTANCE: float = 100.0

@export var player: Player


func _ready() -> void:
	if player == null:
		player = get_parent() as Player
	player.spell_cast.connect(_on_spell_cast)


## Point under the crosshair: first hit of a ray from the camera, or AIM_DISTANCE ahead.
func aim_point() -> Vector3:
	var camera: Camera3D = player.get_aim_camera()
	var from: Vector3 = camera.global_position
	var to: Vector3 = from - camera.global_basis.z * AIM_DISTANCE
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	return result["position"] if not result.is_empty() else to


func _on_spell_cast(spell: ResolvedSpell) -> void:
	if spell.scene == null:
		push_warning("SpellCaster: %s has no scene yet" % spell.key)
		return
	var node: SpellNode = spell.scene.instantiate() as SpellNode
	if node == null:
		push_error("SpellCaster: %s scene root must extend SpellNode" % spell.key)
		return
	var origin: Vector3 = player.cast_origin.global_position
	var target: Vector3 = aim_point()
	var direction: Vector3 = target - origin
	if direction.length_squared() < 0.0001:
		direction = -player.get_aim_camera().global_basis.z
	node.setup(spell, player, origin, direction, target)
	player.get_parent().add_child(node)
