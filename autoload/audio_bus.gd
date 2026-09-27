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
	## Round 8: own hit and own kill are louder/weightier than a plain impact (user feedback).
	"hit_strong": ["impacts/impactSoft_heavy_000.ogg", "impacts/impactSoft_heavy_002.ogg"],
	"kill": ["impacts/impactBell_heavy_000.ogg", "impacts/impactSoft_heavy_002.ogg"],
	"hurt": ["impacts/impactSoft_heavy_000.ogg", "impacts/impactSoft_heavy_001.ogg"],
	"thud": ["impacts/impactSoft_heavy_000.ogg", "impacts/impactSoft_heavy_001.ogg", "impacts/impactSoft_heavy_002.ogg"],
	"shatter": ["impacts/impactGlass_light_000.ogg", "impacts/impactGlass_light_001.ogg"],
	"stone": ["impacts/impactMining_000.ogg", "impacts/impactMining_001.ogg"],
	"bell": ["impacts/impactBell_heavy_000.ogg"],
	"cloth": ["foley/cloth1.ogg", "foley/cloth2.ogg", "foley/cloth3.ogg"],
	"page": ["foley/bookFlip1.ogg", "foley/bookFlip2.ogg"],
	"book": ["foley/bookOpen.ogg"],
}

## Round of "spell SFX still bad" feedback: layer an element-fitting CC0 sample under
## the synthesized impact so each element's hit reads distinctly (icy crunch, boom, ...).
const IMPACT_LAYER: Dictionary = {
	&"fire": "thud",
	&"frost": "shatter",
	&"storm": "bell",
	&"wind": "cloth",
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
	play_sample_at(String(IMPACT_LAYER.get(element, "thud")), position, parent, 0.0)


func _play_at(stream: AudioStream, position: Vector3, parent: Node, volume_db: float) -> void:
	if Net.dedicated or parent == null or not parent.is_inside_tree():
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db + randf_range(-1.0, 1.0)
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
	player.volume_db = volume_db + randf_range(-0.8, 0.8)
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


## Cast tonal center per element (Hz) and the low-end center used for impacts.
const BASE_FREQ: Dictionary = {&"fire": 150.0, &"frost": 900.0, &"storm": 260.0, &"wind": 480.0}
const IMPACT_FREQ: Dictionary = {&"fire": 70.0, &"frost": 1900.0, &"storm": 55.0, &"wind": 90.0}
## Inharmonic partial ratios/decay rates for the frost chime (spec 01 §5: glassy/crystal identity).
const FROST_PARTIAL_RATIO: Array[float] = [1.0, 2.02, 2.99, 4.13]
const FROST_PARTIAL_DECAY: Array[float] = [2.6, 4.5, 6.5, 9.0]


## Redesigned spell audio (user feedback "spell sound effects are still bad"): each element
## gets a distinct identity (fire = whoosh+crackle, frost = glassy chime, storm = electric zap,
## wind = airy whoosh+whistle); form shapes the pitch sweep (projectile steady/travelling,
## self rising shimmer, area deeper+wider); effect shapes the envelope (direct = clean single
## hit, burst = louder low-end punch, lingering = sustained tail). Everything is generated into
## a float buffer first so a shared attack/release envelope, a single ~9kHz low-pass and a
## final loudness normalization pass apply identically to all 36 combos.
func _synth(element: StringName, form: StringName, effect: StringName, impact: bool = false) -> AudioStreamWAV:
	var length: float = {&"direct": 0.22, &"burst": 0.5, &"lingering": 0.85}.get(effect, 0.3)
	if impact:
		length = 0.55
	var attack: float = {&"projectile": 0.006, &"self": 0.09, &"area": 0.02}.get(form, 0.012)
	if impact:
		attack = 0.004
	var base_freq: float = IMPACT_FREQ.get(element, 70.0) if impact else BASE_FREQ.get(element, 300.0)
	var samples: int = maxi(int(length * MIX_RATE), 1)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(samples)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s%s%s%s" % [element, form, effect, impact])
	var phase: float = 0.0
	var phase_b: float = 0.0  # slightly detuned layer: chime 2nd voice / area "width"
	var noise_lp: float = 0.0
	var noise_lp2: float = 0.0
	var noise_band: float = 0.0
	var crackle_env: float = 0.0
	var partial_phase: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i: int in samples:
		var t: float = float(i) / MIX_RATE
		var progress: float = t / length
		# Form sweep: projectile stays steady with a light travel fade, self rises (shimmer
		# climbing away from the caster), area sinks (deeper, wider impact-like body).
		var sweep: float = 1.0
		if not impact:
			match form:
				&"self":
					sweep = 1.0 + progress * 0.6
				&"area":
					sweep = 1.0 - progress * 0.45
				_:
					sweep = 1.0 - progress * 0.08
		phase += TAU * base_freq * sweep / MIX_RATE
		phase_b += TAU * base_freq * sweep * 1.015 / MIX_RATE
		var white: float = rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, white, 0.35)
		noise_lp2 = lerpf(noise_lp2, noise_lp, 0.12)
		noise_band = noise_lp - noise_lp2  # cheap band-pass: difference of two low-passes
		var raw: float = 0.0
		match element:
			&"fire":
				if impact:
					# Low thump plus a handful of ember crackles dying out under it.
					raw = sin(phase) * exp(-t * 9.0)
					raw += 0.5 * noise_band * exp(-t * 14.0)
				else:
					# Whoosh (band-passed noise, brighter at the start) + sparse crackle ticks.
					crackle_env = maxf(crackle_env - 0.02, 0.0)
					if rng.randf() < 0.05:
						crackle_env = 1.0
					raw = 0.85 * noise_band * (1.0 - 0.4 * progress)
					raw += 0.6 * crackle_env * white
					if form == &"area":
						raw += 0.3 * noise_lp2  # deeper/wider: add low rumble body
			&"frost":
				if impact:
					# Icy crunch: bright band-passed noise burst with a couple of short "cracks".
					raw = 0.8 * noise_band * exp(-t * 16.0)
					raw += 0.4 * sin(phase * 3.0) * exp(-t * 40.0)
				else:
					# Inharmonic chime partials with independent decays + a slow shimmer tail.
					for p: int in FROST_PARTIAL_RATIO.size():
						partial_phase[p] += TAU * base_freq * sweep * FROST_PARTIAL_RATIO[p] / MIX_RATE
						raw += (0.5 / (p + 1)) * sin(partial_phase[p]) * exp(-t * FROST_PARTIAL_DECAY[p])
					raw += 0.06 * sin(phase * 2.0) * sin(TAU * 6.0 * t)  # shimmer
					if form == &"area":
						raw += 0.15 * sin(phase_b)  # width: detuned twin voice
			&"storm":
				if impact:
					# Low boom (slow sine) under low-passed rumble noise, with a brief crackle.
					raw = sin(phase) * exp(-t * 6.0)
					raw += 0.5 * noise_lp2 * exp(-t * 8.0)
					if rng.randf() < 0.02:
						raw += white * 0.6
				else:
					# Electric zap: square/saw with a fast pitch drop, plus sparse crackle noise.
					var drop: float = exp(-t * 22.0)
					var zap_phase: float = phase * (1.0 + 2.0 * drop)
					raw = 0.55 * signf(sin(zap_phase)) + 0.2 * (fmod(zap_phase / TAU, 1.0) * 2.0 - 1.0)
					if rng.randf() < 0.1:
						raw += 0.5 * white
					if form == &"area":
						raw += 0.2 * signf(sin(phase_b * (1.0 + 2.0 * drop)))
			_:  # wind
				if impact:
					raw = 0.5 * noise_lp2 * exp(-t * 12.0)
					raw += 0.3 * sin(phase) * exp(-t * 16.0)
				else:
					# Airy filtered-noise sweep plus a soft tonal whistle.
					raw = 0.7 * noise_lp2 * (0.6 + 0.4 * sin(TAU * 2.0 * t))
					raw += 0.35 * sin(phase) * (0.5 + 0.5 * sin(TAU * 3.0 * t + 1.0))
					if form == &"area":
						raw += 0.2 * noise_band
		var env: float = _envelope(t, length, attack, effect, impact)
		var sample: float = raw * env
		if effect == &"burst" and not impact:
			# Extra low-end punch on the cast so bursts read louder without just being clipped.
			sample += 0.55 * sin(TAU * 60.0 * t) * exp(-t * 16.0)
		buf[i] = sample
	_lowpass(buf, 9000.0)
	_normalize(buf, -16.0, -1.5)
	return _to_wav(buf)


