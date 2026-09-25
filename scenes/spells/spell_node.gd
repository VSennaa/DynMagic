class_name SpellNode
extends Node3D
## Base for every spawned spell. SpellCaster calls setup() before adding it to the tree.

var spell: ResolvedSpell
var caster: Node3D
## Normalized aim direction from the cast origin.
var direction: Vector3 = Vector3.FORWARD
## Point under the crosshair (for area spells and previews).
var target_point: Vector3 = Vector3.ZERO


func setup(p_spell: ResolvedSpell, p_caster: Node3D, origin: Vector3, p_direction: Vector3, p_target: Vector3) -> void:
	spell = p_spell
	caster = p_caster
	direction = p_direction.normalized()
	target_point = p_target
	position = origin


## Deals this spell's damage (scaled) to a target in the "damageable" group.
func hit(target: Node, damage_scale: float = 1.0) -> void:
	if target == null or target == caster or not target.is_in_group(&"damageable"):
		return
	hit_amount(target, spell.damage * damage_scale)


## Deals a fixed amount (zones, damage over time) instead of the spell's base damage.
func hit_amount(target: Node, amount: float) -> void:
	if target == null or target == caster or not target.is_in_group(&"damageable"):
		return
	if caster != null and caster.has_method(&"damage_mult"):
		amount *= float(caster.call(&"damage_mult"))
	target.call(&"receive_hit", amount, spell, caster)


## Damageable nodes whose colliders overlap a sphere. The caster is filtered later by hit().
func overlap_damageables(center: Vector3, radius: float) -> Array[Node]:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	var found: Array[Node] = []
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var target: Node = find_damageable(result["collider"])
		if target != null and not found.has(target):
			found.append(target)
	return found


## Walks up from a collider to the node that owns receive_hit (colliders can be children).
static func find_damageable(collider: Object) -> Node:
	var node: Node = collider as Node
	while node != null:
		if node.is_in_group(&"damageable"):
			return node
		node = node.get_parent()
	return null


## First non-damageable surface below a point: zones and marks land on the floor, never on a body.
func floor_below(point: Vector3) -> Vector3:
	var exclude: Array[RID] = []
	var body: CollisionObject3D = caster as CollisionObject3D
	if body != null:
		exclude.append(body.get_rid())
	for _attempt: int in 4:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point + Vector3.DOWN * 20.0)
		query.exclude = exclude
		var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			return point
		if find_damageable(result["collider"]) == null:
			return result["position"]
		exclude.append(result["rid"])
	return point
