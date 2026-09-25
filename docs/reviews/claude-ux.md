# Revisão UX e game feel — DynMagic v0.3.1

Revisor: Claude (papel de designer de UX e game feel). Data: 2026-09-25.
Escopo: do exe até o fim da primeira partida, pensando num amigo que nunca viu o jogo, com olhar de FPS competitivo (Valorant, CS2, Spellbreak, Witch It).
Base: `docs/HANDOFF.md`, `docs/SDD.md`, specs 01, 02, 05 e 06, `docs/release-notes.md` e o código de `scenes/ui/*`, `scenes/player/*`, `autoload/audio_bus.gd`, `autoload/settings.gd` e `scenes/net/net_match.gd`. Revisão só de leitura: não rodei o jogo, e as linhas citadas são do commit `eb2ed56`.

Legenda: **P0** bloqueia o alfa fechado 1.0 · **P1** precisa entrar no alfa ou logo depois · **P2** polimento. Esforço: **S** (menos de meio dia), **M** (1 a 2 dias), **L** (3 dias ou mais).

---

## Resumo

A base está boa: a roda de composição na mira, a grade de recarga com os símbolos, a prévia de mira das magias confirmadas, o círculo rúnico que o oponente enxerga, as legendas de som e o menu de grimório já formam um sistema coerente. O que falta para um alfa com amigos:

1. O jogo **não ensina** nada na tela. Controles, draft e regras só existem nas notas de release.
2. **Não há confirmação de acerto** no PvP, nem feedback de morte ou de fim de round.
3. **Draft e placar mostram ids internos** (`cold_blood`, `sudden_death`, `fire`), e o painel do draft é reconstruído a cada segundo.
4. A plaquinha de HP do inimigo **aparece através das paredes**, o que na prática é um wallhack.

---

## P0 — bloqueiam o alfa

### P0-1. A plaquinha de debug do inimigo aparece através das paredes
- **Problema:** a Label3D sobre o oponente usa `no_depth_test = true`. Ela mostra HP, escudo e os ids crus dos status, e fica visível atrás de qualquer cobertura. Numa arena 1v1 isso revela a posição do inimigo o tempo todo e acaba com o jogo de cobertura e de som de passos.
- **Evidência:** `scenes/player/player.gd:420` (comentário "Debug nameplate… Replaced by the final HUD in M6"), `:424` (`no_depth_test = true`) e `:444` (texto `HP %d … burn slow`).
- **Impacto:** quebra o pilar competitivo e o pilar "Leitura clara". O jogador lê a plaquinha em vez do círculo rúnico.
- **Proposta:** remover o `no_depth_test`. Mostrar o nome do oponente e uma barra de HP curta só quando houver linha de visão (raycast barato a 10 Hz) e só perto da mira, como no Valorant. Status viram ícones coloridos com o símbolo do elemento. O modo espectador pode manter a versão atual.
- **Esforço:** S.

### P0-2. Não há onboarding: o jogador não sabe compor magias, fazer o draft nem quais são as regras
- **Problema:** nem no menu, nem no treino, nem no lobby há alguma tela que explique Q/E/R duas vezes, LMB para confirmar, RMB para repetir, F para cancelar, teclas 1–4 no treino ou 1–7 no draft. Tudo isso só existe em `docs/release-notes.md`. O Treino abre direto no Fogo, sem nenhum texto. As teclas 1–4 para trocar de elemento só aparecem nos comentários do código.
- **Evidência:** `scenes/ui/main_menu.gd:34-38` (sem "Como jogar"), `scenes/sandbox/training.gd:16-24` (HUD sem dicas), `scenes/sandbox/training.gd:5-10` (teclas 1–4 escondidas), `scenes/ui/hud.gd:77-81` (a única dica é "LMB confirmar · RMB cancelar" durante a mira).
- **Impacto:** o primeiro duelo vira "aperto tudo e vejo o que sai". O amigo que não leu o zip desiste em 2 minutos. A gramática Forma × Efeito, que é o pilar do jogo, fica invisível.
- **Proposta:**
  1. Uma tela **"Como jogar"** no menu principal, que abre sozinha na primeira execução: um cartão com a gramática em 3×3, os nomes das magias, marcas de rápida ou confirmada e as teclas lidas do InputMap.
  2. **Treino guiado** em 6 passos, com checkmarks num canto: Seta (Q,Q), Leque (R,Q), Orbe (Q,E + LMB), Guarda (E,Q), Muralha (R,R + LMB) e RMB para repetir. Depois disso vira o treino livre com a legenda "1–4 trocam o elemento".
  3. **Cartão de referência no Tab**: o placar ganha a grade 3×3 do elemento atual com os nomes e as teclas.
  4. Uma faixa de dicas rotativas no lobby enquanto espera o oponente.
