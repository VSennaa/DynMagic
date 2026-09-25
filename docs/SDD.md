# DynMagic — Software Design Document

Versão 0.1 · 2026-09-24 · Status: rascunho para revisão

## 1. Visão

Arena 1v1 de magia dinâmica em primeira pessoa. O jogador não escolhe magias prontas: ele **compõe** cada magia em tempo real, apertando até 3 hotkeys em sequência (Elemento → Forma → Efeito), e dispara com o botão do mouse. O elemento é travado no início de cada round num draft rápido. Partidas são melhor de 7 rounds em arenas pequenas inspiradas no Skirmish do Valorant, jogadas em LAN.

Pilares:

1. **Composição > memorização.** 1 elemento por round + 2 teclas = 9 magias no round, 36 no total, derivadas de regras e não de uma lista.
2. **Leitura clara.** Cada combinação tem silhueta, cor e som distintos. O oponente precisa ler o que vem só pela conjuração.
3. **Rounds curtos e decisivos.** 1 vida por round, 90 s, overtime com regra aleatória.
4. **Estética.** Mistura da energia de Bleach (contraste, trilhas de reiatsu, cortes limpos) com a magia desenhada de Witch Hat Atelier (glifos, círculos rúnicos, tinta). Renderização cartoon estilo Sea of Thieves: toon shading, cores saturadas, nada realista.

## 2. Decisões tomadas

| Tema | Decisão | Origem |
|---|---|---|
| Engine | Godot 4.7.2, GDScript | Usuário |
| MCP | Godot AI (hi-godot/godot-ai) v4.2.3: plugin no editor ao vivo, 46 tools. Substitui o Coding-Solo/godot-mcp | Usuário |
| Câmera | 1ª pessoa, braços visíveis | Usuário |
| Gramática | 3 slots: Elemento, Forma, Efeito. 4 elementos. Sempre 1 elemento por round, que preenche o slot 1. O jogador aperta 2 teclas (forma, efeito) | Usuário |
| Draft | Em ordem: lado A escolhe, depois lado B. Sem elemento repetido. A primeira escolha alterna a cada round | Usuário |
| Conjuração | Magias rápidas disparam ao completar a sequência. Magias de posicionamento pedem confirmação no `LMB`. Hotkeys `Q`/`E`/`R`, `F` cancela, `RMB` repete ou cancela | Usuário |
| Vantagem | Runa para quem perdeu + Núcleo Arcano. Sem segundo elemento | Usuário |
| Overtime | Sorteado entre Colapso, Morte Súbita e Maré de Mana. O host pode fixar uma regra | Usuário |
| Personagem | Um único mago base. A identidade vem do elemento | Usuário |
| Formato | Rounds (MD7, primeiro a 4) + draft na fase 0:00 | Usuário |
| Rede | LAN, host-authoritative, ENet | Usuário (LAN) + proposta |
| Arte | Shader-first com placeholders estilizados; Blender + mcp-blender + Tripo numa fase posterior | Usuário |
| Arenas | 3 variantes (A, B, C) do layout da imagem de referência | Usuário |

## 3. Premissas

As premissas P1–P5 foram validadas em 2026-09-24 e passaram para a tabela da seção 2.

- **Q1 — Repetir o próprio elemento (resolvida).** Um jogador pode escolher o mesmo elemento do round anterior. A regra "sem repetir" vale só entre os dois jogadores no mesmo round.

## 4. Arquitetura

### 4.1 Visão geral

```
┌──────────────────────── Autoloads (singletons) ────────────────────────┐
│ Settings   Net   Lobby   MatchState   SpellDB   AudioBus   SceneRouter │
└────────────────────────────────────────────────────────────────────────┘
          │                 │                    │
   ┌──────▼─────┐    ┌──────▼──────┐      ┌──────▼───────┐
   │  UI layer  │    │  Match flow │      │  Arena scene │
   │ menus/HUD  │◄───│ (FSM, host) │─────►│ players,     │
   └────────────┘    └─────────────┘      │ spells, orb  │
                                          └──────────────┘
```

- **Host-authoritative.** O host roda a simulação de verdade: dano, mana, cooldown, estado de round. O cliente prevê o próprio movimento e o VFX local da conjuração.
- **Dados antes de código.** Elementos, formas, efeitos, runas e regras de overtime são `Resource` (`.tres`). A magia final é montada em runtime a partir das três partes.
- **Uma FSM por nível.** `SceneRouter` (telas), `MatchState` (partida), `SpellComposer` (sequência de teclas no jogador).

### 4.2 Estrutura de pastas

