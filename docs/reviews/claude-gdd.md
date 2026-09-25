# Revisão de GDD — DynMagic rumo ao alpha fechado 1.0

Autor: Claude (papel: game designer / dono do GDD) · 2026-09-25 · base: `main` em `eb2ed56` (v0.3.1)

Escopo: coerência SDD × specs × código, core loop, draft/runas/Núcleo/overtime, arenas e o que falta para um **alpha fechado 1.0** (amigos, 1v1, 3 arenas, MD7). Só leitura de código. Nenhum arquivo além deste foi alterado.

Legenda: **P0** bloqueia o alpha · **P1** deve entrar no alpha · **P2** pode ficar para depois. Esforço **S** (≤ 1 dia) / **M** (2–4 dias) / **L** (≥ 1 semana).

---

## Resumo executivo

O esqueleto é sólido: FSM de partida pura e testada, host-authoritative, 36 magias derivadas de tabela, draft sequencial, Núcleo, 3 overtimes, reconexão, servidor dedicado, espectador. O que falta para o alpha não é sistema, é **leitura e justiça**:

1. O jogador não sabe se acertou, por que ganhou ou perdeu o round, nem o que uma runa faz.
2. A plaquinha de HP do oponente aparece **através das paredes**, o que anula o desenho das arenas.
3. O draft encerra a escolha de runa do perdedor antes do tempo, o que anula o catch-up.
4. A Seta com `RMB` é a melhor opção em quase todo cenário. Com isso, a gramática de composição vira "Q Q e depois segura o botão direito".
5. Fogo mata com ~5 Setas e Vento precisa de 8. Quem escolhe primeiro pega Fogo.
6. Morte Súbita zera a vantagem de HP de quem jogou melhor nos 90 s.

---

## P0 — bloqueia o alpha

### P0-1. Plaquinha do oponente visível através de paredes (wallhack para os dois)
- **Problema:** o `Label3D` "debug" sobre o oponente usa `no_depth_test = true` e mostra HP, escudo e status.
- **Evidência:** `scenes/player/player.gd:420-428` (comentário "Debug nameplate… Replaced by the final HUD in M6") e `:438-444`.
- **Impacto:** nenhuma cobertura esconde posição. Emboscada na Espinha (spec 03 §3 C), quebra de linha de visão pelo pilar e a previsão de Marca/Semente perdem valor. Quem está na frente em HP não consegue se esconder, e o atrás sabe sempre onde mirar a Marca. O pilar 2 do SDD ("Leitura clara") vira informação perfeita, não leitura.
- **Proposta:** remover o `no_depth_test`. O HP do oponente sai do mundo e vai para o HUD, em duas barras no topo estilo jogo de luta (ver P1-9). No mundo fica só um contorno fino quando houver linha de visão, se o playtest pedir.
- **Esforço:** S.

### P0-2. A runa do perdedor é sorteada quando o lado B escolhe o elemento
- **Problema:** `_advance_draft()` chama `_auto_pick_runes()` e vai para `COUNTDOWN` assim que B escolhe. A spec diz que o perdedor escolhe a runa "durante os 20 s inteiros, em paralelo".
- **Evidência:** `scenes/match/match_fsm.gd:117-120` × `docs/specs/02-match-loop.md` §3 item 3.
- **Impacto:** quando o perdedor é o lado A (acontece a cada troca de lado), o vencedor, como lado B, pode escolher na hora e forçar uma runa aleatória no perdedor. Mesmo sem má-fé, quem ainda está lendo as 3 opções perde a escolha. O único mecanismo de catch-up passa a ser loteria.
- **Proposta:** o draft termina quando `elements` está completo **e** todos os `rune_offers` têm escolha, ou quando o relógio de B zera. Mostrar "aguardando runa do oponente" para quem já escolheu. Adicionar teste em `test_match_fsm.gd`.
- **Esforço:** S.