- **Esforço:** M para (1)+(3), M para (2).

### P0-3. Não há confirmação de acerto nem de abate no PvP
- **Problema:** quando você acerta o oponente não acontece nada no seu lado: nem hitmarker, nem som, nem número. Os números de dano só existem no boneco de treino. O único som ligado a dano é o `hit`, que toca quando **você** apanha. Um abate só dispara o sino de fim de round, igual para quem ganhou e para quem perdeu.
- **Evidência:** `scenes/ui/hud.gd:182-186` (som só no dano recebido), `scenes/sandbox/training_dummy.gd:62` (a opção "Números de dano" só vale para o boneco), `scenes/net/net_match.gd:42` (sino genérico). A spec 04 §5 já prevê o RPC `damage_applied` "para hitmarker e número de dano", mas ele não foi implementado.
- **Impacto:** em FPS, sem hitmarker o jogo parece quebrado. Com projéteis lentos, Orbe em arco e zonas, o jogador não sabe se o dano entrou, se o escudo absorveu ou se a Guarda de Vento desviou.
- **Proposta:** o host envia `damage_applied(target, amount, spell_key, flags)` para o conjurador, com flags para headshot, escudo, desvio e abate. No HUD: um X na mira por 0,15 s (branco no corpo, amarelo no headshot, azul no escudo), um som curto de "tic" com pitch subindo em acertos seguidos, um número flutuante opcional (a opção já existe em Settings) e, no abate, um X vermelho maior com som próprio mais o texto "ABATE". Do lado da vítima, um vinheta vermelha rápida.
- **Esforço:** M.

### P0-4. O draft é ilegível e instável
- **Problema:**
  - As **runas aparecem pelo id interno** (`breath`, `cold_blood`, `light_step`…) e sem descrição: o perdedor escolhe no escuro.
  - O próprio elemento aparece cru: "Seu elemento: fire".
  - A linha de texto mostra "[escolhidos: fire, frost]" e "Runa (5-7): haste, echo".
  - Os cartões de elemento só trazem o nome. Não há status, identidade nem dica do que o elemento faz.
  - O painel inteiro é destruído e recriado **a cada `MatchState.changed`**, ou seja, a cada segundo do relógio. Um clique pode cair entre o `queue_free` e a recriação, e o foco do teclado se perde.
  - O texto diz "DRAFT 0:00", que é jargão de design, e não deixa claro quem escolhe primeiro nem por quê.
- **Evidência:** `scenes/net/net_match.gd:593-633` (reconstrução em `_update_draft_panel`), `:625` (`String(elements[me])`), `:631` (`String(rune)`), `:440-443` (linha de texto com ids), `autoload/match_state.gd:84-86` (broadcast a cada segundo). A spec 06 §1 pede relógio grande, "Lado A/B escolhendo" e cartões com o elemento travado.
- **Impacto:** é a primeira decisão da partida, com só 10 s, e a informação necessária não está na tela. A runa, que é o catch-up, perde o valor.
- **Proposta:** montar o painel uma vez e só atualizar o estado (disabled, relógio, destaque do turno). Cada cartão ganha a cor, o nome de exibição e uma linha de identidade, por exemplo "Queimadura: 4/s por 3 s · Muralha queima". Um selo "Oponente" marca o cartão travado. As runas saem de uma tabela de exibição (spec 02 §54: Fôlego, Pressa, Passo Leve, Casca, Foco, Eco, Sangue Frio) com ícone e uma linha de efeito. Um relógio grande pulsa nos últimos 3 s, com um aviso de que a escolha é aleatória se o tempo acabar. Criar um helper único, `DisplayNames` (elemento, runa, overtime, arena, status, forma), para eliminar todos os ids crus (ver P1-1).
- **Esforço:** M.

