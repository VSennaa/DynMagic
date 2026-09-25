@tool
class_name SoundCaption
extends RefCounted
## Caption range is independent of the volume sliders, so muted SFX remain accessible.

const RANGE: float = 30.0
const ELEMENT_NAMES: Dictionary = {&"fire": "Fogo", &"frost": "Gelo", &"storm": "Raio", &"wind": "Vento"}


static func describe(spell: ResolvedSpell, source: Vector3, listener: Transform3D) -> String:
	var offset: Vector3 = source - listener.origin
	if offset.length() > RANGE:
		return ""
	var local: Vector3 = listener.basis.inverse() * offset
	var direction: String = "perto de você"
	if offset.length() > 1.0:
		if absf(local.x) > absf(local.z):
			direction = "à direita" if local.x > 0.0 else "à esquerda"
		else:
			direction = "à frente" if local.z < 0.0 else "atrás"
	return "%s de %s %s" % [spell.display_name, ELEMENT_NAMES.get(spell.element, String(spell.element)), direction]
