@tool
class_name ElementDef
extends Resource
## One element: color, damage multiplier, status and per-spell variants.
## See docs/specs/01-spell-system.md section 3.

@export var id: StringName = &"fire"
@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export var damage_mult: float = 1.0
@export var status_id: StringName = &""
@export var status_duration: float = 0.0
## Extra numbers for the status, e.g. {"dps": 4.0} for burn.
@export var status_params: Dictionary = {}
## Spell key -> params that override or extend SpellBase.params for this element.
@export var variants: Dictionary = {}


func variant_for(spell_key: StringName) -> Dictionary:
	var entry: Variant = variants.get(spell_key, variants.get(String(spell_key), {}))
	return entry as Dictionary if entry is Dictionary else {}