### P0-5. Morte e fim de round não têm feedback
- **Problema:** quando você morre, o cajado some e a câmera fica parada. Não aparece "Você morreu", não há câmera de morte e não se sabe quem venceu o round nem por quê. O ROUND_END dura 3 s com o texto "Fim do round". A spec 02 prevê "replay da câmera do killer" e a spec 05 §5 prevê uma órbita de 3 s em 3ª pessoa. Nenhum dos dois existe.
- **Evidência:** `scenes/player/first_person_arms.gd:85-86` e `:97` (só esconde o viewmodel), `scenes/net/net_match.gd:448-449` ("Fim do round"), `docs/specs/02-match-loop.md:19` e `docs/specs/05-player-controller.md:54-56`.
- **Impacto:** num MD7 de 1 vida, o fim do round é o momento de maior emoção, e hoje ele passa sem clímax. O jogador também não aprende o que o matou.
- **Proposta:** um banner central "ROUND 3 — VOCÊ VENCEU / PERDEU", com o motivo ("Abate com Orbe de Raio", "Tempo: mais HP", "Colapso") e o placar animado. Na morte, a câmera sobe para 3ª pessoa orbitando o corpo durante 2–3 s, com "Morto por X com Seta de Fogo (42 de dano)". Como MVP, basta o banner com o motivo e a magia final; a câmera pode vir depois.
- **Esforço:** S para o banner, M para a câmera de morte.

---

## P1 — importantes para o alfa

### P1-1. Ids crus e jargão em várias telas
- **Evidência:**
  - HUD de status: `scenes/ui/hud.gd:67` (`burn 2.3s`), `:71` (`runa: cold_blood`), `:73` (`SOBRECARGA 3`, sem dizer que são 3 magias).
  - Overtime: `scenes/net/net_match.gd:447` (`OVERTIME: sudden_death`).
  - Resultados: `:553` (motivo cru) e `:562` (`projectile 40%`).
  - Placar (Tab): `:661-663` (`fire + haste`, `arena A`).
  - Lobby: `scenes/ui/lobby_screen.gd:56` (`Overtime: random   Arena: rotation`).
  - Grimório: `scenes/ui/grimoire_screen.gd:53` (dump de `params` como `zone_radius: 3.5`) e `:55` (`Status do elemento: burn`).
- **Impacto:** passa a impressão de build de debug, e o jogador não entende status nem regras.
- **Proposta:** um mapa único de exibição, que pode ser um `DisplayNames.gd` ou `display_name` nos `.tres` de status, runas e overtime. Status no HUD como chips: ícone, nome em PT ("Queimando 2,3 s", "Lento", "Chocado: próximo dano +20%", "Invulnerável") e a cor do elemento. Tirar o dump de `params` do grimório e trocar por 2–3 linhas escritas à mão por magia.
- **Esforço:** M.

### P1-2. Não há feedback quando a magia é recusada (sem mana, em recarga, recusada pelo host)
- **Problema:** `cast_rejected` não tem nenhum ouvinte na UI. Apertar Q,Q sem mana não faz nada. A rejeição do host só gera um `push_warning`. Como o cliente já pagou mana e recarga localmente, a grade de recarga passa a mostrar uma magia "usada" que nunca saiu. A roda escurece opções em recarga mas não as que custam mais mana do que você tem, e nenhuma tela mostra o custo de mana.
- **Evidência:** `scenes/player/spell_composer.gd:13`, `:186-188` e `:199-201`; `scenes/net/net_match.gd:286-287`; `scenes/ui/crosshair_wheel.gd:62-68`; `scenes/ui/hud.gd:60-62` (barra de mana sem marca de custo).
- **Proposta:** ouvir `cast_rejected` no HUD: som de "error" (a amostra já existe em `audio_bus.gd:22`), a roda treme e aparece o texto "Sem mana" ou "Recarga 2,1 s". Na etapa de efeito, escurecer também as opções sem mana, e mostrar o custo como um trecho mais claro na barra de mana. Quando o host recusar, desfazer a recarga local e mostrar o motivo.
- **Esforço:** S para o feedback local, M para o estorno em rede.

