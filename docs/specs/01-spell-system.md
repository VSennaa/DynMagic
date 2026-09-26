# Spec 01 — Sistema de magia

## 1. Gramática

Toda magia = **Elemento + Forma + Efeito**.

| Slot | Opção 1 (`Q`) | Opção 2 (`E`) | Opção 3 (`R`) |
|---|---|---|---|
| 1. Elemento | fixo no round (escolhido no draft) | — | — |
| 2. Forma | Projétil | Pessoal | Área |
| 3. Efeito | Direto | Explosivo | Contínuo |

- Cada jogador tem **sempre 1 elemento por round**. O slot 1 é preenchido sozinho. O jogador aperta 2 teclas: forma e efeito.
- Cada magia tem um **modo de conjuração** (seção 2.1):
  - **Rápida:** dispara no momento em que o efeito é escolhido, na direção da mira. Sem clique.
  - **Confirmada:** ao escolher o efeito, entra em modo de mira com prévia. `LMB` confirma. `RMB` ou `F` cancela sem gastar mana.
- `RMB` fora do modo de mira repete a última magia. Magia rápida dispara na hora. Magia confirmada entra em modo de mira.
- `F` limpa a sequência.
- A sequência expira 2,5 s depois da última tecla. O modo de mira expira em 4 s e cancela sem gastar mana.
- Buffer de input de 150 ms: tecla apertada durante o lockout de conjuração entra na fila.

### Máquina de estados do `SpellComposer`

```
IDLE ─tecla─► SLOT_EFFECT ─tecla─┬─ rápida ──────────────────► CASTING ─► IDLE
  ▲                │             └─ confirmada ─► AIMING ─LMB─► CASTING
  │                │                                │
  └── F / timeout / morte / fim de round / RMB ─────┘
```

`IDLE` já tem o elemento do round. A primeira tecla escolhe a forma.

## 2. Matriz Forma × Efeito

Valores base, antes do multiplicador de elemento. Dano em HP (vida máxima = 100). Mana máxima = 100, regeneração de 12/s.

| Forma \ Efeito | Direto | Explosivo | Contínuo |
|---|---|---|---|
| **Projétil** | **Seta.** Rápida (45 m/s), 16 dano, 12 mana, CD 0,35 s | **Orbe.** 22 m/s, explode no impacto ou a 30 m. Raio 3 m, 28 dano central com queda linear até 10. 30 mana, CD 2 s | **Semente.** Parábola (18 m/s). Cria zona de 3,5 m por 4 s no impacto. 22 mana, CD 5 s |
| **Pessoal** | **Guarda.** Escudo de 30 por 3 s. 25 mana, CD 8 s | **Impulso** (mobilidade superior). Dash de 9 m na direção do input em 0,18 s, com invulnerabilidade nos primeiros 0,1 s. Deixa rastro. 20 mana, CD 4 s | **Aura.** Buff de 6 s (ver elemento). 30 mana, CD 14 s |
| **Área** | **Leque.** Cone instantâneo de 6 m, 50°. 20 dano. 18 mana, CD 1,2 s | **Marca.** Círculo no chão onde a mira toca (alcance 25 m). Detona depois de 0,9 s. Raio 2,5 m, 38 dano. 35 mana, CD 6 s | **Muralha.** Parede de 6 × 3 m a 4 m à frente, perpendicular à mira. Dura 5 s, 120 HP. 30 mana, CD 10 s |

## 3. Elementos

Cada elemento aplica um multiplicador de dano, um status e uma variação por magia.

