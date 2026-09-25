class_name Hud
extends CanvasLayer
## HUD: crosshair composition wheel, HP/shield/mana bars, 3×3 cooldown grid
## and active statuses. Final layout arrives in M6 (docs/specs/06-ui-settings.md section 2).

const ELEMENT_NAMES: Dictionary = {&"fire": "Fogo", &"frost": "Gelo", &"storm": "Raio", &"wind": "Vento"}
## C17: why a spell was refused. Keys are the reasons produced by the local validator
## and by the host (scenes/player/player.gd `_validate_cast`, scenes/net/net_match.gd `_request_cast`).
const REJECT_REASONS: Dictionary = {
	&"no_mana": "Mana insuficiente",
	&"cooldown": "Magia em recarga",
	&"lockout": "Aguarde um instante",
	&"frozen": "Fora de combate",
	&"dead": "Você está morto",
	&"bad_origin": "Posição inválida",
	&"invalid": "Pedido inválido",
}

var player: Player

var _trail: Label
var _wheel: CrosshairWheel
## Bars and cooldown grid: hidden when no player is bound (spectators).
var _player_widgets: Array[Control] = []
var _hint: Label
var _enemy_box: VBoxContainer
var _enemy_name: Label
var _enemy_hp: ProgressBar
var _enemy_shield: ProgressBar
var _reject_label: Label
var _reject_time: float = 0.0
var _hp_bar: ProgressBar
var _shield_bar: ProgressBar
var _mana_bar: ProgressBar
var _hp_label: Label
var _mana_label: Label
var _status_label: Label
var _cooldowns: CooldownGrid
var _damage_arrow: Label
var _fps_label: Label
var _caption_label: Label
var _captions: Array[Dictionary] = []
var _core_bar: ProgressBar
var _last_hp: float = -1.0
var _prev_hp: float = -1.0
var _last_damage: float = 0.0
var _arrow_time: float = 0.0
## C2: hitmarker and floating damage number for our own successful hits.
var _hitmarker: Label
var _hitmarker_time: float = 0.0
var _feedback: Label
var _feedback_time: float = 0.0
## C3: round/death banners and the damage card shown on death.
var _banner: Label
var _banner_time: float = 0.0
var _death_card: Label
## Where hits most likely came from (1v1: the opponent). Set by the match scene.
var threat: Node3D


func _ready() -> void:
	_build()
	AudioBus.spell_played.connect(_on_spell_sound)
	Settings.changed.connect(_on_caption_setting)
	MatchState.damage_dealt.connect(on_damage_dealt)


func bind(p_player: Player) -> void:
	player = p_player
	player.composer.cast_rejected.connect(_on_cast_rejected)
	player.stats.died.connect(_on_died)


func _process(delta: float) -> void:
	_update_captions(delta)
	_reject_time = maxf(_reject_time - delta, 0.0)
	_reject_label.modulate.a = clampf(_reject_time * 2.0, 0.0, 1.0)
	_hitmarker_time = maxf(_hitmarker_time - delta, 0.0)
	_hitmarker.modulate.a = clampf(_hitmarker_time * 3.0, 0.0, 1.0)
	_feedback_time = maxf(_feedback_time - delta, 0.0)
	_feedback.modulate.a = clampf(_feedback_time * 1.5, 0.0, 1.0)
	_banner_time = maxf(_banner_time - delta, 0.0)
	_banner.modulate.a = clampf(_banner_time, 0.0, 1.0)
	var has_player: bool = player != null and is_instance_valid(player)
	for widget: Control in _player_widgets:
		widget.visible = has_player
	_wheel.visible = has_player
	if not has_player:
		return
	var stats: Stats = player.stats
	if _prev_hp >= 0.0 and stats.hp < _prev_hp - 0.5:
		_last_damage = _prev_hp - stats.hp
	_prev_hp = stats.hp
	_death_card.modulate.a = clampf(_death_card.modulate.a - delta * 0.5, 0.0, 1.0)
	_update_damage_arrow(delta, stats.hp + stats.shield)
	_fps_label.visible = Settings.show_fps or OS.get_cmdline_user_args().has("--fps")
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_hp_bar.max_value = stats.max_hp
	_hp_bar.value = stats.hp
	_enemy_box.visible = is_instance_valid(threat) and threat is Player
	if _enemy_box.visible:
		var enemy: Player = threat as Player
		_enemy_hp.max_value = enemy.stats.max_hp
		_enemy_hp.value = enemy.stats.hp
		_enemy_shield.max_value = enemy.stats.max_hp
		_enemy_shield.value = enemy.stats.shield
	_shield_bar.max_value = stats.max_hp
	_shield_bar.value = stats.shield
	_hp_label.text = "HP %d%s" % [roundi(stats.hp), "  +%d" % roundi(stats.shield) if stats.shield > 0.0 else ""]
	_mana_bar.max_value = stats.max_mana
	_mana_bar.value = stats.mana
	_mana_label.text = "MN %d" % roundi(stats.mana)
	_update_trail(player.composer)
	_cooldowns.player = player
	var parts: PackedStringArray = PackedStringArray()
	for id: StringName in stats.active_statuses():
		parts.append("%s %.1fs" % [Glossary.status(id), stats.status_time_left(id)])
	if player.invulnerable_time > 0.0:
		parts.append("invulnerável")
	if player.rune != &"":
		parts.append("runa: %s" % Glossary.rune(player.rune))
	if player.has_overcharge():
		parts.append("SOBRECARGA ×%d" % player.overcharge_casts)
	_status_label.text = "  ".join(parts)


