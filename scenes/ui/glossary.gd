class_name Glossary
extends RefCounted
## D10: single glossary for every player-facing name. UI must never print raw ids
## (`cold_blood`, `sudden_death`, `burn`, `fire`) — always go through here.

const ELEMENTS: Dictionary = {&"fire": "Fogo", &"frost": "Gelo", &"storm": "Raio", &"wind": "Vento"}
const FORMS: Dictionary = {&"projectile": "Projétil", &"self": "Pessoal", &"area": "Área"}
const EFFECTS: Dictionary = {&"direct": "Direto", &"burst": "Explosivo", &"lingering": "Contínuo"}
const STATUSES: Dictionary = {&"burn": "Queimando", &"slow": "Lento", &"shock": "Choque", &"knockback": "Empurrão", &"aura": "Aura"}
## Rune id -> short name shown on the draft button.
const RUNES: Dictionary = {
	&"breath": "Fôlego",
	&"haste": "Pressa",
	&"light_step": "Passo Leve",
	&"husk": "Casca",
	&"focus": "Foco",
	&"echo": "Eco",
	&"cold_blood": "Sangue Frio",
}
## Rune id -> effect, shown as a description line.
const RUNE_DESCRIPTIONS: Dictionary = {
	&"breath": "+30 de mana máxima",
	&"haste": "-20% de recarga",
	&"light_step": "+12% de velocidade",
	&"husk": "+25 de escudo no round",
	&"focus": "concentração",
	&"echo": "-30% de mana ao repetir a magia",
	&"cold_blood": "+20% de dano com pouca vida",
}
const OVERTIME: Dictionary = {&"collapse": "Colapso", &"sudden_death": "Morte Súbita", &"mana_surge": "Maré de Mana", &"random": "Aleatório"}
const ARENAS: Dictionary = {&"rotation": "Rotação", &"random": "Aleatória", &"A": "A Claustro", &"B": "B Pátio Partido", &"C": "C Espinha"}
## round_ended / match_ended reason -> why the round was decided.
const REASONS: Dictionary = {
	&"kill": "abate", &"double_kill": "abate duplo", &"hp": "mais vida",
	&"core": "Núcleo Arcano", &"draw": "empate", &"forfeit": "desistência",
	&"score": "placar", &"timeout": "tempo",
}


static func element(id: StringName) -> String:
	return String(ELEMENTS.get(id, String(id)))


static func form(id: StringName) -> String:
	return String(FORMS.get(id, String(id)))


static func effect(id: StringName) -> String:
	return String(EFFECTS.get(id, String(id)))


static func status(id: StringName) -> String:
	return String(STATUSES.get(id, String(id)))


static func rune(id: StringName) -> String:
	return String(RUNES.get(id, String(id)))


static func rune_description(id: StringName) -> String:
	return String(RUNE_DESCRIPTIONS.get(id, ""))


static func overtime(id: StringName) -> String:
	return String(OVERTIME.get(id, String(id)))


static func arena(id: StringName) -> String:
	return String(ARENAS.get(id, String(id)))


static func reason(id: StringName) -> String:
	return String(REASONS.get(id, String(id)))