```
DynMagic/
├─ project.godot
├─ docs/                    SDD + specs
├─ autoload/                settings.gd, net.gd, lobby.gd, match_state.gd,
│                           spell_db.gd, audio_bus.gd, scene_router.gd
├─ data/
│  ├─ elements/             fire.tres, frost.tres, storm.tres, wind.tres
│  ├─ forms/                projectile.tres, self.tres, area.tres
│  ├─ effects/              direct.tres, burst.tres, lingering.tres
│  ├─ runes/                *.tres
│  └─ overtime/             collapse.tres, sudden_death.tres, mana_surge.tres
├─ scenes/
│  ├─ ui/                   main_menu, lobby, settings, draft, hud, results
│  ├─ arena/                arena_base.tscn, arena_a/b/c.tscn, core_orb.tscn
│  ├─ player/               player.tscn, fp_arms.tscn, spell_composer.gd
│  └─ spells/               spell_projectile.tscn, spell_area.tscn,
│                           spell_self.tscn, zone.tscn, wall.tscn
├─ shaders/                 toon.gdshader, outline.gdshader, rune_circle.gdshader
├─ vfx/                     partículas por elemento
├─ audio/
└─ tests/                   McpTestSuite: spell_resolution, match_fsm, net_serialization
```

### 4.3 Fluxo de telas

```
Boot ─► Menu Principal ─┬─► Hospedar ─► Lobby ─► Partida ─► Resultados ─► Lobby/Menu
                        ├─► Entrar (LAN browser) ─► Lobby
                        ├─► Treino (vs boneco, offline)
                        ├─► Configurações
                        └─► Sair
```

### 4.4 Fluxo de partida

```
Lobby ─► Carregar arena ─► [Round N]
  Draft 0:00 (20 s: A escolhe, B escolhe) ─► Contagem 3-2-1 ─► Combate 90 s ─┬─► Morte ─► Fim do round
                                                        └─► 0:00 ─► Overtime ─► Fim do round
Fim do round ─► placar 4? ─não─► Round N+1
                          └sim─► Resultados
Placar 3-3 ─► Round decisivo (arena sorteada, runa para ambos)
```

## 5. Índice de specs

| # | Spec | Conteúdo |
|---|---|---|
| 01 | [Sistema de magia](specs/01-spell-system.md) | Gramática, matriz 4×3×3, números, VFX |
| 02 | [Loop de partida](specs/02-match-loop.md) | FSM, draft, vantagem, overtime, placar |
| 03 | [Arenas](specs/03-arenas.md) | Layout base, variantes A/B/C, Núcleo Arcano |
| 04 | [Rede](specs/04-networking.md) | Topologia, descoberta LAN, sincronização, RPCs |
| 05 | [Controle do jogador](specs/05-player-controller.md) | Movimento FPS, câmera, vida/mana, hit |
| 06 | [UI, menus e configurações](specs/06-ui-settings.md) | Telas, HUD, settings persistidos |
| 07 | [Arte e pipeline](specs/07-art-pipeline.md) | Shaders, paleta, VFX, pipeline Blender futuro |
| 08 | [Ferramentas e setup](specs/08-tooling.md) | Godot 4.7.2, MCP Godot AI, testes, build |

## 6. Roadmap

| Marco | Entrega | Critério de pronto |
|---|---|---|
| M0 Setup | Projeto Godot, MCP ligado, autoloads vazios, CI local de testes | `test_run` do Godot AI passa com 0 falhas |
| M1 Sandbox | Movimento FPS, SpellComposer, 1 elemento com as 9 magias, boneco de treino | Todas as 9 magias funcionam offline |
| M2 Grimório | 4 elementos, 36 magias, HUD de composição, VFX placeholder | Teste de resolução cobre as 36 combinações |
| M3 Rede | Host/entrar por IP, descoberta LAN, 2 jogadores se movendo e conjurando | 2 instâncias locais jogam 5 min sem desync visível |
| M4 Loop | FSM de partida, draft, runas, Núcleo, overtime, resultados | Partida MD7 completa de ponta a ponta em LAN |
| M5 Arenas | 3 variantes com greybox final e colisão | Cada variante passa checklist de simetria e linhas de visão |
| M6 Polimento | Menus, configurações, áudio, shaders toon, VFX por elemento | Checklist de UX aprovado pelo usuário |
| M7 Arte | Pipeline Blender + mcp-blender + Tripo, personagem e props finais | Assets importados sem quebra de colisão e com outline |

## 7. Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| 36 magias difíceis de balancear | Alto | Números derivados de fórmula (forma × efeito × multiplicador de elemento). Balanceamento mexe em poucas tabelas |
| Composição lenta em 1ª pessoa | Alto | Conjuração rápida sem clique, recast no RMB, buffer de input de 150 ms, HUD de composição perto da mira |
| Proteção contra trapaça em LAN | Baixo | Host-authoritative basta para LAN |
| Leitura da magia inimiga em 1ª pessoa | Médio | Círculo rúnico colorido aparece na frente do conjurador durante a composição. Cor = elemento, forma do glifo = forma |
| Arte gerada por IA sem consistência de estilo | Médio | Arte final só no M7. Shader toon unifica o visual |

## 8. Fora de escopo (v1)

Matchmaking online, relay/NAT punch, ranking, mais de 2 jogadores, personagens múltiplos, monetização, replays.
