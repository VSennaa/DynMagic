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


## Crosshair point dropped to the ground below it, clamped to max_range from the player (Mark).
func ground_target(max_range: float) -> Vector3:
	var aim: Vector3 = aim_point()
	var flat: Vector3 = aim - player.global_position
	flat.y = 0.0
	if flat.length() > max_range:
		aim = player.global_position + flat.normalized() * max_range + Vector3.UP * aim.y
	return _floor_below(aim, Vector3(aim.x, player.global_position.y, aim.z))


## First non-damageable surface below a point (rays pass through players and dummies).
func _floor_below(point: Vector3, fallback: Vector3) -> Vector3:
	var exclude: Array[RID] = [player.get_rid()]
	for attempt: int in 4:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point + Vector3.DOWN * 20.0)
		query.exclude = exclude
		var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			return fallback
		if SpellNode.find_damageable(result["collider"]) == null:
			return result["position"]
		exclude.append(result["rid"])
	return fallback


## Placement for Wall: `distance` ahead of the player on the floor, facing the aim direction.
func wall_transform(distance: float) -> Transform3D:
	var forward: Vector3 = -player.get_aim_camera().global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else -player.global_basis.z
	var center: Vector3 = player.global_position + forward * distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(center + Vector3.UP * 1.0, center + Vector3.DOWN * 20.0)
	query.exclude = [player.get_rid()]
	var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		center = result["position"]
	return Transform3D(Basis.looking_at(forward, Vector3.UP), center)


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
