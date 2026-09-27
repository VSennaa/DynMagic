## Audio bus volumes and one-shot playback helpers. See docs/specs/06-ui-settings.md.
## Mixed sources (user decision 2026-09-25): CC0 samples (Kenney, audio/cc0/) for UI, footsteps,
## hits and foley. Round 2026-09-27 ("spell sounds still bad"): spells now build on real CC0
## samples (audio/cc0/spells/, Kenney Sci-Fi Sounds + Digital Audio) decoded and resampled in
## GDScript (pitch-shift, layering, one-pole low/high-pass) with synthesis kept as a subtle
## sparkle/crackle support layer only. Cached per spell and played with small pitch variation.
extends Node

signal spell_played(spell: ResolvedSpell, position: Vector3)

const MIX_RATE: int = 22050
const BUSES: Array[String] = ["Music", "SFX", "UI", "Spells"]
## Spells is a dedicated sub-bus that sends into SFX (so spell casts/impacts pick up the SFX
## reverb send and the SFX volume slider) instead of feeding Master directly.
const BUS_SEND: Dictionary = {"Spells": "SFX"}
const MAX_VOICES_PER_SPELL: int = 3

var _cache: Dictionary[String, AudioStreamWAV] = {}
## Sample groups: name -> list of streams (a random one plays each time).
var _samples: Dictionary[String, Array] = {}
var _music: AudioStreamPlayer
## Per spell-key list of currently playing voices, so no single spell can stack more than
## MAX_VOICES_PER_SPELL simultaneous instances.
var _active_voices: Dictionary = {}

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
			AudioServer.set_bus_send(index, BUS_SEND.get(bus, "Master"))
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
	_play_at(_cache[key], position, parent, 0.0, &"Spells", key)


## Low boom for explosions and Mark detonations.
func play_impact(element: StringName, position: Vector3, parent: Node) -> void:
	if Net.dedicated:
		return
	var key: String = "%s_impact" % element
	if not _cache.has(key):
		_cache[key] = _synth(element, &"area", &"burst", true)
	_play_at(_cache[key], position, parent, 2.0, &"Spells", key)
	play_sample_at(String(IMPACT_LAYER.get(element, "thud")), position, parent, 0.0)


## voice_key, when non-empty, caps concurrent instances of that spell (MAX_VOICES_PER_SPELL):
## the oldest playing voice is stopped before a new one starts, so spam never stacks endlessly.
func _play_at(stream: AudioStream, position: Vector3, parent: Node, volume_db: float, bus: StringName = &"SFX", voice_key: String = "") -> void:
	if Net.dedicated or parent == null or not parent.is_inside_tree():
		return
	if voice_key != "":
		_limit_voices(voice_key)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db + randf_range(-1.0, 1.0)
	player.unit_size = 6.0
	player.pitch_scale = randf_range(0.96, 1.04)
	parent.add_child(player)
	player.global_position = position
	if voice_key != "":
		var list: Array = _active_voices.get(voice_key, [])
		list.append(player)
		_active_voices[voice_key] = list
		player.finished.connect(_on_voice_finished.bind(voice_key, player))
	player.finished.connect(player.queue_free)
	player.play()


func _on_voice_finished(voice_key: String, player: AudioStreamPlayer3D) -> void:
	var list: Array = _active_voices.get(voice_key, [])
	list.erase(player)
	_active_voices[voice_key] = list


## Stops the oldest voice(s) of a spell so a new one never pushes it past MAX_VOICES_PER_SPELL.
func _limit_voices(voice_key: String) -> void:
	var list: Array = _active_voices.get(voice_key, [])
	while list.size() >= MAX_VOICES_PER_SPELL:
		var oldest: AudioStreamPlayer3D = list.pop_front()
		if is_instance_valid(oldest):
			oldest.stop()
			oldest.queue_free()
	_active_voices[voice_key] = list


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