### P1-3. A própria magia sai com atraso de um RTT
- **Problema:** online, o cliente pede o cast ao host e só cria o VFX e o som quando recebe `_spawn_spell`. O braço dá o "flash" na hora, mas o projétil e o som saem um RTT depois. A spec 04 diz que o cliente prevê o VFX local.
- **Evidência:** `scenes/player/spell_caster.gd:84-90` e `scenes/net/net_match.gd:224-228` e `:272-282`.
- **Impacto:** em LAN quase não se nota. No servidor dedicado por IP, que os amigos vão usar, 40–80 ms entre clicar e ver a Seta sair deixam o jogo "borrachudo". Magias rápidas são o núcleo do feel.
- **Proposta:** um spawn cosmético local imediato (só visual e som, sem colisão de dano), reconciliado pelo `_spawn_spell` do host, que substitui o fantasma ou o descarta em caso de rejeição. Se não der tempo, pelo menos tocar o som e o flash do círculo rúnico localmente na hora.
- **Esforço:** M/L.

### P1-4. O indicador de dano direcional aponta sempre para o oponente e dispara à toa
- **Problema:** a seta aponta para o `threat`, que é sempre o oponente. Ela não considera a origem real do dano (zona, muralha, colapso, queimadura). Pior: a seta e o som de dano disparam em qualquer queda de `hp + shield`, inclusive quando o **escudo expira** sozinho (Guarda, Aura) e quando a Morte Súbita zera o HP para 1.
- **Evidência:** `scenes/ui/hud.gd:52` e `:182-199`, `scenes/net/net_match.gd:509`.
- **Impacto:** a seta mente ("ele está ali") e ensina errado. Um som de dano sem dano confunde.
- **Proposta:** alimentar a seta pelo `damage_applied` de P0-3, com a posição da fonte. Usar arcos na borda da tela no estilo CS2/Valorant em vez de "▲". Ignorar quedas de escudo por expiração. Dar ao colapso um indicador próprio: borda roxa e o texto "Fora da zona".
- **Esforço:** S, depois de P0-3.

### P1-5. Rebind: conflitos desligam ações em silêncio, e os rótulos fixam Q/E/R
- **Problema:** se você liga uma tecla que já está em uso, a outra ação fica **sem tecla**, sem perguntar. A spec 06 §5 pede para perguntar. Um jogador pode perder o `slot_2` e não conseguir mais jogar. Os rótulos dizem "Slot 1 (Q)" mesmo depois do rebind, e o grimório fixa "Q/E/R". O slider de sensibilidade não mostra valor e usa radianos por pixel (0,0005–0,008), então quem vem do CS ou do Valorant não consegue reproduzir a própria sensibilidade. FOV e volumes também não mostram número.
- **Evidência:** `scenes/ui/settings_screen.gd:7`, `:46`, `:56-57`, `:60` e `:123-127`, `autoload/settings.gd:343-350`, `scenes/ui/grimoire_screen.gd:24` e `:28`.
- **Proposta:** usar um diálogo de troca ("E já está em Slot 2. Trocar?") que faz um swap real. Rótulos "Forma/Efeito opção 1", mais a tecla lida do InputMap (reaproveitar `CrosshairWheel.key_text`). Mostrar o valor numérico ao lado de cada slider. Para a sensibilidade, usar uma escala "CS2/Valorant" (converter `m_yaw` 0,022 × sens) ou pelo menos mostrar cm/360 a 800 DPI. Usar o mesmo `key_text` no grimório, na dica de mira (P1-8) e na tela "Como jogar".
- **Esforço:** S/M.

### P1-6. Fluxo de rede: sem IP do host, sem porta, sem motivo de desconexão
- **Problema:**
  - O host não vê o próprio IP em lugar nenhum. Com Radmin, ZeroTier ou VPS, o amigo precisa pedir por fora.
  - "Entrar por IP" usa sempre a porta 7777 e não aceita `ip:porta`, então um servidor dedicado com `--port N` é inacessível pela UI.
  - O campo de IP vem preenchido com `127.0.0.1`.
  - Quando o host sai, o cliente volta ao menu sem mensagem, e o mesmo vale durante a partida.
  - No resultado, se o host clicar em "Menu principal", o outro jogador é jogado no menu sem aviso.
  - "Voltar ao lobby" num listen server só muda a cena local, sem sincronizar e sem `MatchState.reset_for_lobby()`, e não existe a "Revanche" que a spec 06 §1 prevê.