### P0-3. Não há confirmação de acerto para quem ataca
- **Problema:** o HUD só reage a dano **recebido** (seta direcional e som "hit"). Números de dano existem apenas no boneco de treino. O RPC `damage_applied` da spec 04 §6 ("serve para hitmarker e número de dano") não foi implementado.
- **Evidência:** `scenes/ui/hud.gd:182-199`; `scenes/sandbox/training_dummy.gd:62`; `grep damage_applied` sem resultado; `docs/specs/04-networking.md` §6.
- **Impacto:** em FPS de projétil com viagem de 0,4–1 s, sem hitmarker o jogador não aprende a mirar nem sabe se a Marca pegou. Hoje a única confirmação é a plaquinha que atravessa paredes (P0-1), que vai sair.
- **Proposta:** o host envia `damage_applied(target, amount, spell_key, killed)` reliable ao atacante. No cliente: marcador na mira com cor do elemento e um X maior no abate, som de acerto distinto do de levar dano e número flutuante (já existe `Settings.show_damage_numbers`). Status aplicado (queimou, lento, chocado) aparece como ícone curto junto do número.
- **Esforço:** M.

### P0-4. O round e a partida terminam sem dizer quem ganhou e por quê
- **Problema:** o `ROUND_END` mostra apenas "Fim do round". O motivo (`kill`/`hp`/`core`/`draw`/`forfeit`) só vai para o log. O painel final mostra o id cru (`score`) e o placar como `a × b` sem nomes. O nome do overtime aparece como id cru (`sudden_death`). Um espectador vê "Derrota" porque `winner_id != me`.
- **Evidência:** `scenes/net/net_match.gd:446-449`, `:550`, `:553`; `autoload/match_state.gd:208-211`; spec 02 §5 ("nome da regra aparece em destaque por 2 s", não feito).
- **Impacto:** perder por "HP no overtime" ou por "Núcleo no desempate" sem ver a regra parece bug. O alpha é para amigos entenderem o jogo, e hoje a regra é invisível.
- **Proposta:**
  - Banner de round (2,5 s): "VOCÊ VENCEU O ROUND / Abate · Mais HP (62 × 40) · Núcleo no desempate · Empate", com o placar animando.
  - Banner de overtime (2 s) com nome traduzido e uma linha de regra ("Morte Súbita: 1 HP, primeiro acerto vence").
  - Resultados com nomes, placar por round (elemento de cada um + motivo) e "Vitória de X" para espectador e servidor.
  - Tabela única de nomes pt-BR para ids (`breath`→Fôlego, `sudden_death`→Morte Súbita, `fire`→Fogo), usada no HUD, no draft, no Tab e nos resultados. Hoje `hud.gd:67,71`, `net_match.gd:625,661` também mostram ids crus.
- **Esforço:** M.

### P0-5. O draft pede decisões sem informação
- **Problema:** as cartas de elemento mostram só o nome. As runas aparecem como ids em inglês (`cold_blood`, `echo`) sem descrição. O Grimório lista parâmetros crus (`homing_deg: 15.0`, status `burn`).
- **Evidência:** `scenes/net/net_match.gd:615-632`, `:442`; `scenes/ui/grimoire_screen.gd:51-60`.
- **Impacto:** o novato escolhe elemento e runa às cegas em 10 s. A contra-escolha (spec 02 §4.3), vendida como mecanismo de vantagem, não existe na prática se o jogador não sabe o que o elemento faz.
- **Proposta:**
  - Carta de elemento com 3 linhas: status ("Queimadura: dano contínuo"), ponto forte ("dano alto") e ponto fraco ("sem controle").
  - Botão de runa com nome pt-BR e efeito em uma linha. `RUNES` vira `Resource` com `display_name`/`description` (SDD §4.2 já prevê `data/runes/`).
  - Grimório com uma frase de descrição por variante, gerada a partir de uma tabela de textos, não dos `params`.
- **Esforço:** S–M.