## Element sample layers (Kenney Sci-Fi Sounds / Digital Audio, audio/cc0/spells/). Each element's
## identity comes from 2-3 real CC0 samples that get pitch-shifted/layered in _synth; "pitch" is
## the element's base playback-rate multiplier and "cutoff" its final low-pass corner (frost stays
## bright, wind/fire stay warm). Synthesis is only ever a subtle sparkle/crackle layer on top.
const ELEMENT_SAMPLES: Dictionary = {
	&"fire": {
		"body": ["spells/thrusterFire_000.ogg", "spells/thrusterFire_001.ogg", "spells/thrusterFire_002.ogg", "spells/thrusterFire_003.ogg", "spells/thrusterFire_004.ogg"],
		"impact": ["spells/explosionCrunch_000.ogg", "spells/explosionCrunch_001.ogg", "spells/explosionCrunch_002.ogg", "spells/explosionCrunch_003.ogg", "spells/explosionCrunch_004.ogg"],
		"low": ["spells/lowFrequency_explosion_000.ogg", "spells/lowFrequency_explosion_001.ogg"],
		"pitch": 0.8, "cutoff": 3200.0,
	},
	&"frost": {
		"body": ["spells/forceField_000.ogg", "spells/forceField_001.ogg", "spells/forceField_002.ogg", "spells/forceField_003.ogg", "spells/forceField_004.ogg"],
		"shimmer": ["spells/phaserUp1.ogg", "spells/phaserUp2.ogg", "spells/phaserUp3.ogg", "spells/phaserUp4.ogg", "spells/phaserUp5.ogg", "spells/phaserUp6.ogg", "spells/phaserUp7.ogg"],
		"impact": ["spells/impactMetal_000.ogg", "spells/impactMetal_001.ogg", "spells/impactMetal_002.ogg", "spells/impactMetal_003.ogg", "spells/impactMetal_004.ogg"],
		"pitch": 1.4, "cutoff": 9500.0,
	},
	&"storm": {
		"body": ["spells/zap1.ogg", "spells/zap2.ogg", "spells/zapTwoTone.ogg", "spells/zapTwoTone2.ogg", "spells/zapThreeToneUp.ogg", "spells/zapThreeToneDown.ogg"],
		"snap": ["spells/laserSmall_000.ogg", "spells/laserSmall_001.ogg", "spells/laserSmall_002.ogg", "spells/laserRetro_000.ogg", "spells/laserRetro_001.ogg"],
		"impact": ["spells/lowFrequency_explosion_000.ogg", "spells/lowFrequency_explosion_001.ogg"],
		"low": ["spells/lowFrequency_explosion_000.ogg", "spells/lowFrequency_explosion_001.ogg"],
		"pitch": 1.0, "cutoff": 8000.0,
	},
	&"wind": {
		"body": ["spells/phaseJump1.ogg", "spells/phaseJump2.ogg", "spells/phaseJump3.ogg", "spells/phaseJump4.ogg", "spells/phaseJump5.ogg"],
		"impact": ["spells/forceField_000.ogg", "spells/forceField_002.ogg", "spells/forceField_004.ogg"],
		"pitch": 0.95, "cutoff": 5500.0,
	},
}
## Real sample used for the "self" form's rising shimmer, layered on top of every element's body.
const SELF_SHIMMER: Array[String] = ["spells/powerUp1.ogg", "spells/powerUp2.ogg", "spells/powerUp3.ogg", "spells/powerUp4.ogg", "spells/powerUp5.ogg", "spells/powerUp6.ogg", "spells/powerUp7.ogg", "spells/powerUp8.ogg", "spells/powerUp9.ogg", "spells/powerUp10.ogg", "spells/powerUp11.ogg", "spells/powerUp12.ogg"]

## Decoded-sample cache: "spells/foo.ogg" -> {data: PackedFloat32Array (mono, -1..1), rate: int}.
var _pcm_cache: Dictionary = {}


