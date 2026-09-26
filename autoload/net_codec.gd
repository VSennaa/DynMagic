@tool
class_name NetCodec
extends RefCounted
## Binary packing for the unreliable streams (docs/specs/04-networking.md sections 5 and 7).
## InputFrame ≈ 22 B, player snapshot entry ≈ 57 B.

enum InputButton { JUMP = 1, CROUCH = 2, SPRINT = 4 }


## {seq:int, move:Vector2, yaw:float, pitch:float, buttons:int, composer:int}
static func pack_inputs(frames: Array[Dictionary]) -> PackedByteArray:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.put_u8(frames.size())
	for frame: Dictionary in frames:
		buf.put_u32(int(frame["seq"]))
		var move: Vector2 = frame["move"]
		buf.put_8(_quantize(move.x))
		buf.put_8(_quantize(move.y))
		buf.put_float(float(frame["yaw"]))
		buf.put_float(float(frame["pitch"]))
		buf.put_u8(int(frame["buttons"]))
		buf.put_u8(int(frame["composer"]))
	return buf.data_array


static func unpack_inputs(data: PackedByteArray) -> Array[Dictionary]:
	if data.is_empty() or data[0] < 1 or data[0] > 3 or data.size() != 1 + int(data[0]) * 16:
		return []
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.data_array = data
	var frames: Array[Dictionary] = []
	var count: int = buf.get_u8()
	for i: int in count:
		frames.append({
			"seq": buf.get_u32(),
			"move": Vector2(_dequantize(buf.get_8()), _dequantize(buf.get_8())),
			"yaw": buf.get_float(),
			"pitch": buf.get_float(),
			"buttons": buf.get_u8(),
			"composer": buf.get_u8(),
		})
	for frame: Dictionary in frames:
		if not is_finite(float(frame["yaw"])) or not is_finite(float(frame["pitch"])) or int(frame["buttons"]) > 7:
			return []
	return frames


## {tick:int, players: Array of {id, ack, pos, vel, yaw, pitch, hp, mana, shield, statuses, composer}}
static func pack_snapshot(snapshot: Dictionary) -> PackedByteArray:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.put_u32(int(snapshot["tick"]))
	var entries: Array = snapshot["players"]
	buf.put_u8(entries.size())
	for entry: Dictionary in entries:
		buf.put_32(int(entry["id"]))
		buf.put_u32(int(entry["ack"]))
		_put_vec3(buf, entry["pos"])
		_put_vec3(buf, entry["vel"])
		buf.put_float(float(entry["yaw"]))
		buf.put_float(float(entry["pitch"]))
		buf.put_half(float(entry["hp"]))
		buf.put_half(float(entry["mana"]))
		buf.put_half(float(entry["shield"]))
		buf.put_u8(int(entry["statuses"]))
		buf.put_u8(int(entry["composer"]))
		_put_gameplay(buf, entry.get("gameplay", {}))
	return buf.data_array


static func unpack_snapshot(data: PackedByteArray) -> Dictionary:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.data_array = data
	var tick: int = buf.get_u32()
	var entries: Array[Dictionary] = []
	var count: int = buf.get_u8()
	for i: int in count:
		entries.append({
			"id": buf.get_32(),
			"ack": buf.get_u32(),
			"pos": _get_vec3(buf),
			"vel": _get_vec3(buf),
			"yaw": buf.get_float(),
			"pitch": buf.get_float(),
			"hp": buf.get_half(),
			"mana": buf.get_half(),
			"shield": buf.get_half(),
			"statuses": buf.get_u8(),
			"composer": buf.get_u8(),
			"gameplay": _get_gameplay(buf),
		})
	return {"tick": tick, "players": entries}


## Status ids <-> bit flags for the snapshot.
const STATUS_BITS: Dictionary = {&"burn": 1, &"slow": 2, &"shock": 4, &"aura": 8}


static func status_mask(statuses: Array) -> int:
	var mask: int = 0
	for id: Variant in statuses:
		mask |= int(STATUS_BITS.get(StringName(id), 0))
	return mask


## Composer state (2 bits) + form index + 1 (2 bits) + effect index + 1 (2 bits): lets
## the opponent draw the rune circle (spec 04 §4).
static func pack_composer(state: int, form_index: int, effect_index: int) -> int:
	return (state & 3) | (((form_index + 1) & 3) << 2) | (((effect_index + 1) & 3) << 4)


static func unpack_composer(value: int) -> Vector3i:
	return Vector3i(value & 3, ((value >> 2) & 3) - 1, ((value >> 4) & 3) - 1)


static func _quantize(v: float) -> int:
	return clampi(roundi(v * 127.0), -127, 127)


static func _dequantize(v: int) -> float:
	return float(v) / 127.0


static func _put_vec3(buf: StreamPeerBuffer, v: Vector3) -> void:
	buf.put_float(v.x)
	buf.put_float(v.y)
	buf.put_float(v.z)


static func _get_vec3(buf: StreamPeerBuffer) -> Vector3:
	return Vector3(buf.get_float(), buf.get_float(), buf.get_float())


# --- Gameplay state (M11: compact replacement for the put_var blob) -------------------
# Stats + ReconnectState runtime fields in a fixed schema: floats as halves, bools as bits,
# spells and statuses as small indices. Keeps a 2-player snapshot well under the ENet MTU.