### P0-6. Onboarding inexistente
- **Problema:** a primeira experiência é o menu, depois o lobby, e o draft em 10 s. O Treino não tem roteiro. As teclas 1–4 do treino estão só nas notas de release. Não há tela "Como jogar".
- **Evidência:** `scenes/sandbox/training.gd` (sem UI de instrução); `docs/release-notes.md` "Como jogar"; spec 06 §1 não define tutorial.
- **Impacto:** o grimório de 36 magias com 2 teclas é o pilar do jogo e também a maior barreira. Sem guia, o amigo convidado só aprende a Seta, o que reforça P1-1.
- **Proposta, em ordem de custo:**
  - (a) Cartão "Como jogar" (1 tela) no primeiro boot e no pause: gramática Q/E/R, rápida × confirmada, RMB, F.
  - (b) Treino com checklist lateral: "lance 1 magia de cada forma", "use uma confirmada", "acerte o boneco móvel com Orbe", "use Impulso". Elemento trocado por cartas na tela, não por teclas escondidas.
  - (c) Opcional: um boneco que revida (Seta a cada 2 s) para treinar Guarda e Impulso. O `--bot` já faz quase isso.
- **Esforço:** (a) S, (b) M, (c) M.

---

## P1 — deve entrar no alpha

### P1-1. Seta + RMB é estratégia dominante; a composição some
- **Problema:** a Seta tem o melhor dano por mana, a menor recarga, conjuração rápida e 45 m/s. O RMB repete sem teclas, então vira uma metralhadora no botão direito.

  | Magia (base) | Dano | Mana | Dano/mana | CD | Modo |
  |---|---|---|---|---|---|
  | Seta | 16 | 12 | **1,33** | **0,35 s** | rápida |
  | Leque | 20 | 18 | 1,11 | 1,2 s | rápida (6 m) |
  | Marca | 38 | 35 | 1,09 | 6 s | confirmada + 0,9 s |
  | Orbe | 28→10 | 30 | ≤ 0,93 | 2 s | confirmada |

  Com 100 de mana saem 8 Setas em 2,8 s. A regeneração fica pausada o tempo todo (pausa de 0,5 s > CD de 0,35 s).
- **Evidência:** `data/spells/*.tres`; `scenes/player/spell_composer.gd:139-147` (recast); `scenes/player/stats.gd:22,91-94`.
- **Impacto:** a decisão por round se resume a "Q Q, segura RMB, E E se apertar". Orbe, Semente, Marca, Aura e Muralha viram nicho. O pilar 1 do SDD ("Composição > memorização") não se sustenta em jogo real, e a métrica de tempo de composição mede pouco porque recast não entra.
- **Proposta (escolher uma, testar em playtest):**
  - (A) **Cargas na Seta:** 3 cargas, 1 a cada 1,2 s, mana 12. Cria ritmo e janelas legíveis ("ele gastou as 3").
  - (B) **Recast limitado a magias confirmadas.** O RMB volta a ser a ferramenta de "repetir a Marca" e não uma arma primária.
  - (C) Ajuste numérico mínimo: Seta 14 dano / 14 mana / CD 0,5 s.

  Recomendo (A)+(B). O alvo é Leque e Marca terem o melhor dano por mana, pagando em alcance ou telegrafia.
- **Esforço:** S (números) a M (cargas + HUD).

### P1-2. Elementos desbalanceados; o draft vira "lado A pega Fogo"
- **Problema:** Fogo tem ×1,15 mais Queimadura na Seta. Vento tem ×0,85 e status de empurrão, sem dano. Setas para matar 100 HP com 100% de acerto: **Fogo ~5** (18,4 + queimadura), Gelo 7, Raio 7, **Vento 8**. Vento gasta 96 de mana e não fecha o abate sem regenerar.
- **Evidência:** `data/elements/fire.tres`, `wind.tres`; spec 01 §3.
- **Impacto:** o draft não tem tabela de contra-escolha (nenhum elemento "responde" a outro), então a segunda escolha é só "o melhor que sobrou". A primeira escolha, que alterna por lado, vira a vantagem que decide rounds.
- **Proposta:**
  - Achatar os multiplicadores (Fogo 1,05 / Gelo 0,95 / Raio 1,0 / Vento 0,95) e dar identidade só pelo status e pelas variantes.
  - Dar ao Vento uma ferramenta de dano ou de abate, por exemplo a Seta aplicar empurrão leve, ou o Leque de Vento que joga contra parede causar +10.
  - Escrever na spec 01 uma **matriz de contra-escolha** leve (3–4 interações): Guarda de Vento anula Orbe/Seta; Aura de Gelo ignora lentidão; Muralha de Raio transparente contra Muralha opaca de Gelo; e assim por diante. Assim a contra-escolha tem conteúdo.
  - Medir a taxa de escolha e de vitória por elemento no alpha (P1-11).
