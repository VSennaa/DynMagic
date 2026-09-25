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