## Decodes a CC0 sample once (offline, via AudioStreamPlayback.mix_audio) and caches the mono PCM.
func _load_pcm(rel_path: String) -> Dictionary:
	if _pcm_cache.has(rel_path):
		return _pcm_cache[rel_path]
	var out: Dictionary = {"data": PackedFloat32Array(), "rate": MIX_RATE}
	var stream: AudioStream = load("res://audio/cc0/" + rel_path) as AudioStream
	if stream != null:
		var playback: AudioStreamPlayback = stream.instantiate_playback()
		if playback != null:
			playback.start(0.0)
			var mono: PackedFloat32Array = PackedFloat32Array()
			const CHUNK: int = 4096
			while true:
				var frames: PackedVector2Array = playback.mix_audio(1.0, CHUNK)
				for v: Vector2 in frames:
					mono.append((v.x + v.y) * 0.5)
				if frames.size() < CHUNK:
					break
			playback.stop()
			_normalize_sample_rms(mono, -16.0)  # equalize source loudness (Kenney packs vary)
			out = {"data": mono, "rate": AudioServer.get_mix_rate()}
	_pcm_cache[rel_path] = out
	return out


## Normalizes a decoded source sample to a fixed RMS before it ever gets layered/pitched, so
## differently-mastered Kenney packs (Sci-Fi Sounds vs Digital Audio) don't bias one element's
## loudness before the final per-spell normalization pass even runs.
func _normalize_sample_rms(data: PackedFloat32Array, target_rms_db: float) -> void:
	var sum_sq: float = 0.0
	for v: float in data:
		sum_sq += v * v
	var rms: float = sqrt(sum_sq / maxf(data.size(), 1))
	if rms < 0.0001:
		return
	var gain: float = db_to_linear(target_rms_db) / rms
	for i: int in data.size():
		data[i] = clampf(data[i] * gain, -1.0, 1.0)


## Resamples (pitch-shift via linear interpolation) and mixes one real sample into buf at
## start_time, sweeping pitch/gain linearly across the remaining buffer so "self" shimmer can
## rise and fading layers can taper. gain_start/gain_end are plain linear multipliers.
func _mix_sample(buf: PackedFloat32Array, group: Array, rng: RandomNumberGenerator, start_time: float, pitch_start: float, pitch_end: float, gain_start: float, gain_end: float, max_len: float, loop: bool = false) -> void:
	if group.is_empty():
		return
	var pcm: Dictionary = _load_pcm(group[rng.randi() % group.size()])
	var data: PackedFloat32Array = pcm["data"]
	if data.is_empty():
		return
	var native_rate: float = float(pcm["rate"])
	var limit_samples: int = data.size() if max_len < 0.0 else mini(data.size(), int(max_len * native_rate))
	var start_idx: int = int(start_time * MIX_RATE)
	var span: float = maxf(float(buf.size() - start_idx) / MIX_RATE, 0.001)
	var src_pos: float = 0.0
	var i: int = start_idx
	while i < buf.size():
		var idx0: int = int(src_pos)
		if idx0 >= limit_samples - 1 or idx0 >= data.size() - 1:
			# A pitched-up short sample can run out well before the shared envelope's decay
			# ends; textural layers (body/shimmer) loop back to the start instead of leaving
			# the rest of the shaped envelope silent (one-shot impact/punch layers don't loop).
			if loop and limit_samples > 1:
				src_pos = fmod(src_pos, float(limit_samples - 1))
				idx0 = int(src_pos)
			else:
				break
		var progress: float = clampf(float(i - start_idx) / MIX_RATE / span, 0.0, 1.0)
		var pitch: float = lerpf(pitch_start, pitch_end, progress)
		var gain: float = lerpf(gain_start, gain_end, progress)
		var frac: float = src_pos - idx0
		buf[i] += lerpf(data[idx0], data[idx0 + 1], frac) * gain
		src_pos += native_rate / MIX_RATE * pitch
		i += 1