- **Esforço:** S (números) + M (matriz e texto).

### P1-3. Morte Súbita apaga a vantagem de HP conquistada no round
- **Problema:** aos 0:00 os dois vão para 1 HP, sem olhar quem estava na frente.
- **Evidência:** `scenes/net/net_match.gd:505-511`; spec 02 §5. A regra de timeout do mesmo parágrafo diz o contrário ("vence quem tem mais HP").
- **Impacto:** quem jogou melhor por 90 s (90 × 10 HP) tem 1/3 de chance de o sorteio devolver a partida para uma moeda. Parece injusto e desincentiva jogar pela vantagem. A Guarda também quebra a regra "primeiro acerto": ela cria escudo depois do início, e a Guarda de Gelo dá 45.
- **Proposta:**
  - (A) Morte Súbita só entra se a diferença de HP for ≤ 15. Acima disso, sorteia entre Colapso e Maré.
  - (B) Mudar a regra para "HP atual × 0,3, mínimo 1", que mantém a ordem.
  - Em ambas, bloquear a Guarda durante a Morte Súbita (ou reduzir o escudo a 1 acerto) e documentar.
  - Anunciar a regra com banner (P0-4).
- **Esforço:** S.

### P1-4. Sobrecarga assimétrica entre host e convidado
- **Problema:** o contador de 3 magias só é decrementado em `_on_cast_requested` (caminho local). No host, o pedido do cliente passa por `_request_cast`, que cobra `mana_cost_for` (0 com sobrecarga) e **não** decrementa `overcharge_casts`. Com isso o convidado tem 10 s de magias grátis com +20% de dano sem limite, e o jogador que hospeda tem 3. No servidor dedicado, os dois ficam sem limite.
- **Evidência:** `scenes/net/net_match.gd:247-250` × `scenes/player/player.gd:385-390, 462-468`; spec 02 §4.2.
- **Impacto:** vantagem estrutural para quem entra como convidado, e um Núcleo muito mais forte do que o previsto: 10 s de Marcas grátis podem somar 150+ de dano.
- **Proposta:** decrementar no host em `_request_cast` (e em `_broadcast_spawn` no caminho do host) e replicar o contador no snapshot. Adicionar teste. Mostrar a sobrecarga **do oponente** no HUD ("Oponente: SOBRECARGA 2"); hoje ela não aparece (não é status).
- **Esforço:** S.

### P1-5. Morte simultânea não usa a regra de desempate
- **Problema:** `MatchFsm.both_died()` existe e está testado, mas ninguém o chama. `Stats.died` leva direto a `report_death`. Na morte simultânea (tick do Colapso, Marca + reflexo da Guarda de Fogo), perde quem é processado primeiro, ou seja, a ordem dos nós (host primeiro).
- **Evidência:** `scenes/match/match_fsm.gd:148-154`; `scenes/net/net_match.gd:126`; `scenes/match/collapse_zone.gd:129-139`.
- **Impacto:** o resultado de rounds decisivos no Colapso fica viciado a favor de um slot.
- **Proposta:** acumular as mortes do frame no host e resolver em `_physics_process` (1 morte → `player_died`; 2 → `both_died(hp_before)`), guardando o HP antes do tick.
- **Esforço:** S.