## Shared attack/release shape so every element/effect fades in and out cleanly (>=5 ms, no
## clicks) regardless of what its raw waveform looks like.
func _envelope(t: float, length: float, attack: float, effect: StringName, impact: bool) -> float:
	var a: float = maxf(attack, 0.005)
	var fade_in: float = minf(t / a, 1.0)
	var body: float
	if impact:
		body = pow(maxf(1.0 - t / length, 0.0), 1.4)
	else:
		match effect:
			&"lingering":
				var release_start: float = length * 0.5
				if t < release_start:
					body = 1.0
				else:
					body = maxf(1.0 - (t - release_start) / (length - release_start), 0.0)
				body *= 0.85 + 0.15 * sin(TAU * 5.0 * t)  # gentle sustained-tail tremolo
			&"burst":
				body = pow(maxf(1.0 - t / length, 0.0), 1.6)
			_:
				body = pow(maxf(1.0 - t / length, 0.0), 2.2)
	var tail: float = length - t
	var fade_out: float = clampf(tail / 0.006, 0.0, 1.0)  # >=6 ms fade-out, avoids end clicks
	return fade_in * body * fade_out


## Single ~9 kHz low-pass (two cascaded one-pole stages) so nothing in the spell layer is harsh.
func _lowpass(buf: PackedFloat32Array, cutoff_hz: float) -> void:
	var coef: float = 1.0 - exp(-TAU * cutoff_hz / MIX_RATE)
	var y1: float = 0.0
	var y2: float = 0.0
	for i: int in buf.size():
		y1 += coef * (buf[i] - y1)
		y2 += coef * (y1 - y2)
		buf[i] = y2


## Normalizes to a target RMS loudness (with a hard peak ceiling) so all 36 combos sit within
## a few dB of each other regardless of how sparse/dense their raw waveform is.
func _normalize(buf: PackedFloat32Array, target_rms_db: float, peak_ceiling_db: float) -> void:
	var sum_sq: float = 0.0
	var peak: float = 0.0
	for v: float in buf:
		sum_sq += v * v
		peak = maxf(peak, absf(v))
	var rms: float = sqrt(sum_sq / maxf(buf.size(), 1))
	if rms < 0.0001 or peak < 0.0001:
		return
	var gain: float = db_to_linear(target_rms_db) / rms
	var ceiling: float = db_to_linear(peak_ceiling_db)
	if peak * gain > ceiling:
		gain = ceiling / peak
	for i: int in buf.size():
		buf[i] = clampf(buf[i] * gain, -1.0, 1.0)


func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(buf.size() * 2)
	for i: int in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