- **Evidência:** `scenes/ui/play_lan.gd:39`, `:62`, `:69`; `scenes/ui/lobby_screen.gd:17` e `:31`; `scenes/net/net_match.gd:40` e `:565-571`; `autoload/net.gd:233-236`; `autoload/lobby.gd:109-119` (só o dedicado usa `return_to_lobby`).
- **Proposta:** no lobby do host, mostrar "Seu IP: 192.168.x.x · 7777" com um botão Copiar. Aceitar `host:porta` no campo de IP e deixar o campo vazio com um placeholder. Guardar em `SceneRouter` uma mensagem para o próximo menu ("O host encerrou a sala", "Oponente desconectou", "Versão diferente") e exibi-la num toast. Nos resultados, o botão "Revanche/Voltar ao lobby" chama `Lobby.return_to_lobby()` também no listen server e mostra quem já voltou. Também mostrar o nome da sala no lobby do cliente.
- **Esforço:** S cada item, M no total.

### P1-7. O HUD de partida não mostra o estado do oponente nem os eventos
- **Problema:**
  - O topo é uma única Label: "Round 3 Você 1 × 1 Oponente 1:12". Não há pips de rounds, **não mostra o elemento do oponente** (só no Tab, e cru) nem a própria runa de forma legível.
  - O Núcleo Arcano surge aos 30 s sem anúncio, e a barra de captura só aparece dentro do raio.
  - O overtime entra sem explicar a regra.
  - A contagem é "Prepare-se..." sem 3-2-1 grande nem som de largada.
- **Evidência:** `scenes/net/net_match.gd:46-54`, `:420-454` e `:472-488`; `scenes/ui/hud.gd:123-128` e `:202-205`. Compare com o layout da spec 06 §2 (`[P1 ●●●○] 1:12 [○○●● P2] OVERTIME: COLAPSO`).
- **Proposta:** uma barra superior com pips por jogador na cor do elemento de cada um, o relógio grande e o nome e símbolo do elemento inimigo. Anúncios centrais de 2 s com som: "NÚCLEO ARCANO SURGIU" (mais um marcador de direção na borda), "OVERTIME: COLAPSO — a zona fecha", "3 · 2 · 1 · DUELO!". A runa e a Sobrecarga viram chips com ícone ao lado das barras.
- **Esforço:** M.

### P1-8. A roda de composição não diz qual magia sai nem se ela é rápida ou confirmada
- **Problema:**
  - A spec 06 §2 pede um marcador de rápida (raio) ou confirmada (alvo) em cada opção de efeito, e ele não existe.
  - A roda não mostra o nome da magia ("Seta", "Orbe"), que é o vocabulário usado no grimório e nas legendas.
  - A dica "LMB confirmar · RMB cancelar" é fixa e em inglês.
  - A mira expira depois de 4 s e a sequência depois de 2,5 s, sem nenhum indicador.
  - A disposição Q no topo, E embaixo à esquerda e R embaixo à direita não bate com o teclado, onde Q, E e R ficam da esquerda para a direita.
- **Evidência:** `scenes/ui/crosshair_wheel.gd:13` (ANGLES), `:46-58` e `:61-75`; `scenes/ui/hud.gd:80-81` (o `_trail` fica sempre vazio, código morto); `scenes/player/spell_composer.gd:19-20`.
- **Proposta:**
  - Na etapa de efeito, cada setor ganha um marcador pequeno de raio ou alvo, e o nome da magia aparece sob a mira ("Orbe · mira + clique").
  - Setores num arco acima da mira: Q a 10 h, E a 12 h, R a 2 h, espelhando o teclado. Vale testar A/B com 3 pessoas.
  - Um anel de tempo que esvazia durante a mira e a composição.
  - A dica passa a usar `key_text` ("Clique esquerdo: lançar · Clique direito: cancelar").
