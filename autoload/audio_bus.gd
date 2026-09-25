## Audio bus volumes and one-shot playback helpers. See docs/specs/06-ui-settings.md.
## Until real sound assets exist (spec 07 §4), spell sounds are synthesised in three layers
## (spec 01 §5): element timbre, form attack and effect tail. Results are cached per spell.
extends Node

signal spell_played(spell: ResolvedSpell, position: Vector3)

const MIX_RATE: int = 22050
const BUSES: Array[String] = ["Music", "SFX", "UI"]

var _cache: Dictionary[String, AudioStreamWAV] = {}


func _ready() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	Settings.load_settings()  # re-apply saved volumes now that the buses exist


## Plays the cast sound of a spell at a world position.
func play_spell(spell: ResolvedSpell, position: Vector3, parent: Node) -> void:
	spell_played.emit(spell, position)
	var key: String = "%s_%s" % [spell.element, spell.key]
	if not _cache.has(key):
		_cache[key] = _synth(spell.element, spell.form, spell.effect)
	_play_at(_cache[key], position, parent, 0.0)


## Low boom for explosions and Mark detonations.
func play_impact(element: StringName, position: Vector3, parent: Node) -> void:
	var key: String = "%s_impact" % element
	if not _cache.has(key):
		_cache[key] = _synth(element, &"area", &"burst", true)
	_play_at(_cache[key], position, parent, 2.0)


func _play_at(stream: AudioStreamWAV, position: Vector3, parent: Node, volume_db: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db
	player.unit_size = 6.0
	parent.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()


func _synth(element: StringName, form: StringName, effect: StringName, impact: bool = false) -> AudioStreamWAV:
	var length: float = {&"direct": 0.18, &"burst": 0.45, &"lingering": 0.7}.get(effect, 0.3)
	if impact:
		length = 0.6
	var attack: float = {&"projectile": 0.005, &"self": 0.08, &"area": 0.02}.get(form, 0.01)
	var base_freq: float = {&"fire": 180.0, &"frost": 880.0, &"storm": 330.0, &"wind": 440.0}.get(element, 300.0)
	if impact:
		base_freq *= 0.35
	var samples: int = int(length * MIX_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s%s%s%s" % [element, form, effect, impact])
	var phase: float = 0.0
	var noise_lp: float = 0.0
	for i: int in samples:
		var t: float = float(i) / MIX_RATE
		var env: float = minf(t / attack, 1.0) * pow(1.0 - t / length, 2.0 if effect != &"lingering" else 1.0)
		# Form: area drops in pitch like a thud, self rises, projectile is steady.
		var sweep: float = {&"projectile": 1.0, &"self": 1.0 + t * 1.5, &"area": maxf(1.0 - t * 1.2, 0.35)}.get(form, 1.0)
		phase += TAU * base_freq * sweep / MIX_RATE
		var white: float = rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, white, 0.15)
		var tone: float
		match element:
			&"fire":
				tone = 0.5 * noise_lp * 2.0 + 0.35 * (fmod(phase / TAU, 1.0) * 2.0 - 1.0)
			&"frost":
				tone = 0.6 * sin(phase) + 0.25 * sin(phase * 2.01) * sin(t * 40.0)
			&"storm":
				tone = 0.45 * signf(sin(phase)) + (0.5 * white if rng.randf() < 0.08 else 0.0)
			_:
				tone = 0.8 * lerpf(noise_lp, white, 0.3 + 0.3 * sin(t * 12.0))
		var sample: float = clampf(tone * env * 0.7, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