## C17: a refused spell says why instead of failing silently. Fades over ~1.5 s.
func _on_cast_rejected(_spell: ResolvedSpell, reason: StringName) -> void:
	_reject_label.text = REJECT_REASONS.get(reason, "Magia recusada")
	_reject_time = 1.5


## C2: our hits are confirmed with a hitmarker, a sound and (optionally) the total damage.
func on_damage_dealt(amount: float, _hits: int) -> void:
	_hitmarker_time = 0.45
	if Settings.show_damage_numbers:
		_feedback.text = "%d" % roundi(amount)
		_feedback_time = 0.9
	AudioBus.play_ui("hit", -8.0)


## C3: big centre message for round and death events.
func show_banner(text: String, color: Color = Color.WHITE) -> void:
	_banner.text = text
	_banner.add_theme_color_override(&"font_color", color)
	_banner_time = 2.6


## C3: damage card (no replay): who killed us and the last hit taken.
func _on_died() -> void:
	_death_card.text = "Você foi abatido\núltimo dano: %d" % roundi(_last_damage)
	_death_card.modulate.a = 1.0


## The wheel shows the combo; text remains only as a short hint while aiming.
func _update_trail(composer: SpellComposer) -> void:
	_wheel.player = player
	_trail.text = ""
	_hint.text = "LMB confirmar · RMB cancelar" if composer.state == SpellComposer.State.AIMING else ""

func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_caption_label = _label("", 20)
	_caption_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_caption_label.position = Vector2(-260, 130)
	_caption_label.custom_minimum_size.x = 520
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_caption_label)

	_wheel = CrosshairWheel.new()
	root.add_child(_wheel)
	_wheel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

	var trail_box: VBoxContainer = VBoxContainer.new()
	trail_box.set_anchors_preset(Control.PRESET_CENTER)
	trail_box.position = Vector2(-200, 80)
	trail_box.custom_minimum_size = Vector2(400, 0)
	root.add_child(trail_box)
	_trail = _label("", 22)
	_trail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trail_box.add_child(_trail)
	_hint = _label("", 16)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(1, 1, 1, 0.7)
	trail_box.add_child(_hint)

	_fps_label = _label("", 18)
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.position = Vector2(-120, 12)
	root.add_child(_fps_label)

	_damage_arrow = _label("▲", 48)
	_damage_arrow.add_theme_color_override(&"font_color", Color(1.0, 0.25, 0.25))
	_damage_arrow.visible = false
	root.add_child(_damage_arrow)

	_core_bar = _bar(Color(0.8, 0.6, 1.0))
	_core_bar.max_value = 1.0
	_core_bar.set_anchors_preset(Control.PRESET_CENTER)
	_core_bar.position = Vector2(-160, 110)
	_core_bar.visible = false
	root.add_child(_core_bar)

	var bars: VBoxContainer = VBoxContainer.new()
	_player_widgets.append(bars)
	bars.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bars.position = Vector2(32, 24)
	bars.custom_minimum_size = Vector2(320, 0)
	root.add_child(bars)

	# Both HP bars live at the top (D5): ours left, the opponent's right.
	_enemy_box = VBoxContainer.new()
	_player_widgets.append(_enemy_box)
	_enemy_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_enemy_box.position = Vector2(-352, 24)
	_enemy_box.custom_minimum_size = Vector2(320, 0)
	root.add_child(_enemy_box)
	_enemy_name = _label("OPONENTE", 18)
	_enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_enemy_box.add_child(_enemy_name)
	_enemy_hp = _bar(Color(0.85, 0.25, 0.25))
	_enemy_box.add_child(_enemy_hp)
	_enemy_shield = _bar(Color(0.95, 0.9, 0.5))
	_enemy_shield.custom_minimum_size.y = 6
	_enemy_box.add_child(_enemy_shield)

	_reject_label = _label("", 22)
	_reject_label.set_anchors_preset(Control.PRESET_CENTER)
	_reject_label.position = Vector2(-200, -110)
	_reject_label.custom_minimum_size = Vector2(400, 0)
	_reject_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reject_label.add_theme_color_override(&"font_color", Color(1.0, 0.75, 0.3))
	_reject_label.modulate.a = 0.0
	root.add_child(_reject_label)

	# C2: hitmarker + floating damage number, both centred on the crosshair.
	_hitmarker = _label("✕", 40)
	_hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	_hitmarker.position = Vector2(-20, -20)
	_hitmarker.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.85))
	_hitmarker.modulate.a = 0.0
	root.add_child(_hitmarker)
	_feedback = _label("", 26)
	_feedback.set_anchors_preset(Control.PRESET_CENTER)
	_feedback.position = Vector2(-100, -70)
	_feedback.custom_minimum_size = Vector2(200, 0)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.4))
	_feedback.modulate.a = 0.0
	root.add_child(_feedback)

	# C3: centre banner (round/death) and the damage card.
	_banner = _label("", 46)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-300, -180)
	_banner.custom_minimum_size = Vector2(600, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_death_card = _label("", 24)
	_death_card.set_anchors_preset(Control.PRESET_CENTER)
	_death_card.position = Vector2(-250, 70)
	_death_card.custom_minimum_size = Vector2(500, 0)
	_death_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_card.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))
	_death_card.modulate.a = 0.0
	root.add_child(_death_card)

	_hp_label = _label("HP", 18)
	bars.add_child(_hp_label)
	_hp_bar = _bar(Color(0.85, 0.25, 0.25))
	bars.add_child(_hp_bar)
	_shield_bar = _bar(Color(0.95, 0.9, 0.5))
	_shield_bar.custom_minimum_size.y = 6
	bars.add_child(_shield_bar)
	_mana_label = _label("MN", 18)
	bars.add_child(_mana_label)
	_mana_bar = _bar(Color(0.3, 0.5, 0.95))
	bars.add_child(_mana_bar)
	_status_label = _label("", 16)
	bars.add_child(_status_label)

	_cooldowns = CooldownGrid.new()
	_player_widgets.append(_cooldowns)
	# Anchor before parenting: with no parent yet, position becomes the offset from the corner.
	_cooldowns.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_cooldowns.position = -_cooldowns.custom_minimum_size - Vector2(32, 32)
	root.add_child(_cooldowns)


