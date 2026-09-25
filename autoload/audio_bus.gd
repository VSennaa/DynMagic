## Audio bus volumes and one-shot playback helpers. See docs/specs/06-ui-settings.md.
## Mixed sources (user decision 2026-09-25): CC0 samples (Kenney, audio/cc0/) for UI, footsteps,
## hits and foley; spells are synthesised in three layers (spec 01 §5): element timbre, form
## attack and effect tail, cached per spell and played with small pitch variation.
extends Node

signal spell_played(spell: ResolvedSpell, position: Vector3)

const MIX_RATE: int = 22050
const BUSES: Array[String] = ["Music", "SFX", "UI"]

var _cache: Dictionary[String, AudioStreamWAV] = {}
## Sample groups: name -> list of streams (a random one plays each time).
var _samples: Dictionary[String, Array] = {}
var _music: AudioStreamPlayer

const SAMPLE_GROUPS: Dictionary = {
	"click": ["ui/click_002.ogg"],
	"hover": ["ui/select_001.ogg"],
	"confirm": ["ui/confirmation_001.ogg"],
	"back": ["ui/back_001.ogg"],
	"error": ["ui/error_001.ogg"],
	"toggle": ["ui/toggle_001.ogg"],
	"open": ["ui/open_001.ogg"],
	"footstep": ["footsteps/footstep_concrete_000.ogg", "footsteps/footstep_concrete_001.ogg", "footsteps/footstep_concrete_002.ogg", "footsteps/footstep_concrete_003.ogg", "footsteps/footstep_concrete_004.ogg"],
	"hit": ["impacts/impactPunch_medium_000.ogg", "impacts/impactPunch_medium_001.ogg", "impacts/impactPunch_medium_002.ogg"],
	"thud": ["impacts/impactSoft_heavy_000.ogg", "impacts/impactSoft_heavy_001.ogg", "impacts/impactSoft_heavy_002.ogg"],
	"shatter": ["impacts/impactGlass_light_000.ogg", "impacts/impactGlass_light_001.ogg"],
	"stone": ["impacts/impactMining_000.ogg", "impacts/impactMining_001.ogg"],
	"bell": ["impacts/impactBell_heavy_000.ogg"],
	"cloth": ["foley/cloth1.ogg", "foley/cloth2.ogg", "foley/cloth3.ogg"],
	"page": ["foley/bookFlip1.ogg", "foley/bookFlip2.ogg"],
	"book": ["foley/bookOpen.ogg"],
}


func _ready() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	_add_sfx_reverb()
	Settings.load_settings()  # re-apply saved volumes now that the buses exist
	for group: String in SAMPLE_GROUPS:
		var streams: Array = []
		for path: String in SAMPLE_GROUPS[group]:
			var stream: AudioStream = load("res://audio/cc0/" + path) as AudioStream
			if stream != null:
				streams.append(stream)
		_samples[group] = streams
	if DisplayServer.get_name() != "headless":
		_start_music()


## Plays the cast sound of a spell at a world position.
func play_spell(spell: ResolvedSpell, position: Vector3, parent: Node) -> void:
	spell_played.emit(spell, position)
	if Net.dedicated:
		return  # C15: no audio synthesis on the dedicated server.
	var key: String = "%s_%s" % [spell.element, spell.key]
	if not _cache.has(key):
		_cache[key] = _synth(spell.element, spell.form, spell.effect)
	_play_at(_cache[key], position, parent, 0.0)


## Low boom for explosions and Mark detonations.
func play_impact(element: StringName, position: Vector3, parent: Node) -> void:
	if Net.dedicated:
		return
	var key: String = "%s_impact" % element
	if not _cache.has(key):
		_cache[key] = _synth(element, &"area", &"burst", true)
	_play_at(_cache[key], position, parent, 2.0)
	play_sample_at("thud", position, parent, 0.0)


func _play_at(stream: AudioStream, position: Vector3, parent: Node, volume_db: float) -> void:
	if Net.dedicated or parent == null or not parent.is_inside_tree():
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db
	player.unit_size = 6.0
	player.pitch_scale = randf_range(0.93, 1.07)
	parent.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()


## 2D sample on the UI bus (menus, own hits, round events).
func play_ui(group: String, volume_db: float = -4.0) -> void:
	if Net.dedicated:
		return
	var stream: AudioStream = _pick(group)
	if stream == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"UI"
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.96, 1.04)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Positional sample on the SFX bus (footsteps, impacts, foley).
func play_sample_at(group: String, position: Vector3, parent: Node, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _pick(group)
	if stream != null:
		_play_at(stream, position, parent, volume_db)


func _pick(group: String) -> AudioStream:
	var streams: Array = _samples.get(group, [])
	return streams[randi() % streams.size()] as AudioStream if not streams.is_empty() else null


## Small room reverb on SFX so synthesized spells sit in the arena.
func _add_sfx_reverb() -> void:
	var index: int = AudioServer.get_bus_index("SFX")
	if index < 0 or AudioServer.get_bus_effect_count(index) > 0:
		return
	var reverb: AudioEffectReverb = AudioEffectReverb.new()
	reverb.room_size = 0.45
	reverb.damping = 0.6
	reverb.wet = 0.18
	reverb.dry = 0.9
	AudioServer.add_bus_effect(index, reverb)


## Placeholder music (spec 07 §4): a slow synthesized pad loop on the Music bus.
func _start_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = _pad_loop()
	_music.bus = &"Music"
	_music.volume_db = -18.0
	add_child(_music)
	_music.play()


func _pad_loop() -> AudioStreamWAV:
	const LENGTH: float = 16.0
	# Am - F - C - G, one chord per 4 s, soft sines with slow tremolo.
	var chords: Array = [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 261.63, 329.63], [196.0, 246.94, 293.66]]
	var samples: int = int(LENGTH * MIX_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	for i: int in samples:
		var t: float = float(i) / MIX_RATE
		var chord: Array = chords[int(t / 4.0) % 4]
		var local: float = fmod(t, 4.0)
		var env: float = minf(local / 0.8, 1.0) * minf((4.0 - local) / 0.8, 1.0)
		var v: float = 0.0
		for f: float in chord:
			v += sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)
		v *= 0.12 * env * (0.8 + 0.2 * sin(TAU * 0.25 * t))
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = samples
	return wav


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