- **Esforço:** S/M.

### P1-9. Tela de resultados fraca para o fechamento de uma MD7
- **Problema:**
  - O placar é montado com `score.values()`, que tem ordem indefinida, e não diz quem é quem.
  - O motivo aparece cru e a precisão é mostrada por forma com o id.
  - Não há histórico por round (elementos, quem venceu, como) nem "melhor magia".
  - A tela é um painel sobre a arena congelada, sem música ou som de vitória.
- **Evidência:** `scenes/net/net_match.gd:538-571`.
- **Proposta:** colunas "Você | Oponente" com nomes, uma linha por round (elemento dos dois, vencedor, motivo, ícone), um destaque ("Mais dano: Orbe de Raio, 180") e um som de vitória ou derrota. Como MVP: ordem fixa (você primeiro), textos em PT e a tabela de rounds.
- **Esforço:** M.

### P1-10. Configurações que a spec 06 promete e ainda faltam, com impacto no alfa
- **Problema:** faltam o modo janela sem borda, o brilho, o outline on/off, o **modo de composição Segurar**, o "forçar confirmação em todas as magias", as cores do círculo aliado e inimigo e "Restaurar padrão" por aba (só existe para as teclas). Os volumes aparecem com os nomes internos dos buses ("Master", "Music", "SFX", "UI"). O botão "Salvar" é redundante, porque "Voltar" também salva, e não existe Cancelar.
- **Evidência:** `docs/specs/06-ui-settings.md:44-50` comparado com `scenes/ui/settings_screen.gd:29-94` e `:98-108`.
- **Proposta para o alfa:** rótulos em PT com valor (Geral, Música, Efeitos, Interface), borderless, sem borda, e a opção Segurar. Esta última é barata no `SpellComposer` e ajuda muito quem vem de jogos com "hold to aim". O resto fica para P2. Organizar em abas (Vídeo, Áudio, Controles, Jogo, Acessibilidade) em vez de um scroll de 620 px.
- **Esforço:** M.

### P1-11. Grimório pouco didático
- **Problema:** é um bloco de texto com dump técnico. Não usa os símbolos do `SpellGlyph`, não tem prévia visual e não pode ser consultado durante a partida.
- **Evidência:** `scenes/ui/grimoire_screen.gd:41-60`.
- **Proposta:** uma grade 3×3 por elemento com os símbolos e os nomes. Ao clicar, um cartão com uma descrição curta escrita à mão, as tags (rápida ou confirmada, dano, mana, recarga, status) e as teclas. O mesmo componente é reaproveitado no cartão do Tab (P0-2.3).
- **Esforço:** M.

---

## P2 — polimento