## Subtle synthesized support layer only (sparkle/crackle/soft noise/sub-punch): the real samples
## carry each element's identity, this just adds texture that would be tedious to sample.
func _add_synth_support(buf: PackedFloat32Array, element: StringName, effect: StringName, impact: bool, rng: RandomNumberGenerator) -> void:
	var noise_lp: float = 0.0
	var noise_lp2: float = 0.0
	var crackle_env: float = 0.0
	for i: int in buf.size():
		var t: float = float(i) / MIX_RATE
		var white: float = rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, white, 0.35)
		noise_lp2 = lerpf(noise_lp2, noise_lp, 0.12)
		var noise_band: float = noise_lp - noise_lp2
		var support: float = 0.0
		match element:
			&"fire":
				crackle_env = maxf(crackle_env - 0.02, 0.0)
				if not impact and rng.randf() < 0.04:
					crackle_env = 1.0
				support = 0.18 * crackle_env * white
			&"storm":
				if rng.randf() < (0.03 if impact else 0.07):
					support = 0.22 * white
			&"wind":
				support = 0.22 * noise_lp2 * (0.6 + 0.4 * sin(TAU * 2.0 * t))
			&"frost":
				support = 0.05 * sin(TAU * 6.0 * t) * noise_band
		if effect == &"burst" and not impact:
			support += 0.35 * sin(TAU * 55.0 * t) * exp(-t * 14.0)  # low-end punch on cast bursts
		buf[i] += support


## Rebuilt spell audio (round "spell sounds still bad"): each element's cast/impact is now built
## from 2-3 real CC0 samples (ELEMENT_SAMPLES) pitch-shifted and layered per form/effect, with a
## thin synthesized sparkle/crackle/noise layer on top (_add_synth_support). Form shapes the layer
## choice (projectile steady, self rising shimmer, area deeper+wider+detuned); effect shapes which
## extra layer joins in (burst adds a bigger hit, lingering adds a soft fading shimmer tail) and
## the shared envelope's shape. A single low-pass (element cutoff) plus loudness normalization
## keep all 36 combos consistent.
func _synth(element: StringName, form: StringName, effect: StringName, impact: bool = false) -> AudioStreamWAV:
	var layers: Dictionary = ELEMENT_SAMPLES.get(element, ELEMENT_SAMPLES[&"fire"])
	var base_pitch: float = layers.get("pitch", 1.0)
	var cutoff: float = layers.get("cutoff", 8000.0)
	var length: float
	var attack: float
	if impact:
		length = {&"direct": 0.35, &"burst": 0.9, &"lingering": 1.05}.get(effect, 0.55)
		attack = 0.004
	else:
		length = {&"direct": 0.16, &"burst": 0.45, &"lingering": 0.6}.get(effect, 0.3)
		attack = {&"projectile": 0.006, &"self": 0.09, &"area": 0.02}.get(form, 0.012)
		if form == &"projectile" and effect == &"direct":
			# Arrow-like spam (cast every 0.3s): keep this combo very short and soft so it never
			# gets fatiguing.
			length = 0.11
			attack = 0.003
	var samples: int = maxi(int(length * MIX_RATE), 1)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(samples)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s%s%s%s" % [element, form, effect, impact])
	var depth_pitch: float = base_pitch * (0.82 if form == &"area" else 1.0)

	if impact:
		var impact_group: Array = layers.get("impact", layers.get("body", []))
		var impact_pitch: float = depth_pitch * (0.85 if effect == &"burst" else 1.0)
		_mix_sample(buf, impact_group, rng, 0.0, impact_pitch, impact_pitch * 0.94, 0.9, 0.0, length)
		if effect != &"direct" and layers.has("low"):
			_mix_sample(buf, layers["low"], rng, 0.0, depth_pitch * 0.8, depth_pitch * 0.7, 0.8, 0.0, length)
		if form == &"area":
			_mix_sample(buf, impact_group, rng, 0.01, impact_pitch * 1.03, impact_pitch * 0.97, 0.5, 0.0, length)
	else:
		var body_group: Array = layers.get("body", [])
		match form:
			&"self":
				# Rising shimmer climbing away from the caster. Both layers loop: a pitched-up
				# body/shimmer sample can otherwise run out well before the cast's full length.
				_mix_sample(buf, body_group, rng, 0.0, depth_pitch * 0.9, depth_pitch * 1.05, 0.7, 0.9, length, true)
				_mix_sample(buf, SELF_SHIMMER, rng, 0.0, base_pitch * 0.85, base_pitch * 1.35, 0.0, 0.8, length, true)
			&"area":
				# Deeper + wider: a second, detuned copy of the body sample for width.
				_mix_sample(buf, body_group, rng, 0.0, depth_pitch, depth_pitch * 0.92, 0.9, 0.5, length, true)
				_mix_sample(buf, body_group, rng, 0.015, depth_pitch * 1.03, depth_pitch * 0.95, 0.5, 0.25, length, true)
			_:  # projectile: steady launch, softer for the spammable direct combo
				var g: float = 0.55 if effect == &"direct" else 0.85
				_mix_sample(buf, body_group, rng, 0.0, depth_pitch, depth_pitch * 0.97, g, g * 0.5, length, true)
		if effect == &"burst":
			var punch_group: Array = layers.get("impact", layers.get("low", body_group))
			_mix_sample(buf, punch_group, rng, 0.0, depth_pitch * 0.9, depth_pitch * 0.8, 0.6, 0.0, length)
		elif effect == &"lingering" and layers.has("shimmer"):
			_mix_sample(buf, layers["shimmer"], rng, length * 0.15, base_pitch * 0.9, base_pitch * 1.1, 0.0, 0.35, length, true)

	_add_synth_support(buf, element, effect, impact, rng)

	for i: int in buf.size():
		var t: float = float(i) / MIX_RATE
		buf[i] *= _envelope(t, length, attack, effect, impact)

	_lowpass(buf, cutoff)
	if element == &"frost":
		_highpass(buf, 200.0)  # trim sub-bass mud, keep it bright without biting into loudness
	_soft_limit(buf, 0.35)  # tame transient sample peaks so loudness normalizes consistently
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