| | Fogo | Gelo | Raio | Vento |
|---|---|---|---|---|
| Cor primária | `#FF5A1F` | `#6FD3FF` | `#C98BFF` | `#7CF2B0` |
| Dano | ×1,15 | ×0,9 | ×1,0 | ×0,85 |
| Status | Queimadura: 4 dano/s por 3 s | Lentidão: −30% velocidade por 1,5 s | Choque: próximo dano recebido +20% | Empurrão: knockback de 5 m/s |
| Seta | Aplica queimadura | Aplica lentidão | Velocidade 70 m/s | Curva 15° na direção da mira |
| Orbe | Deixa chão em chamas por 2 s | Congela chão (atrito baixo) por 3 s | Encadeia 1 raio secundário (8 dano) | Puxa para o centro antes de explodir |
| Semente | Zona de dano 8/s | Zona de lentidão 50% | Zona aplica choque a cada 1 s | Zona de corrente: projéteis que passam desviam |
| Guarda | Refletir 20% do dano | Escudo 45, mas sem movimento de sprint | Ao quebrar, choca quem atacou | Desvia o próximo projétil |
| Impulso | Rastro de fogo 2 s | Dash deslizante, 11 m | Teleporte instantâneo (sem travessia) | Dash para cima + planar 1 s |
| Aura | +20% dano | Imune a lentidão, +15 regeneração de escudo | +25% velocidade de projétil e −15% CD | +25% velocidade de movimento, pulo duplo |
| Leque | Alcance 7 m | Aplica lentidão forte (50%) | Arco 30°, alcance 9 m | Empurrão de 10 m/s |
| Marca | Queimadura em área | Prende no lugar 0,6 s | Detona em 0,6 s | Lança para cima |
| Muralha | Queima quem atravessa | 180 HP, opaca | Muralha de raio (transparente, dá dano) | Bloqueia projéteis, não pessoas |

### 2.1 Modo de conjuração

| Forma \ Efeito | Direto | Explosivo | Contínuo |
|---|---|---|---|
| **Projétil** | Rápida | Confirmada (prévia: ponto de impacto + raio) | Confirmada (prévia: arco da parábola + zona) |
| **Pessoal** | Rápida | Rápida (direção = input de movimento; sem input = para frente) | Rápida |
| **Área** | Rápida | Confirmada (prévia: círculo no chão) | Confirmada (prévia: muralha fantasma) |

Regra: magia de reação ou de pressão é rápida. Magia que depende de posicionamento é confirmada. A prévia só aparece para quem conjura. O oponente vê o círculo rúnico (seção 5), que fica aceso durante todo o modo de mira.

Regra de balanceamento: o valor de cada célula vem de `base × mult_elemento`. Só as variações da tabela acima são código específico.

## 4. Modelo de dados

```gdscript
# data/elements/element_def.gd
class_name ElementDef extends Resource
@export var id: StringName
@export var display_name: String
@export var color: Color
@export var damage_mult: float = 1.0
@export var status: StatusDef
@export var variants: Dictionary   # StringName (spell_key) -> SpellVariant

# data/forms/form_def.gd
class_name FormDef extends Resource
@export var id: StringName          # &"projectile", &"self", &"area"
@export var glyph: Texture2D

# data/effects/effect_def.gd
class_name EffectDef extends Resource
@export var id: StringName          # &"direct", &"burst", &"lingering"

# data/spell_base.gd — uma entrada por (forma, efeito)
class_name SpellBase extends Resource
@export var key: StringName         # &"projectile_direct"
@export var scene: PackedScene
@export var damage: float
@export var mana_cost: float
@export var cooldown: float
@export var params: Dictionary      # speed, radius, duration...
```

Implementação (2026-09-24): bases em `data/spells/<form>_<effect>.tres`, elementos em `data/elements/<id>.tres`. `ElementDef.variants` guarda, por chave de magia, parâmetros que sobrescrevem ou somam aos de `SpellBase.params`. `FormDef`/`EffectDef` ficam para o M2, junto com os glifos.

`SpellDB.resolve(element, form, effect) -> ResolvedSpell` monta os números finais. Função pura, sem estado. Testada nas 36 combinações.

`SpellBase` também tem `@export var cast_mode: CastMode` (`QUICK` ou `CONFIRM`), conforme a tabela 2.1.

Cooldown é por **combinação forma+efeito**. Todos os cooldowns zeram no início de cada round.

## 5. Leitura visual