| # | Problema | Evidência | Proposta | Esforço |
|---|---|---|---|---|
| P2-1 | A câmera é "seca": sem flinch ao tomar dano, sem kick de FOV ao lançar, sem balanço ao andar e sem impacto na aterrissagem. A opção "reduzir tremor" da spec não tem o que reduzir | `scenes/player/player.gd:103-114`; ROADMAP M6 ("No camera shake exists yet") | Flinch leve (≤1°) no dano, kick de FOV de 2° no cast, bob sutil, e a opção de reduzir tremor controlando tudo isso | S/M |
| P2-2 | A música provisória (pad) toca sem parar, inclusive no duelo, e cobre os passos | `autoload/audio_bus.gd:131-137` | Mutar ou baixar no combate; stinger no início e no fim do round | S |
| P2-3 | Sons de evento faltando: início do round, contagem, Núcleo surgiu ou capturado, overtime, composição do inimigo por perto | `scenes/net/net_match.gd:42` (só o sino) | Um sample por evento, usando as amostras Kenney já presentes | S |
| P2-4 | As legendas cobrem só os casts de magia. Passos, impactos, Núcleo e zona ficam de fora | `scenes/ui/hud.gd:208-217`, `scenes/ui/sound_caption.gd` | Estender o `AudioBus` com eventos de legenda genéricos | S |
| P2-5 | Duplicação e inconsistência de nomes: `ELEMENT_NAMES` fixo (e não usado no HUD) em vez de `ElementDef.display_name` | `scenes/ui/hud.gd:6`, `scenes/ui/sound_caption.gd:7` | Ler sempre o `display_name` | S |
| P2-6 | Idioma misturado: "Overtime", "Draft", "Round", "HP/MN", "LMB/RMB", "Slot", "Overlay", "Off", "host", "PRONTO/aguardando" | vários (`lobby_screen.gd:31,48`, `hud.gd:59,62`, `settings_screen.gd:7-8,44`) | Glossário decidido pelo usuário (ver a seção final). No mínimo "Mana" em vez de "MN" e botões do mouse por extenso | S |
| P2-7 | Notas de release desatualizadas ou contraditórias: "Tempestade" contra "Raio" no jogo; "Limitações: braços ainda não aparecem, sem música"; "(P/S/A, D/X/P)" | `docs/release-notes.md:12`, `:31`, `:69-73` | Revisar as notas a cada tag; o nome do elemento deve ser único (ver a seção final) | S |
| P2-8 | Código e textos residuais: comentário "Final layout arrives in M6", `_trail` sempre vazio, versão de fallback "0.2", header de `net_match.gd` "M3… arrives in M4" | `scenes/ui/hud.gd:3-4` e `:78-80`, `scenes/ui/main_menu.gd:40`, `scenes/net/net_match.gd:1-4` | Limpeza | S |
| P2-9 | A janela padrão de 1920×1080 em modo janela passa da tela de um monitor 1080p (barra de título e taskbar) | `autoload/settings.gd:31-32` e `:202-207` | Primeira execução em borderless ou tela cheia na resolução do desktop | S |
| P2-10 | Configurações abertas pela pausa cobrem a tela inteira com o backdrop, e a partida online continua | `scenes/ui/pause_menu.gd:101-108` | Overlay semitransparente sem o backdrop pintado quando for overlay | S |
| P2-11 | A tela Jogar LAN junta Hospedar e Entrar numa coluna longa, com o nome duplicado em Configurações. A sala sem nome fica em branco | `scenes/ui/play_lan.gd:20-47` | Duas abas, como diz a spec. Nome padrão da sala: "Sala de <nome>" | S |
| P2-12 | Bindings por `keycode`: em AZERTY, Q/E/R e WASD caem em lugares ruins | HANDOFF §5 ("Input bindings use keycode") | Usar `physical_keycode` com o rótulo pelo layout (`DisplayServer.keyboard_get_label_from_physical`) | S |
| P2-13 | O treino não mostra o DPS que a spec 06 §1 promete (o boneco já calcula `dps()`) | `scenes/sandbox/training_dummy.gd` | Um painel pequeno de DPS e último golpe | S |
| P2-14 | Daltonismo: a paleta recolore os elementos, mas a seta de dano, o HP em vermelho e o estado da grade dependem de cor e alfa | `scenes/ui/hud.gd:118-119`, `scenes/ui/cooldown_grid.gd:52-75` | Mudar também forma e padrão (a grade já tem número, então basta a seta ou o arco) | S |

---

## Primeiros 5 minutos (percurso de quem nunca jogou)

1. **Abre o exe**, passa pelo aviso do SmartScreen e cai no menu com a arena girando. Bonito. Não há "Como jogar" (P0-2).
2. **Jogar LAN:** digita o nome, cria a sala. O amigo em outra rede não acha a sala e o host não sabe o próprio IP (P1-6). Na mesma LAN funciona.
3. **Lobby:** vê "Overtime: random   Arena: rotation" (P1-1). Os dois clicam em Pronto e o host inicia.
4. **Draft, 10 s:** o painel pisca a cada segundo. As cartas não dizem o que o elemento faz. Quem perdeu o round vê `cold_blood` (P0-4). O tempo esgota e sai uma escolha aleatória.
5. **Contagem de 3 s:** aparece "Prepare-se..." (P1-7).
6. **Combate:** vê três setores apagados na mira. Aperta Q e aparecem os símbolos do efeito. Aperta Q de novo e a Seta sai. Acertou? Não sabe (P0-3). A plaquinha do inimigo atravessa a parede (P0-1). Aperta R,R: a mira pede clique, ele não clica, e depois de 4 s a magia some sem aviso (P1-8). Fica sem mana e as teclas "não funcionam" (P1-2).
7. **Morre:** o cajado some, "Fim do round", sino. Por quê? Com quê? (P0-5).