### P1-6. O Núcleo Arcano ignora a arena
- **Problema:** o Núcleo sempre nasce em `(0, 3, 0)` ("on top of Arena A's central pillar"), mas não existe rampa no pilar. A captura mede distância no plano XZ (raio 2 m) e o pilar tem meia largura de 1,5 m. Na A se captura do chão, encostado no pilar, com o cristal flutuando 3 m acima. Na B ele flutua sobre a caixa alta. Na C fica sobre a espinha, em vez de "numa fresta", e dá para capturar dos dois lados do muro ao mesmo tempo, sem linha de visão.
- **Evidência:** `scenes/net/net_match.gd:479`; `scenes/match/arcane_core.gd:64-66`; `scenes/arena/arena_builder.gd:23,37,50`; spec 03 §4.
- **Impacto:** o objetivo central não lê como objetivo. O "rei da colina" do Claustro, que dava identidade à arena, não existe.
- **Proposta:** `ArenaBuilder` exporta um marcador `CoreSpot` por variante:
  - A: topo do pilar com rampa curta de 1 m de largura, em um lado só, espelhada.
  - B: centro aberto, com a caixa alta deslocada.
  - C: dentro da fresta sul (e a do norte fica fechada no round, ou alterna).

  A captura passa a considerar Y (cilindro de 2 m × 2,5 m).
- **Esforço:** M.

### P1-7. "Desistir" desconecta e faz o oponente esperar 30 s
- **Problema:** o botão Desistir chama `Net.close()`. O host vê desconexão, entra em `PAUSED` por 30 s e só então dá W.O. Se quem desiste é o host, o convidado cai no menu sem resultado.
- **Evidência:** `scenes/ui/pause_menu.gd:91-96`; `scenes/net/net_match.gd:57`; `scenes/match/match_fsm.gd:176-181`.
- **Impacto:** a pior experiência possível para quem ganhou.
- **Proposta:** RPC `request_forfeit` leva a `fsm.forfeit(id)` imediato, com resultados para os dois, e só depois fecha a conexão. Host que sai com convidado presente: mostrar "O host encerrou a partida" com o placar.
- **Esforço:** S.

### P1-8. A primeira escolha do round decisivo é determinística (favorece o host)
- **Problema:** `north_id = players[0]` no round 1 (menor id = host) e alterna depois. Sem empates, os rounds 1, 3, 5 e **7 (decisivo)** têm o host como lado A. Isso dá 4 primeiras escolhas contra 3.
- **Evidência:** `scenes/match/match_fsm.gd:67, 272-273`; spec 02 §3.
- **Impacto:** com P1-2 não resolvido, a primeira escolha vale muito, e o round mais importante sempre favorece o mesmo slot.
- **Proposta:** sortear o norte do round 1 (e mostrar a moeda). No decisivo, a primeira escolha vai para quem perdeu o round 6, o que é coerente com o catch-up. Documentar na spec 02 §6.
- **Esforço:** S.

### P1-9. O HUD de combate não mostra o estado do duelo
- **Problema:** não há barras dos dois jogadores no topo (o HUD da spec 06 §2 mostra `[P1 ●●●○] 1:12 [○○●● P2]`). O placar está num `Label` de texto. O elemento e a runa do oponente só aparecem no Tab. A barra do Núcleo recebe progresso a 1 Hz. Falta o marcador rápida × confirmada por opção de efeito.
- **Evidência:** `scenes/net/net_match.gd:420-454`; `autoload/match_state.gd:86-88`; `scenes/ui/crosshair_wheel.gd` (sem marcador); spec 06 §2.
- **Impacto:** o jogador não sabe se está ganhando a troca, e espectador e stream não têm o que ler.
- **Proposta:** faixa superior com pips de rounds, relógio, elemento/runa de cada lado e barra de HP+escudo de cada um (substitui a plaquinha de P0-1). O progresso do Núcleo é calculado no cliente a partir do snapshot ou enviado a 10 Hz. Os marcadores ⚡/◎ ficam na roda.
- **Esforço:** M.

### P1-10. Morte sem câmera de morte nem replay
- **Problema:** a spec 05 §5 pede câmera orbitando o corpo por 3 s. A spec 02 §2 pede "replay da câmera do killer" no `ROUND_END`. Nenhum dos dois existe: os braços só somem.
- **Evidência:** `scenes/player/first_person_arms.gd:77-85`; ausência no `net_match.gd`.
- **Impacto:** quem morre não entende de onde veio o golpe, e o momento de virada fica sem clímax.
- **Proposta para o alpha:** em vez de replay (L), câmera de morte em 3ª pessoa olhando para o killer por 2,5 s, com um cartão "Abatido por Orbe de Fogo (28)" que usa o `damage_applied` de P0-3. O replay fica fora da v1 (mover para SDD §8).
- **Esforço:** M.

