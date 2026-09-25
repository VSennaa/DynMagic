@tool
class_name SpellBase
extends Resource
## Base numbers for one Form × Effect cell, before the element multiplier.
## See docs/specs/01-spell-system.md sections 2 and 4.

enum CastMode { QUICK, CONFIRM }

@export var form: StringName = &"projectile"      # projectile | self | area
@export var effect: StringName = &"direct"        # direct | burst | lingering
@export var display_name: String = ""
@export var cast_mode: CastMode = CastMode.QUICK
## Spawned by the caster. Null until the spell scene exists.
@export var scene: PackedScene
@export var damage: float = 0.0
@export var mana_cost: float = 0.0
@export var cooldown: float = 0.0
## Shape-specific numbers: speed, radius, duration, range...
@export var params: Dictionary = {}


## Stable id shared by cooldowns and network messages, e.g. &"projectile_direct".
func key() -> StringName:
	return make_key(form, effect)


static func make_key(form_id: StringName, effect_id: StringName) -> StringName:
	return StringName("%s_%s" % [form_id, effect_id])