func _label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _bar(color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(320, 14)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override(&"fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override(&"background", bg)
	return bar

## Directional damage indicator (spec 06 §2): when HP drops, an arrow at the screen edge points
## toward the threat for 1 s. In 1v1 the threat is the opponent.
func _update_damage_arrow(delta: float, total_hp: float) -> void:
	if _last_hp >= 0.0 and total_hp < _last_hp - 0.5:
		_arrow_time = 1.0
		AudioBus.play_ui("hit", -6.0)
	_last_hp = total_hp
	_arrow_time = maxf(_arrow_time - delta, 0.0)
	_damage_arrow.visible = _arrow_time > 0.0 and threat != null and is_instance_valid(threat)
	if not _damage_arrow.visible:
		return
	var to_threat: Vector3 = threat.global_position - player.global_position
	var local: Vector3 = player.global_basis.inverse() * to_threat
	var angle: float = atan2(local.x, -local.z)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var radius: float = minf(screen.x, screen.y) * 0.32
	_damage_arrow.position = screen * 0.5 + Vector2(sin(angle), -cos(angle)) * radius - _damage_arrow.size * 0.5
	_damage_arrow.rotation = angle
	_damage_arrow.pivot_offset = _damage_arrow.size * 0.5
	_damage_arrow.modulate.a = _arrow_time


## Core capture progress for the local player (0..1); hidden at 0.
func set_core_progress(ratio: float) -> void:
	_core_bar.visible = ratio > 0.0
	_core_bar.value = ratio


func _on_spell_sound(spell: ResolvedSpell, source: Vector3) -> void:
	if not Settings.sound_captions or not is_instance_valid(player):
		return
	var text: String = SoundCaption.describe(spell, source, player.get_aim_camera().global_transform)
	if text.is_empty():
		return
	if _captions.size() == 3:
		_captions.pop_front()
	_captions.append({"text": text, "remaining": 2.5})
	_update_captions(0.0)


func _on_caption_setting(key: StringName) -> void:
	if key == &"sound_captions" and not Settings.sound_captions:
		_captions.clear()
		_update_captions(0.0)


func _update_captions(delta: float) -> void:
	var lines: PackedStringArray = PackedStringArray()
	for i: int in range(_captions.size() - 1, -1, -1):
		_captions[i]["remaining"] -= delta
		if float(_captions[i]["remaining"]) <= 0.0:
			_captions.remove_at(i)
	for entry: Dictionary in _captions:
		lines.append(entry["text"])
	_caption_label.text = "\n".join(lines)
	_caption_label.visible = Settings.sound_captions and not lines.is_empty()
