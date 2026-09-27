extends Node3D
## Real-gameplay spell-body capture (v1.2.1 follow-up to tools/spell_capture.gd).
## spell_capture.tscn's flat-gray static overview "looked fine" but the user reported the
## bodies still read as "a sphere with light" (sometimes invisible) in actual first-person
## play. This tool instead loads the real training sandbox (res://scenes/sandbox/training.tscn,
## the same Arena A + Player + HUD used to play), forces the player's element per round, and
## fires every form/effect combo through the real composer -> caster path:
##   SpellDB.resolve() -> SpellComposer._begin()/press_cast() (same call the real LMB/quick-key
##   path makes) -> Player._on_cast_requested() -> SpellCaster.spawn() -> the actual spell scene.
## Screenshots come from the player's own first-person camera (Head/Camera3D, viewmodel arms
## composited via the CanvasLayer overlay, same as what a player sees) at 0.05s/0.2s/0.5s
## after each cast, plus one third-person frame per combo.
## Windowed run only (screenshots need a real backbuffer):
##   Godot_v4.7.2-stable_win64_console.exe --path D:\DynMagic res://tools/cast_capture.tscn
## Output: res://build/gauntlet/cast_<element>_<form>_<effect>_<t>.png (+ ..._third.png).

const TRAINING_SCENE: PackedScene = preload("res://scenes/sandbox/training.tscn")
const ELEMENTS: Array[StringName] = [&"fire", &"frost", &"storm", &"wind"]
const FORMS: Array[StringName] = [&"projectile", &"area", &"self"]
const EFFECTS: Array[StringName] = [&"direct", &"burst", &"lingering"]
const CAPTURE_TIMES: Array[float] = [0.05, 0.2, 0.5]
const OUT_DIR: String = "res://build/gauntlet"

var _training: Node3D
var _player: Player
var _spawn_transform: Transform3D


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().mode = Window.MODE_WINDOWED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_training = TRAINING_SCENE.instantiate()
	add_child(_training)
	# Let the sandbox's own _ready() (spawn transform, HUD, dummies) finish first.
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _training.get_node(^"Player") as Player
	# training.gd already points the spawn transform into the arena, toward the dummy line;
	# don't override rotation here (an earlier version forced rotation.y = PI, which turned the
	# player straight into the spawn's back wall instead).
	_spawn_transform = _player.global_transform
	await get_tree().physics_frame

	for element: StringName in ELEMENTS:
		_training.call(&"set_element", element)
		await get_tree().process_frame
		for form: StringName in FORMS:
			for effect: StringName in EFFECTS:
				await _cast_and_capture(element, form, effect)

	print("[cast_capture] done")
	get_tree().quit()


## Fires one form/effect combo through the real composer path and screenshots the result.
func _cast_and_capture(element: StringName, form: StringName, effect: StringName) -> void:
	# SpellCaster.spawn() adds every spell node to get_tree().current_scene, which for this
	# tool (run directly, not through _training) is this CastCapture root itself, NOT
	# `_training`. Diff this node's own children to find/free what a cast spawns.
	var before: Array[Node] = get_children()

	var spell: ResolvedSpell = SpellDB.resolve(element, form, effect)
	if spell == null:
		push_error("cast_capture: could not resolve %s/%s/%s" % [element, form, effect])
		return
	# Real casts are seconds apart (mana regen, cooldowns, dashes settling); this loop fires 36
	# of them within a couple of seconds, so put the player back at spawn with full mana/no
	# cooldowns/lockout before every cast -- otherwise later combos either get rejected
	# ("Mana insuficiente", nothing spawns) or drift away from spawn (Impulse's dash/teleport)
	# until captures are a close-up of scenery instead of the cast.
	_player.global_transform = _spawn_transform
	_player.velocity = Vector3.ZERO
	_player.reset_round()
	_player.cast_lockout = 0.0
	# Same call SpellComposer.press_slot() makes on the second key press; quick spells
	# (cast_mode QUICK) fire immediately inside _begin(), confirm spells need the press_cast()
	# LMB would send.
	_player.composer.last_spell = null
	_player.composer._begin(spell)
	if _player.composer.state == SpellComposer.State.AIMING:
		_player.composer.press_cast()

	var label: String = "%s_%s_%s" % [element, form, effect]
	var elapsed: float = 0.0
	for t: float in CAPTURE_TIMES:
		var wait: float = t - elapsed
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		elapsed = t
		await RenderingServer.frame_post_draw
		_save(_player.get_aim_camera(), "cast_%s_%s" % [label, _time_tag(t)])

	await _capture_third_person(label)

	# Free whatever this cast spawned (projectile scene, Wall, Zone, self shell/marker...)
	# before the next combo so 36 casts don't pile up on top of each other.
	for node: Node in get_children():
		if is_instance_valid(node) and not before.has(node):
			node.queue_free()
	await get_tree().process_frame


func _capture_third_person(label: String) -> void:
	var cam: Camera3D = Camera3D.new()
	_training.add_child(cam)
	var back: Vector3 = -_player.get_aim_camera().global_basis.z
	cam.global_position = _player.global_position + Vector3.UP * 1.8 - back * 3.2 + Vector3.RIGHT.rotated(Vector3.UP, PI * 0.15) * 1.2
	cam.look_at(_player.global_position + Vector3.UP * 1.0, Vector3.UP)
	cam.current = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(cam, "cast_%s_third" % label)
	cam.current = false
	cam.queue_free()
	_player.get_aim_camera().current = true


func _save(camera: Camera3D, filename: String) -> void:
	if camera != null:
		camera.current = true
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, filename])
	print("[cast_capture] saved %s.png" % filename)


func _time_tag(t: float) -> String:
	return "%.2fs" % t
