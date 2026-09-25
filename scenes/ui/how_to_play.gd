extends Control
## C14: "Como jogar" — a single page that explains the loop, the controls, the spell
## grammar and the match rules, so a new player does not need the specs.

const CONTROL_LINES: Array[String] = [
	"WASD mover · Espaço pular · Ctrl agachar · Shift correr",
	"Q / E / R escolher a forma, depois o efeito",
	"Segurar a mira nas magias confirmadas e clicar com o botão esquerdo",
	"Botão direito repete a última magia (só as confirmadas)",
	"Tab placar · F3 rede · Esc pausa",
]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var column: VBoxContainer = UiKit.screen(self)
	column.add_child(UiKit.title("Como jogar", 52))
	column.add_child(UiKit.header("O duelo"))
	column.add_child(UiKit.label("Melhor de 7: vence quem ganhar 4 rounds. Cada round é 1 vida em 90 s; se o tempo acabar, a Prorrogação decide.", 20))
	column.add_child(UiKit.header("A escolha"))
	column.add_child(UiKit.label("A cada round cada jogador escolhe 1 elemento (Fogo, Gelo, Raio ou Vento); não pode repetir o do oponente. Quem perdeu o round anterior escolhe 1 de 3 runas.", 20))
	column.add_child(UiKit.header("As magias"))
	column.add_child(UiKit.label("Cada magia é uma combinação: elemento fixo do round + forma (Projétil, Pessoal, Área) + efeito (Direto, Explosivo, Contínuo). São 9 opções por round.", 20))
	column.add_child(UiKit.row(_element_labels()))
	column.add_child(UiKit.header("Controles"))
	for line: String in CONTROL_LINES:
		column.add_child(UiKit.label(line, 20))
	column.add_child(UiKit.button("Voltar", func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU)))


## One coloured chip per element with its identity status.
func _element_labels() -> Array[Control]:
	var chips: Array[Control] = []
	var identity: Dictionary = {&"fire": "queimadura", &"frost": "lentidão", &"storm": "choque", &"wind": "empurrão"}
	for element_id: StringName in MatchFsm.ELEMENTS:
		var element: ElementDef = SpellDB.elements.get(element_id)
		var chip: Label = UiKit.label("%s — %s" % [Glossary.element(element_id), identity.get(element_id, "")], 18)
		if element != null:
			chip.add_theme_color_override(&"font_color", element.color)
		chip.custom_minimum_size = Vector2(150, 0)
		chips.append(chip)
	return chips
