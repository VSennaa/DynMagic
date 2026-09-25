@tool
extends McpTestSuite


func suite_name() -> String:
	return "sound_caption"


func test_direction_range_and_camera_rotation() -> void:
	var spell: ResolvedSpell = ResolvedSpell.new()
	spell.element = &"fire"
	spell.display_name = "Orbe"
	assert_eq(SoundCaption.describe(spell, Vector3.LEFT * 5, Transform3D.IDENTITY), "Orbe de Fogo à esquerda")
	assert_eq(SoundCaption.describe(spell, Vector3.RIGHT * 5, Transform3D.IDENTITY), "Orbe de Fogo à direita")
	assert_eq(SoundCaption.describe(spell, Vector3.FORWARD * 5, Transform3D.IDENTITY), "Orbe de Fogo à frente")
	assert_eq(SoundCaption.describe(spell, Vector3.BACK * 5, Transform3D.IDENTITY), "Orbe de Fogo atrás")
	assert_eq(SoundCaption.describe(spell, Vector3.ZERO, Transform3D.IDENTITY), "Orbe de Fogo perto de você")
	assert_eq(SoundCaption.describe(spell, Vector3.RIGHT * 31, Transform3D.IDENTITY), "")
	var listener: Transform3D = Transform3D(Basis(Vector3.UP, PI), Vector3(10, 0, 0))
	assert_eq(SoundCaption.describe(spell, Vector3(15, 0, 0), listener), "Orbe de Fogo à esquerda")
