class_name RuneCircle
extends MeshInstance3D
## Shows the spell being composed as a rune circle in front of the caster's hands.
## Everyone sees it: the caster through the first-person camera, the opponent on the body.

const FORM_INDEX: Dictionary = {&"projectile": 0, &"self": 1, &"area": 2}
const EFFECT_INDEX: Dictionary = {&"direct": 0, &"burst": 1, &"lingering": 2}
const APPEAR_TIME: float = 0.12

@export var player: Player

var _material: ShaderMaterial
var _composer: SpellComposer


func _ready() -> void:
	_material = material_override as ShaderMaterial
	if player == null:
		player = owner as Player
	# Player children are ready before the player, so read the composer by path.
	_composer = player.get_node(^"SpellComposer") as SpellComposer
	_composer.state_changed.connect(_on_state_changed)
	visible = false


func _on_state_changed(state: SpellComposer.State) -> void:
	match state:
		SpellComposer.State.IDLE:
			visible = false
		SpellComposer.State.SLOT_EFFECT:
			_show(_composer.form, &"")
		SpellComposer.State.AIMING:
			if _composer.pending != null:
				_show(_composer.pending.form, _composer.pending.effect)
		SpellComposer.State.CASTING:
			# Flash the full circle briefly on release.
			if _composer.last_spell != null:
				_show(_composer.last_spell.form, _composer.last_spell.effect)


func _show(form: StringName, effect: StringName) -> void:
	var element: ElementDef = SpellDB.elements.get(_composer.element_id)
	if element != null:
		_material.set_shader_parameter(&"rune_color", element.color)
	_material.set_shader_parameter(&"form_index", FORM_INDEX.get(form, -1))
	_material.set_shader_parameter(&"effect_index", EFFECT_INDEX.get(effect, -1))
	if not visible:
		visible = true
		scale = Vector3.ONE * 0.2
		create_tween().tween_property(self, ^"scale", Vector3.ONE, APPEAR_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Remote players: draw from the composer bits carried by inputs/snapshots (NetCodec.pack_composer).
func show_bits(bits: int) -> void:
	var unpacked: Vector3i = NetCodec.unpack_composer(bits)
	if unpacked.x == SpellComposer.State.IDLE:
		visible = false
		return
	var forms: Array = FORM_INDEX.keys()
	var effects: Array = EFFECT_INDEX.keys()
	_show(forms[unpacked.y] if unpacked.y >= 0 else &"", effects[unpacked.z] if unpacked.z >= 0 else &"")