### P1-11. Telemetria local para o alpha
- **Problema:** o objetivo de um alpha fechado é aprender, mas as estatísticas atuais só aparecem no painel e depois somem.
- **Evidência:** `autoload/match_state.gd:13-14, 153-169`.
- **Proposta:** o host grava `user://matches/<data>.json` com, por round: elementos, runa, arena, motivo do fim, duração, dano por magia, casts por magia, tempo de composição e overtime sorteado. Com 20 partidas, P1-1, P1-2 e P1-3 deixam de ser opinião.
- **Esforço:** S.

---

## P2 — depois do alpha ou em paralelo

### P2-1. Inconsistências de documentação (GDD × código)
| Onde | Diz | Realidade | Ação |
|---|---|---|---|
| `docs/SDD.md:7` §1 | "apertando até 3 hotkeys (Elemento → Forma → Efeito)" | 2 teclas, elemento fixo (decisão travada no §2) | Corrigir a visão |
| SDD cabeçalho | "Versão 0.1 … rascunho" | v0.3.1 publicada | Versionar o SDD |
| SDD §4.2, spec 01 §4 | `data/forms`, `effects`, `runes`, `overtime` como `.tres` | Pastas vazias; runas em `MatchFsm.RUNES` + `Player.apply_rune` | Decidir: ou dados, ou atualizar a spec |
| spec 02 §2 | `ROUND_END` com replay | Só texto | Ver P1-10 |
| spec 02 §3 | Runa por 20 s | Encerra ao B escolher | Ver P0-2 |
| spec 02 §3 | "Runa do oponente oculta" | As **ofertas** do perdedor vão para os dois (`match_state.gd:190`) | Enviar ofertas só ao dono |
| spec 02 | Empate de round | Não diz se há runa após empate (código: ninguém recebe) | Documentar |
| spec 03 §4 | Núcleo no pilar com rampa (A) e na fresta (C) | Fixo em (0,3,0) | Ver P1-6 |
| spec 03 §5 | `arena_base.tscn` + herança + `tools/build_arena.gd` | `ArenaBuilder.LAYOUTS` + `variant` | Atualizar a spec |
| spec 04 §1 | "espectador fica fora de v1" | Espectador implementado (v0.2.1) | Atualizar |
| spec 05 §3 | Tiro na cabeça ×1,5 para Seta/Orbe | Não implementado | **Decidir**: recomendo remover. Com projétil lento e 1 vida, tiro na cabeça aumenta variância sem aumentar leitura |
| spec 05 §4 | Poses de mão aberta/punho/palma | Viewmodel de cajado com uma mão (v0.3.0) | Atualizar |
| spec 06 §1 | "Revanche" nos resultados | "Voltar ao lobby" | Renomear ou implementar revanche direta |
| spec 06 §2 | Trilha de 3 caixas sob a mira | Roda na mira (`crosshair_wheel.gd`) | Atualizar com a roda + marcador ⚡/◎ |
| spec 06 §3 | Modo Segurar, forçar confirmação, cor aliado/inimigo, brilho, outline, tremor, voz | Ausentes em `settings.gd` | Cortar para v1 ou pôr no roadmap |
| spec 01 §3 | Orbe de Gelo "atrito baixo"; Aura de Gelo "+15 regeneração de escudo" | Lentidão; escudo único de 15 | Ajustar o texto à implementação |
| `docs/release-notes.md:12` × `data/elements/storm.tres` | "Tempestade" | "Raio" no jogo | Escolher um nome |
| `docs/release-notes.md:71` | "braços ainda não aparecem; sem animação" | Resolvido em 0.2.0/0.3.0 | Limpar as limitações |
| HANDOFF §6/§7 | M7 "sem commit", próximos passos de M6 antigos | Commits feitos até v0.3.1 | Atualizar o status |

**Esforço:** S (documentação).

### P2-2. Rodada decisiva e arenas: decisão do perdedor
Hoje as arenas seguem a rotação A→B→C. Proposta: **o perdedor do round anterior escolhe a arena do próximo round** entre as 2 que não foram jogadas por último. É um segundo catch-up com decisão (não um bônus numérico) e dá sentido à identidade das arenas (P2-4). Esforço: S.

