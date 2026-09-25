@tool
class_name ResolvedSpell
extends RefCounted
## Final numbers for one Element × Form × Effect combination.
## Produced by SpellDB.resolve_with(); never edited afterwards.

var element: StringName
var form: StringName
var effect: StringName
var key: StringName
var display_name: String
var cast_mode: SpellBase.CastMode
var scene: PackedScene
var color: Color
## Damage before the element multiplier.
var base_damage: float
var damage: float
var mana_cost: float
var cooldown: float
var params: Dictionary
var status_id: StringName
var status_duration: float
var status_params: Dictionary


func param(name: StringName, default: Variant = null) -> Variant:
	return params.get(String(name), params.get(name, default))


func is_quick() -> bool:
	return cast_mode == SpellBase.CastMode.QUICK