## Per-element low-pass (two cascaded one-pole stages) so nothing in the spell layer is harsh.
func _lowpass(buf: PackedFloat32Array, cutoff_hz: float) -> void:
	var coef: float = 1.0 - exp(-TAU * cutoff_hz / MIX_RATE)
	var y1: float = 0.0
	var y2: float = 0.0
	for i: int in buf.size():
		y1 += coef * (buf[i] - y1)
		y2 += coef * (y1 - y2)
		buf[i] = y2


## One-pole high-pass (used to keep frost bright by trimming low-end mud from its samples).
func _highpass(buf: PackedFloat32Array, cutoff_hz: float) -> void:
	var rc: float = 1.0 / (TAU * cutoff_hz)
	var dt: float = 1.0 / MIX_RATE
	var alpha: float = rc / (rc + dt)
	var prev_in: float = 0.0
	var prev_out: float = 0.0
	for i: int in buf.size():
		var x: float = buf[i]
		var y: float = alpha * (prev_out + x - prev_in)
		prev_in = x
		prev_out = y
		buf[i] = y


## Soft-knee saturation above `threshold` (tanh) so a single sharp sample transient can't dominate
## the peak and starve the RMS normalization pass below of headroom (keeps the 36 combos within
## a few dB of each other even when their source samples have very different crest factors).
func _soft_limit(buf: PackedFloat32Array, threshold: float) -> void:
	var span: float = maxf(1.0 - threshold, 0.0001)
	for i: int in buf.size():
		var x: float = buf[i]
		var a: float = absf(x)
		if a > threshold:
			var over: float = (a - threshold) / span
			buf[i] = signf(x) * (threshold + span * tanh(over))


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