### P2-3. Pool de runas com variância alta
Algumas ofertas vêm só com runas fracas (Passo Leve, Foco, Sangue Frio). Eco e Fôlego escalam com o meta da Seta (Eco: 12 Setas por barra de mana). Proposta: ofertas estratificadas (1 ofensiva, 1 defensiva, 1 utilitária). Reavaliar Eco depois de P1-1. Casca 25 dura 999 s: documentar que dura o round inteiro. Esforço: S.

### P2-4. Identidade das arenas × elementos (documentar e reforçar)
Leitura atual do layout (`arena_builder.gd:20-62`):
- **A Claustro:** aberta, pilar 3×3 central, pares de caixas nos quadrantes. Favorece Seta de Raio (70 m/s) e Muralha opaca de Gelo. Com o Núcleo no topo (P1-6), vira arena de disputa vertical.
- **B Pátio Partido:** barras de 1,4 m a 11 m dos spawns (o jogador agachado some atrás delas), centro quase vazio. Favorece Marca e Impulso. Capturar o Núcleo aqui é arriscado, e esse risco é bom.
- **C Espinha:** espinha de 2,5 m com 2 frestas de 1 m. Favorece Leque, Semente de Fogo (zona de 3,5 m fecha um corredor) e Marca por cima do muro. O Teleporte de Raio "sem travessia" perde valor. O Colapso final de 5 m fica **cortado pela espinha**, o que tende a empurrar decisões para o timeout de HP. Considerar remover o segmento central da espinha durante o Colapso ou deslocar o centro do círculo.

Faltam **marcos visuais por lado**: estandartes e braseiros (M7 aberto) com cor norte/sul, para orientação e callouts entre amigos ("tô no balcão leste"). Registrar esta tabela arena × elemento na spec 03. Esforço: S (doc) + M (marcos).

### P2-5. Tempo morto e ritmo
Estimativa por round: draft 6–20 s + contagem 3 s + combate ~30–60 s + 3 s de fim. **Partida típica de 7–10 min**, o que é bom para o alpha. O pior caso (7 × 176 s) passa de 20 min. Sugestões:
- Draft de 8 s + 8 s.
- Quem não está escolhendo vê a carta do oponente "pensando".
- Contagem mostrando os elementos lado a lado ("Fogo × Gelo").
- Empates de round (raros) não geram runa: documentar.

Esforço: S.

### P2-6. Ganchos de progressão para o alpha (leves, sem economia)
- Histórico local de partidas (reusa P1-11) com recordes: menor tempo de composição, maior dano em um round.
- Contagem de magias usadas no Grimório ("você já usou 23/36"), um incentivo direto ao pilar 1.
- Títulos cosméticos no nome ("Piromante" com 10 rounds vencidos de Fogo).

Esforço: M.

### P2-7. Valor para espectador
Espectador existe mas vê só o texto do placar. Propostas:
- HUD de espectador com as duas barras (P1-9), mana, elemento, runa e recargas 3×3 de cada jogador.
- Feed de magias ("A: Marca de Gelo → B −34").
- Contorno dos jogadores através de paredes **só para espectador**.

Esforço: M.

### P2-8. Nome padrão "Mago" para os dois jogadores
O nome padrão é `"Mago"` (`autoload/settings.gd:25`). A reconexão identifica o slot pelo nome exato (spec 04 §10). Verificar se o host rejeita ou sufixa nomes duplicados. Senão, placar e reconexão ficam ambíguos. Proposta: sufixo automático "Mago 2". Esforço: S.

---

## Análise do core loop

**A gramática funciona.** Elemento fixo + Forma + Efeito é aprendível em 2 minutos com a roda e escala bem, porque as 9 magias por round formam 3 papéis claros: pressão (Seta/Leque), posicionamento (Orbe/Semente/Marca/Muralha) e reação (Guarda/Impulso/Aura). A regra "reação é rápida, posicionamento é confirmado" é boa e legível.

