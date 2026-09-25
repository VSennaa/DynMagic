class_name ReconnectState
extends RefCounted
## Host-only capture and authority-RPC restore of surviving world objects.

const PLAYER_FIELDS: Array[StringName] = [&"overcharge_time", &"overcharge_casts", &"invulnerable_time", &"glide_time", &"sudden_death", &"mana_surge", &"_dash_velocity", &"_dash_time", &"_knockback", &"_burn_dps", &"_burn_tick", &"_slow_strength", &"_air_jumps_used", &"_arrow_charges", &"_arrow_recharge"]

static func player_state(player: Player) -> Dictionary:
	var state: Dictionary = fields(player, PLAYER_FIELDS)
	for key: StringName in [&"active_aura", &"active_guard"]:
		var spell: ResolvedSpell = player.get(key)
		state[key] = [spell.element, spell.form, spell.effect] if spell != null else []
	var last: ResolvedSpell = player.composer.last_spell
	state["last_spell"] = [last.element, last.form, last.effect] if last != null else []
	return state


static func restore_player(player: Player, state: Dictionary) -> void:
	for key: StringName in PLAYER_FIELDS:
		player.set(key, state[key])
	for key: StringName in [&"active_aura", &"active_guard"]:
		var ids: Array = state[key]
		player.set(key, SpellDB.resolve(ids[0], ids[1], ids[2]) if ids.size() == 3 else null)
	var last: Array = state["last_spell"]
	player.composer.last_spell = SpellDB.resolve(last[0], last[1], last[2]) if last.size() == 3 else null


static func fields(object: Object, keys: Array[StringName]) -> Dictionary:
	var state: Dictionary = {}
	for key: StringName in keys:
		state[key] = object.get(key)
	return state


static func capture_world(arena: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child: Node in arena.get_children():
		if child.is_queued_for_deletion() or not (child is SpellNode or child is Wall):
			continue
		var spell: ResolvedSpell = child.get("spell")
		var caster: Node3D = child.get("caster")
		if not is_instance_valid(caster):
			continue
		var runtime: Dictionary = {}
		if child is Projectile:
			runtime = fields(child, [&"velocity", &"_travelled", &"_age", &"_homing_left"])
		elif child is Zone:
			runtime = fields(child, [&"_age", &"_tick_timer"])
		elif child is Wall:
			runtime = fields(child, [&"hp", &"_life", &"_contact_timer"])
		elif child is SelfSpell:
			runtime = fields(child, [&"_life"])
		elif child is AreaSpell:
			runtime = fields(child, [&"_timer"])
		out.append({"scene": child.scene_file_path, "caster": int(String(caster.name)),
			"spell": [spell.element, spell.form, spell.effect], "params": spell.params,
			"transform": (child as Node3D).transform, "runtime": runtime,
			"direction": child.get("direction") if child is SpellNode else Vector3.FORWARD,
			"target": child.get("target_point") if child is SpellNode else Vector3.ZERO})
	return out


static func restore_world(arena: Node, state: Array[Dictionary]) -> void:
	for entry: Dictionary in state:
		var caster: Player = arena.call(&"get_player", int(entry["caster"])) as Player
		var ids: Array = entry["spell"]
		var spell: ResolvedSpell = SpellDB.resolve(ids[0], ids[1], ids[2]).with_params(entry["params"])
		var packed: PackedScene = load(entry["scene"]) as PackedScene
		var node: Node3D = packed.instantiate() as Node3D
		if node is SelfSpell:
			(node as SelfSpell).restoring = true
		node.call(&"setup", spell, caster, (entry["transform"] as Transform3D).origin, entry["direction"], entry["target"])
		arena.add_child(node)
		node.transform = entry["transform"]
		var runtime: Dictionary = entry["runtime"]
		for key: Variant in runtime:
			node.set(key, runtime[key])
