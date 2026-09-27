extends Node
## Renders all 36 element x form x effect spell sounds (cast immediately followed by its own
## impact variant) to build/sounds/<element>_<form>_<effect>.wav so a human can listen to the
## redesigned spell audio (AudioBus._synth, spec 01 §5) outside of a match. Run headless:
##   Godot --headless --path D:\DynMagic res://tools/spell_sound_export.tscn

const ELEMENTS: Array[StringName] = [&"fire", &"frost", &"storm", &"wind"]
const FORMS: Array[StringName] = [&"projectile", &"self", &"area"]
const EFFECTS: Array[StringName] = [&"direct", &"burst", &"lingering"]
const GAP_SECONDS: float = 0.15
const OUT_DIR: String = "res://build/sounds"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var count: int = 0
	for element: StringName in ELEMENTS:
		for form: StringName in FORMS:
			for effect: StringName in EFFECTS:
				var cast: AudioStreamWAV = AudioBus._synth(element, form, effect, false)
				var impact: AudioStreamWAV = AudioBus._synth(element, form, effect, true)
				var combined: PackedByteArray = _concat(cast.data, impact.data)
				var filename: String = "%s_%s_%s.wav" % [element, form, effect]
				var path: String = "%s/%s" % [OUT_DIR, filename]
				_write_wav(path, combined, AudioBus.MIX_RATE)
				var peak_db: float = _peak_dbfs(combined)
				var seconds: float = combined.size() / 2.0 / AudioBus.MIX_RATE
				count += 1
				print("SOUND_OK %s len=%.2fs peak=%.1fdBFS" % [filename, seconds, peak_db])
	print("SPELL_SOUND_EXPORT: %d files" % count)
	get_tree().quit(0)


func _concat(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var gap: PackedByteArray = PackedByteArray()
	gap.resize(int(GAP_SECONDS * AudioBus.MIX_RATE) * 2)  # silence, already zero-filled
	var out: PackedByteArray = PackedByteArray()
	out.append_array(a)
	out.append_array(gap)
	out.append_array(b)
	return out


## Writes raw 16-bit mono PCM as a standard RIFF/WAVE file (AudioStreamWAV.data has no header).
func _write_wav(path: String, data: PackedByteArray, mix_rate: int) -> void:
	const CHANNELS: int = 1
	const BITS: int = 16
	var byte_rate: int = mix_rate * CHANNELS * BITS / 8
	var block_align: int = CHANNELS * BITS / 8
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("RIFF")
	file.store_32(36 + data.size())
	file.store_string("WAVE")
	file.store_string("fmt ")
	file.store_32(16)
	file.store_16(1)
	file.store_16(CHANNELS)
	file.store_32(mix_rate)
	file.store_32(byte_rate)
	file.store_16(block_align)
	file.store_16(BITS)
	file.store_string("data")
	file.store_32(data.size())
	file.store_buffer(data)
	file.close()


func _peak_dbfs(data: PackedByteArray) -> float:
	var peak: int = 0
	var samples: int = data.size() / 2
	for i: int in samples:
		peak = maxi(peak, absi(data.decode_s16(i * 2)))
	if peak == 0:
		return -100.0
	return linear_to_db(float(peak) / 32768.0)