enum Field { FLOAT, INT, BOOL, VEC3 }
## Must list exactly ReconnectState.PLAYER_FIELDS (tests/test_net_serialization.gd checks it).
const GAMEPLAY_FIELDS: Array = [
	[&"overcharge_time", Field.FLOAT], [&"overcharge_casts", Field.INT], [&"invulnerable_time", Field.FLOAT],
	[&"glide_time", Field.FLOAT], [&"sudden_death", Field.BOOL], [&"mana_surge", Field.BOOL],
	[&"_dash_velocity", Field.VEC3], [&"_dash_time", Field.FLOAT], [&"_knockback", Field.VEC3],
	[&"_burn_dps", Field.FLOAT], [&"_burn_tick", Field.FLOAT], [&"_slow_strength", Field.FLOAT],
	[&"_air_jumps_used", Field.INT], [&"_arrow_charges", Field.INT], [&"_arrow_recharge", Field.FLOAT],
	[&"_arrow_interval", Field.FLOAT], [&"_melee_cooldown", Field.FLOAT],
]
const STATUS_IDS: Array[StringName] = [&"burn", &"slow", &"shock", &"knockback", &"aura"]
const SPELL_ELEMENTS: Array[StringName] = [&"fire", &"frost", &"storm", &"wind"]
const SPELL_FORMS: Array[StringName] = [&"projectile", &"self", &"area"]
const SPELL_EFFECTS: Array[StringName] = [&"direct", &"burst", &"lingering"]
const STAT_FLOATS: Array[String] = ["hp", "max_hp", "mana", "max_mana", "shield", "shield_time_left", "regen_pause"]


static func _put_gameplay(buf: StreamPeerBuffer, gameplay: Dictionary) -> void:
	if gameplay.is_empty():
		buf.put_u8(0)
		return
	buf.put_u8(1)
	var stats: Dictionary = gameplay["stats"]
	for key: String in STAT_FLOATS:
		buf.put_half(float(stats[key]))
	buf.put_u8(1 if bool(stats["is_dead"]) else 0)
	var statuses: Dictionary = stats["statuses"]
	var known: Array = statuses.keys().filter(func(id: Variant) -> bool: return STATUS_IDS.has(StringName(id)))
	buf.put_u8(known.size())
	for id: Variant in known:
		buf.put_u8(STATUS_IDS.find(StringName(id)))
		buf.put_half(float(statuses[id]))
	var cooldowns: Dictionary = stats["cooldowns"]
	buf.put_u8(cooldowns.size())
	for key: Variant in cooldowns:
		var parts: PackedStringArray = String(key).split("_")
		buf.put_u8(SPELL_FORMS.find(StringName(parts[0])) * 3 + SPELL_EFFECTS.find(StringName(parts[1])))
		buf.put_half(float(cooldowns[key]))
	var runtime: Dictionary = gameplay["runtime"]
	var bits: int = 0
	for i: int in GAMEPLAY_FIELDS.size():
		var field: Array = GAMEPLAY_FIELDS[i]
		var value: Variant = runtime[field[0]]
		match int(field[1]):
			Field.FLOAT:
				buf.put_half(float(value))
			Field.INT:
				buf.put_u8(clampi(int(value), 0, 255))
			Field.VEC3:
				var v: Vector3 = value
				buf.put_half(v.x)
				buf.put_half(v.y)
				buf.put_half(v.z)
			Field.BOOL:
				bits |= (1 << i) if bool(value) else 0
	buf.put_u32(bits)
	for key: String in ["active_aura", "active_guard", "last_spell"]:
		_put_spell(buf, runtime[key])


static func _get_gameplay(buf: StreamPeerBuffer) -> Dictionary:
	if buf.get_u8() == 0:
		return {}
	var stats: Dictionary = {}
	for key: String in STAT_FLOATS:
		stats[key] = buf.get_half()
	stats["is_dead"] = buf.get_u8() == 1
	var statuses: Dictionary[StringName, float] = {}
	for i: int in buf.get_u8():
		var status_id: StringName = STATUS_IDS[buf.get_u8()]
		statuses[status_id] = buf.get_half()
	stats["statuses"] = statuses
	var cooldowns: Dictionary[StringName, float] = {}
	for i: int in buf.get_u8():
		var index: int = buf.get_u8()
		var spell_key: StringName = StringName("%s_%s" % [SPELL_FORMS[index / 3], SPELL_EFFECTS[index % 3]])
		cooldowns[spell_key] = buf.get_half()
	stats["cooldowns"] = cooldowns
	var runtime: Dictionary = {}
	var bool_fields: Array[int] = []
	for i: int in GAMEPLAY_FIELDS.size():
		var field: Array = GAMEPLAY_FIELDS[i]
		match int(field[1]):
			Field.FLOAT:
				runtime[field[0]] = buf.get_half()
			Field.INT:
				runtime[field[0]] = buf.get_u8()
			Field.VEC3:
				runtime[field[0]] = Vector3(buf.get_half(), buf.get_half(), buf.get_half())
			Field.BOOL:
				bool_fields.append(i)
	var bits: int = buf.get_u32()
	for i: int in bool_fields:
		runtime[GAMEPLAY_FIELDS[i][0]] = bits & (1 << i) != 0
	for key: String in ["active_aura", "active_guard", "last_spell"]:
		runtime[StringName(key)] = _get_spell(buf)
	return {"stats": stats, "runtime": runtime}


## [element, form, effect] or [] as three bytes (255 = none).
static func _put_spell(buf: StreamPeerBuffer, ids: Array) -> void:
	if ids.size() != 3:
		buf.put_u8(255)
		return
	buf.put_u8(SPELL_ELEMENTS.find(StringName(ids[0])))
	buf.put_u8(SPELL_FORMS.find(StringName(ids[1])))
	buf.put_u8(SPELL_EFFECTS.find(StringName(ids[2])))


static func _get_spell(buf: StreamPeerBuffer) -> Array:
	var element: int = buf.get_u8()
	if element == 255:
		return []
	return [SPELL_ELEMENTS[element], SPELL_FORMS[buf.get_u8()], SPELL_EFFECTS[buf.get_u8()]]