A meta para o alfa é que o jogador entenda os passos 4, 6 e 7 **sem** ninguém explicar pelo Discord.

---

## Ordem sugerida de execução

1. P0-1 (S) e o banner de P0-5 (S). São baratos e mudam a percepção na hora.
2. `DisplayNames` e o draft estável (P0-4 e P1-1).
3. `damage_applied`, hitmarker, abate e seta real (P0-3 e P1-4).
4. "Como jogar", o cartão no Tab e o treino guiado (P0-2).
5. Feedback de rejeição (P1-2), IP e porta mais mensagens de desconexão (P1-6), rebind com swap e sliders com valor (P1-5).
6. Barra superior e anúncios (P1-7), marcadores da roda (P1-8) e resultados (P1-9).
7. Previsão cosmética de cast (P1-3), antes de qualquer teste em VPS.

---

## Onde espero discordar de GDD/tech/balance

- **GDD — 10 s por lado no draft.** Para veteranos é ótimo. Para o alfa com novatos, proponho 15 s no round 1 (ou na primeira partida do jogador) e cartões com uma linha de identidade. Suspeito que o GDD vá defender o ritmo. Meu argumento é que a primeira escolha, e a runa às cegas, hoje é aleatória na prática.
- **GDD — fim de round de 3 s.** Sem replay nem banner, 3 s é abrupto. Eu subiria para 4–5 s com recapitulação (motivo e magia final) e manteria o draft curto. O GDD provavelmente vai querer manter o total do round.
- **GDD — nomes e idioma.** "Raio" ou "Tempestade" (o id é `storm`, as notas falam Tempestade), "Leque" ou "Cone", "Overtime", "Draft", "Round". Defendo um glossário travado pelo usuário e aplicado a tudo (HUD, grimório, notas, legendas). Imagino que o GDD prefira manter o jargão de e-sports em inglês. Não tenho objeção a "Round", mas "Overtime: sudden_death" não passa.
- **GDD — disposição da roda.** Q no topo, E embaixo à esquerda e R embaixo à direita contradiz a ordem física das teclas. Proponho o arco superior Q-E-R da esquerda para a direita. A roda atual é recente e foi pensada como "trevo", então pode haver apego.
- **Tech — previsão cosmética de cast (P1-3).** A spec 04 já manda o cliente prever o VFX, mas a implementação optou pela simplicidade. Espero resistência por causa da complexidade de reconciliação e do custo de "fantasmas". Defendo pelo menos som e flash locais imediatos, porque o dedicado por IP vai expor o RTT.
- **Tech — plaquinha sem depth test (P0-1).** Pode ser vista como "debug inofensivo" ou como algo útil para testar. Para mim é bloqueante: é informação de posição de graça num 1v1.
- **Tech — `damage_applied` reliable para cada hit.** Pode preocupar pelo tráfego com Semente e Muralha dando ticks. Proposta: agregar os ticks por 100 ms num único evento, que também serve às legendas e às estatísticas.
- **Balance — overtime aleatório por padrão.** Três regras diferentes (Colapso, Morte Súbita, Maré de Mana), sem explicação na tela, são carga cognitiva demais para o alfa. Eu fixaria Colapso como padrão do lobby no alfa, deixando o host escolher Aleatório. Balance deve querer a variedade desde já.
- **Balance — runas com 7 opções e efeitos invisíveis.** Foco (+20% de velocidade do projétil) e Eco (recast −30%) não dão feedback perceptível. Eu mostraria o efeito ativo no HUD, por exemplo "Eco: recast −30%" no botão direito, ou cortaria para 5 runas com impacto sentido. Balance pode preferir manter o pool.
- **Balance — Choque consumido sem aviso.** O +20% do próximo dano recebido só funciona se o atacante souber que o alvo está chocado. Isso pede um ícone sobre o inimigo, o que puxa a plaquinha de volta com linha de visão (P0-1). Se balance não aceitar informação sobre o inimigo, o Choque perde a razão de existir.