**Densidade de decisão:** a cada 1–2 s o jogador escolhe magia × orçamento de mana × posição. É alta no papel, mas desaba com P1-1: se a Seta via RMB é ótima, a decisão vira mira pura. Com cargas na Seta e recast só em confirmadas, cada decisão volta a ser "gasto a janela agora ou guardo mana para a Marca".

**Contrajogo existente (bom):**
- Marca com anel visível e atraso de 0,9 s.
- Círculo rúnico aceso durante a mira.
- Impulso com i-frames de 0,1 s.
- Guarda de Vento que desvia um projétil.
- Muralha que bloqueia.

**Contrajogo fraco:**
- Magias rápidas não têm telegrafia útil (forma e efeito saem em ~100 ms).
- Não há como ler a mana ou as recargas do oponente. Sugestão: no modelo em 3ª pessoa, o cajado brilha quando a mana está cheia, uma leitura barata.

**Expressão de habilidade:** mira em projétil lento, velocidade de composição (já medida), gestão de mana, timing do Núcleo e combos entre elementos:
- Raio: choque e depois Marca.
- Gelo: Marca prende e o Orbe acerta.
- Vento: Marca lança e as Setas acertam no ar.

Vale destacar esses combos no Grimório: eles são os **momentos de virada** do jogo.

**Snowball:** não existe (reset total por round + runa do perdedor), o que é correto para MD7 entre amigos. O risco oposto (catch-up forte demais) é baixo, porque as runas são suaves. O Núcleo é a única vantagem intra-round e hoje é forte demais para o convidado (P1-4).

---

## Onde espero discordar de tech/balance/UX

1. **Wallhack × informação de HP (UX):** proponho tirar a plaquinha do mundo e pôr as barras dos dois no topo. O UX pode defender a plaquinha pela leitura imediata. Minha posição: HP visível é ok (jogo de luta), **posição** visível não. Aceito uma plaquinha com teste de profundidade, desde que só apareça com linha de visão.
2. **Cargas na Seta e recast restrito (balance/UX):** o balanceamento pode preferir só mexer em números (opção C) para não mudar o input. O UX pode ver o RMB como acessibilidade. Troca: números preservam o hábito e deixam a Seta ótima sob outro limiar; cargas mudam o ritmo e dão leitura ao oponente. Proponho testar as duas no alpha com a telemetria de P1-11.
3. **Achatar os multiplicadores de elemento (balance):** remove sabor ("Fogo bate forte"). Alternativa aceitável: manter Fogo 1,15 mas sem queimadura na Seta, ou dar ao Vento a única Seta com status.
4. **Morte Súbita condicional (design do usuário, SDD §2):** o overtime aleatório é decisão travada do usuário. Minha proposta muda a *condição*, não o sorteio, mas precisa de aprovação dele.
5. **Replay × câmera de morte (tech):** o replay do killer (spec 02) é caro com o netcode atual (L). Defendo cortar para a v1 e fazer a câmera de morte com cartão de dano. O tech pode querer manter o escopo para não abrir exceção na spec.
6. **Tiro na cabeça (balance):** recomendo remover da spec. Quem vem de FPS vai sentir falta. Troca: menos variância e melhor leitura contra recompensa de mira.
7. **Núcleo com altura e rampa (tech/level design):** a captura em cilindro e a rampa exclusiva mudam `ArenaBuilder` e os testes de simetria. O tech pode preferir manter a captura em XZ e só mover o marcador. Aceito, desde que o cristal fique na altura em que se captura.
8. **Perdedor escolhe a arena (design):** adiciona uma decisão ao draft já apertado (10 s). O UX pode achar carga cognitiva demais para novatos. Alternativa: só a partir do round 3.
9. **Prioridade de onboarding (produção):** coloquei o "Como jogar" + roteiro de treino em P0. Para um alpha "entre amigos" alguém pode dizer que o host explica pessoalmente. Discordo: o alpha deve medir se o jogo se explica sozinho, e o custo de (a) é S.
10. **Telemetria (tech):** gravar JSON no `user://` do host é simples, mas levanta a questão de privacidade e coleta. Para alpha fechado, com aviso no lobby, considero aceitável.