- Ao apertar o slot de forma, um **círculo rúnico** aparece na frente das mãos. O oponente vê o mesmo círculo no modelo de terceira pessoa.
- Cor do círculo = elemento. Glifo central = forma. Anel externo = efeito (liso = direto, dentado = explosivo, pontilhado = contínuo).
- Som de conjuração em 3 camadas: timbre do elemento, ataque da forma, cauda do efeito.

## 6. Critérios de aceite

- [ ] As 36 combinações resolvem sem erro e o teste compara com uma tabela esperada.
- [ ] Sequência incompleta nunca conjura.
- [ ] Magia rápida dispara no mesmo frame em que o efeito é escolhido.
- [ ] Magia confirmada mostra prévia e só gasta mana ao confirmar.
- [ ] Timeout, `F`, morte e fim de round limpam a sequência e o modo de mira.
- [ ] Recast respeita mana, cooldown e modo de conjuração.
- [ ] Mana e cooldown só mudam no host. O cliente mostra previsão e corrige com o snapshot.
- [ ] O oponente vê o círculo rúnico com cor e glifo corretos antes do disparo.

## Rodada 9 ? contrato espacial R1

Seta e melee respeitam o percurso f?sico. Melee mede alcance em 3D. Orbe e Marca usam tr?s amostras verticais do corpo a partir do centro do efeito: dano proporcional ? exposi??o; cobertura total impede dano e efeitos. Impacto de Orbe desloca a origem 4 cm pela normal para n?o nascer dentro da pedra. Leque compartilha a consulta de LOS. Semente continua parab?lica e pode colocar uma zona atr?s da cobertura; zona exige piso a at? 0,5 m, raio e exposi??o. Muralha de Gelo bloqueia corpo/tiro/explos?o; Vento bloqueia tiro/explos?o; Fogo e Raio s?o atravess?veis. N?cleo exige dist?ncia horizontal ?2 m e vertical ?0,5 m do CoreAnchor do mapa.

## Rodada 9 ? planos elementais R2 (substitui tabela hist?rica da se??o 3)

Multiplicadores permanecem 1,05/0,95/1/0,95 e Seta mant?m tr?s cargas/0,3 s/1,2 s. Fogo renova queimadura at? 3 s; Leque consome a queimadura antecipando 50% do dano restante, abrindo m?o do restante. Orbe n?o cria ch?o; Guarda n?o reflete. Aura permite uma Semente em faixa de 6?2 m por 4 s, mesmo DPS, orientada pela mira. Impulso s? planta rastro nas posi??es percorridas.

Gelo: Seta sem slow; Orbe aplica slow no impacto, sem zona. Marca prende por 0,6 s; depois h? 1 s sem root/slow forte. Aura s? conserva imunidade a slow. Raio: Choque s? ? consumido em impactos de Seta/Leque/Orbe/Marca; ticks e melee n?o o gastam. Orbe sem chain, Marca 0,9 s, Muralha aplica Choque na travessia. Aura s? aumenta velocidade de proj?til. Teleporte mostra destino por 0,12 s antes do deslocamento, validando colis?o novamente.

Vento: Semente empurra corpos pela dire??o da mira, sem desviar tiros. Guarda desvia um proj?til na janela inicial de 0,25 s; depois conserva o escudo comum. Zonas sobrepostas da mesma magia/dono n?o acumulam intensidade. Status novos usam o codec compacto; protocolo 4 exige clientes da mesma vers?o.

## Rodada 9 ? prepara??o e compromisso R4

G em IDLE vazio arma a pr?xima composi??o para armazenamento; F desarma. G em mira guarda, G com slot cheio recupera (confirmadas exigem LMB). Um slot, com valida??o/ACK por revis?o no host, reserva e recargas normais. Inscri??o persistente mostra apenas a forma. V mant?m 12 dano/1,8 m/70?/0,8 s, com antecipa??o 0,12 s e recupera??o 0,25 s sem conjura??o; dano no contato respeita cobertura e altura. Windup/lockout e slot guardado entram na reconex?o.
