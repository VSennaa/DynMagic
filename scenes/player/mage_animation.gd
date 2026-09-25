extends Node
## Visual-only state selection. NetSync remains the source of remote composer bits.
var player: Player
var animations: AnimationPlayer
var _clips: Dictionary[StringName, StringName] = {}
var _last_position: Vector3
var _dead: bool = false
var _cast_time: float = 0.0
var _last_state: int = 0
var staff_socket: BoneAttachment3D
var staff: Node3D
var element: StringName = &""
var grip_transform: Transform3D
var current: StringName = &""


func setup(owner_player: Player, body: Node3D) -> void:
	player = owner_player
	animations = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_last_position = player.global_position
	var skeleton: Skeleton3D = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		var hand: int = skeleton.find_bone("hand_R")
		if hand >= 0:
			staff_socket = BoneAttachment3D.new()
			staff_socket.name = "StaffSocket"
			staff_socket.bone_name = "hand_R"
			skeleton.add_child(staff_socket)
			var rest: Transform3D = skeleton.get_bone_global_rest(hand)
			grip_transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin)
			_update_staff()
	if animations == null:
		push_error("Mage GLB has no AnimationPlayer")
		return
	for clip: StringName in [&"idle", &"walk", &"cast", &"dash", &"death"]:
		for imported: StringName in animations.get_animation_list():
			if String(imported).get_slice("/", String(imported).get_slice_count("/") - 1) == String(clip):
				_clips[clip] = imported
				var animation: Animation = animations.get_animation(imported)
				animation.loop_mode = Animation.LOOP_LINEAR if clip in [&"idle", &"walk", &"dash"] else Animation.LOOP_NONE
	player.stats.died.connect(_on_died)
	player.spell_cast.connect(_on_cast)
	_play(&"idle")


func _on_died() -> void:
	_dead = true
	_cast_time = 0.0
	_play(&"death")


func _on_cast(_spell: ResolvedSpell) -> void:
	_cast_time = 0.6
	if not _dead:
		_play(&"cast", true)


func _process(delta: float) -> void:
	if animations == null or delta <= 0.0:
		return
	_update_staff()
	var displacement: Vector3 = player.global_position - _last_position
	_last_position = player.global_position
	if player.stats.is_dead or player.stats.hp <= 0.0:
		if not _dead:
			_on_died()
		return
	if _dead:
		_dead = false
		_last_state = 0
		_play(&"idle")
	var sync: NetSync = player.get_node_or_null(^"NetSync") as NetSync
	var state: int = (sync.remote_composer_bits & 3) if sync != null else int(player.composer.state)
	if state == int(SpellComposer.State.CASTING) and _last_state != state:
		_on_cast(null)
	_last_state = state
	_cast_time = maxf(0.0, _cast_time - delta)
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	if sync != null and sync.role == NetSync.Role.CLIENT_REMOTE:
		speed = Vector2(displacement.x, displacement.z).length() / delta
	# Ignore spawn/reconnect teleports, which are not a dash.
	if displacement.length() > 2.0 or player.frozen:
		speed = 0.0
	if speed > player.tuning.sprint_speed * 1.5:
		_play(&"dash")
	elif _cast_time > 0.0 or state in [int(SpellComposer.State.SLOT_EFFECT), int(SpellComposer.State.AIMING)]:
		_play(&"cast")
		# Hold the prepared gesture while composing; release on cast/cancel.
		if _cast_time <= 0.0:
			animations.seek(0.3, true)
	elif speed > 0.15:
		_play(&"walk")
	else:
		_play(&"idle")


func _play(clip: StringName, restart: bool = false) -> void:
	if (current == clip and not restart) or not _clips.has(clip):
		return
	current = clip
	if restart:
		animations.stop()
	animations.play(_clips[clip], 0.10)


func _update_staff() -> void:
	if staff_socket == null:
		return
	var selected: StringName = player.composer.element_id
	if selected not in [&"fire", &"frost", &"storm", &"wind"]:
		selected = &"fire"
	if selected == element:
		return
	element = selected
	if staff != null:
		staff.free()
	staff = (load("res://scenes/assets/staff_%s.tscn" % element) as PackedScene).instantiate() as Node3D
	staff_socket.add_child(staff)
	staff.transform = grip_transform
