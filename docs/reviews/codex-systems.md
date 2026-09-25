# DynMagic — revisão de sistemas, balanceamento e QA da alfa fechada 1.0

Data: 2026-09-25. Revisão estática do workspace, após leitura de AGENTS, HANDOFF, SDD, specs 01–08 e ROADMAP. Escopo: amigos, 1v1, três duelos simultâneos em VPS Linux de 1 vCPU/~900 MB compartilhados. Apenas este relatório foi escrito; HANDOFF foi preservado por instrução explícita desta revisão. A alteração preexistente em `scenes/ui/lobby_screen.gd` não foi editada.

## 1. Tabela dos números reais

Valores sem runa, Aura, Sobrecarga, escudo ou choque prévio. HP/mana = 100/100; regeneração = 12 mana/s, suspensa por 0,5 s após **cada** cast, inclusive gratuito (`scenes/player/stats.gd:18`, `scenes/player/stats.gd:158`). Dano direto = base × elemento; parâmetros como DPS de zona **não** recebem esse multiplicador (`autoload/spell_db.gd:70`, `scenes/spells/zone.gd:47`).

**R** = rápida, sem preparação obrigatória: dispara ao completar a composição. **C** = confirmada, mira voluntária de 0 até 4 s e LMB. Ambas têm lockout posterior de 0,15 s; sequência incompleta expira em 2,5 s. Portanto 0,15 s não é tempo de carga do ataque. Tempos abaixo excluem digitação, latência e voo, salvo indicação. Fontes: `scenes/player/spell_composer.gd:19`, `scenes/player/spell_composer.gd:180`, `scenes/player/spell_composer.gd:196`.

Mana/CD/modo das nove bases conferem com spec 01 §2/2.1. Fontes exatas: `data/spells/projectile_direct.tres:13`, `projectile_burst.tres:13`, `projectile_lingering.tres:13`, `self_direct.tres:13`, `self_burst.tres:13`, `self_lingering.tres:13`, `area_direct.tres:13`, `area_burst.tres:13`, `area_lingering.tres:13` (todos sob `data/spells/`). Variantes: `data/elements/fire.tres:10`, `frost.tres:10`, `storm.tres:10`, `wind.tres:10` (todos sob `data/elements/`).

| Elemento | Forma/efeito — magia | Dano efetivo sem buffs | Mana | CD s | Cast/mira | Alcance / velocidade | Raio / dimensão | Duração e comportamento real |
|---|---|---:|---:|---:|---|---|---|---|
| Fogo | Projétil/direto — Seta | 18,4 + burn | 12 | 0,35 | R | 45 m/s; ~112,5 m antes de expirar | Raycast sem espessura | Voo 2,5 s; burn 4/s por 3 s |
| Gelo | Projétil/direto — Seta | 14,4 | 12 | 0,35 | R | 45 m/s; ~112,5 m | Raycast | Voo 2,5 s; slow 30% por 1,5 s |
| Raio | Projétil/direto — Seta | 16 | 12 | 0,35 | R | 70 m/s; ~175 m | Raycast | Voo 2,5 s; **não aplica choque** |
| Vento | Projétil/direto — Seta | 13,6 | 12 | 0,35 | R | 45 m/s; ~112,5 m de trajetória | Raycast | Curva total 15°, até 90°/s rumo à mira atual; **sem knockback** |
| Fogo | Projétil/explosivo — Orbe | 32,2 → 11,5 | 30 | 2 | C | 22 m/s; 30 m (~1,36 s) | Explosão 3 m; chão 2,4 m | Chão 8/s por 2 s (~16 total), sem burn de status |
| Gelo | Projétil/explosivo — Orbe | 25,2 → 9 | 30 | 2 | C | 22 m/s; 30 m | 3 m; chão 2,4 m | Chão por 3 s; slow 30%, aplicações a cada 0,5 s; **sem baixo atrito** |
| Raio | Projétil/explosivo — Orbe | 28 → 10; secundário 8 | 30 | 2 | C | 22 m/s; 30 m; busca secundária 8 m | 3 m | Secundário somente em alvo fora da lista da explosão; sem choque |
| Vento | Projétil/explosivo — Orbe | 23,8 → 8,5 | 30 | 2 | C | 22 m/s; 30 m | 3 m | Impulso horizontal de atração 6 m/s; dano calculado antes de deslocar o alvo |
| Fogo | Projétil/contínuo — Semente | Zona 8/s (~32 em 4 s) | 22 | 5 | C | 18 m/s; gravidade 14 m/s²; sem limite explícito de distância | 3,5 m | Voo até 5 s; zona 4 s; ticks 4 HP/0,5 s |
| Gelo | Projétil/contínuo — Semente | 0 | 22 | 5 | C | 18 m/s; g=14; voo até 5 s | 3,5 m | Zona 4 s; slow 50%/1,5 s aplicado a cada 0,5 s, duração acumula até 3 s |
| Raio | Projétil/contínuo — Semente | 0 | 22 | 5 | C | 18 m/s; g=14; voo até 5 s | 3,5 m | Zona 4 s; choque +20% no próximo hit, duração 3 s até 6 s; reaplica **a cada 0,5 s** |
| Vento | Projétil/contínuo — Semente | 0 | 22 | 5 | C | 18 m/s; g=14; voo até 5 s | 3,5 m; teste de altura <3 m | Zona 4 s; gira projéteis inimigos 35° em Y, uma vez por zona |
| Fogo | Pessoal/direto — Guarda | 0; reflete 20% do hit | 25 | 8 | R | Próprio jogador | Escudo 30 | 3 s; reflexão usa dano de entrada, inclusive parcela que excede escudo |
| Gelo | Pessoal/direto — Guarda | 0 | 25 | 8 | R | Próprio jogador | Escudo 45 | 3 s; bloqueia sprint enquanto escudo/guarda ativos |
| Raio | Pessoal/direto — Guarda | 0 | 25 | 8 | R | Próprio jogador | Escudo 30 | 3 s; quebra causada por receive_hit aplica choque no atacante |
| Vento | Pessoal/direto — Guarda | 0 | 25 | 8 | R | Próprio jogador | Escudo 30 | 3 s; primeiro hit de forma projétil é anulado e **todo escudo removido** |
| Fogo | Pessoal/explosivo — Impulso | Rastro 8/s por zona | 20 | 4 | R | 9 m / 0,18 s (~50 m/s) | 3 zonas de raio 1,2 m | I-frame 0,1 s; zonas 2 s nos pontos 1,5/4,5/7,5 m, criadas imediatamente |
| Gelo | Pessoal/explosivo — Impulso | 0 | 20 | 4 | R | 11 m / 0,18 s (~61,11 m/s) | Corpo | I-frame 0,1 s; parâmetro slide não é consumido |
| Raio | Pessoal/explosivo — Impulso | 0 | 20 | 4 | R | Teleporte até 9 m, limitado por colisão | Corpo | Movimento instantâneo; i-frame 0,1 s |
| Vento | Pessoal/explosivo — Impulso | 0 | 20 | 4 | R | 9 m horizontal / 0,18 s + velocidade Y 8 m/s | Corpo | I-frame 0,1 s; glide 1 s, gravidade de queda ×0,25 |
| Fogo | Pessoal/contínuo — Aura | +20% no dano via hit_amount | 30 | 14 | R | Próprio jogador | — | 6 s; não aumenta burn de status nem dano da Muralha |
| Gelo | Pessoal/contínuo — Aura | 0; concede 15 de escudo uma vez | 30 | 14 | R | Próprio jogador | Escudo 15, sem somar | 6 s; impede novos slows; slow existente continua |
| Raio | Pessoal/contínuo — Aura | 0 | 30 | 14 | R | Próprio jogador | — | 6 s; velocidade de projétil ×1,25; CD de novos casts ×0,85 |
| Vento | Pessoal/contínuo — Aura | 0 | 30 | 14 | R | Próprio jogador | — | 6 s; movimento +25%; um pulo aéreo extra |
| Fogo | Área/direto — Leque | 23 | 18 | 1,2 | R, instantâneo | 7 m nominal; teste até 7,5 m | Abertura total 50° | VFX 0,2 s; sem burn |
| Gelo | Área/direto — Leque | 18 | 18 | 1,2 | R, instantâneo | 6 m nominal; teste até 6,5 m | 50° | Slow 50% por 1,5 s, acumulável |
| Raio | Área/direto — Leque | 20 | 18 | 1,2 | R, instantâneo | 9 m nominal; teste até 9,5 m | 30° | Sem choque |
| Vento | Área/direto — Leque | 17 | 18 | 1,2 | R, instantâneo | 6 m nominal; teste até 6,5 m | 50° | Knockback horizontal 10 m/s |
| Fogo | Área/explosivo — Marca | 43,7 + burn | 35 | 6 | C; detona +0,9 s | 25 m no cliente; **não validado no servidor** | 2,5 m | Burn 4/s por 3 s, até 6 s acumulados |
| Gelo | Área/explosivo — Marca | 34,2 | 35 | 6 | C; +0,9 s | 25 m no cliente | 2,5 m | Slow 30%/1,5 s seguido de root: efetivamente ≥1,5 s de imobilização em alvo limpo |
| Raio | Área/explosivo — Marca | 38 | 35 | 6 | C; +0,6 s | 25 m no cliente | 2,5 m | Sem choque |
| Vento | Área/explosivo — Marca | 32,3 | 35 | 6 | C; +0,9 s | 25 m no cliente | 2,5 m | Velocidade vertical mínima 9 m/s; altura balística livre ~1,84 m |
| Fogo | Área/contínuo — Muralha | Burn 4/s por contato | 30 | 10 | C | Centro 4 m à frente no cliente | 6×3×0,5 m; HP 120 | 5 s; sólida; verifica contato a cada 0,5 s com margem 0,6 m de cada lado |
| Gelo | Área/contínuo — Muralha | 0 | 30 | 10 | C | 4 m no cliente | 6×3×0,5 m; HP 180 | 5 s, sólida e opaca |
| Raio | Área/contínuo — Muralha | 5 por tick de 0,5 s | 30 | 10 | C | 4 m no cliente | 6×3×0,5 m; contato expandido | 5 s; sem colisão, fora de damageable; HP 120 não utilizável; sem choque |
| Vento | Área/contínuo — Muralha | 0 | 30 | 10 | C | 4 m no cliente | 6×3×0,5 m; HP 120 | 5 s; layer 2, bloqueia projéteis e deixa jogadores passar |

Complementos necessários para interpretar a tabela:

- Setas não têm headshot. Orbe também não: o colisor/posição de impacto não seleciona cabeça. A distância para a queda de dano do Orbe é até `global_position + (0,0.9,0)`, não até a superfície atingida. Assim o dano central tabelado é um teto; impacto na cápsula normalmente já sofre alguma queda (`scenes/spells/projectile.gd:47`, `scenes/spells/burst_projectile.gd:13`, `scenes/spells/burst_projectile.gd:28`).
- Raios de Orbe/Marca/zona são consultas de sobreposição de **esfera com colisor**, não distância plana exata ao centro do jogador. Podem alcançar parte de uma cápsula fora do anel desenhado. Só Leque verifica linha de visão (`scenes/spells/spell_node.gd:42`, `scenes/spells/area_spell.gd:119`).
- Semente, sem obstáculos e no mesmo nível de origem/destino, teria alcance balístico máximo `18²/14 = 23,14 m`; altura da origem, teto, colisão e buffs alteram isso. Não confundir com alcance fixo 25 m. A prévia não inclui Foco/Aura (`scenes/player/aim_preview.gd:62`, `scenes/spells/projectile.gd:21`).
- Burn isolado ideal entrega 12 HP em seis ticks; reaplicação aumenta duração, não DPS, até 6 s. Ordem de atualização/expiração pode afetar o tick da fronteira. Não somar 12 instantaneamente a cada Seta numa rajada. Zonas de Fogo de fontes distintas acumulam dano independente. Muralha expira **antes** de processar contato na última atualização; a 5 s exatos são nove ticks/45 HP de Raio, não dez/50 (`scenes/spells/wall.gd:63`).
- Fogo não queima universalmente, Raio não choca universalmente, Vento não empurra universalmente: portar status no recurso não basta, os chamadores precisam aplicá-lo. Isso deve estar escrito no grimório. Há ambiguidade na linha geral “Status” da spec 01; não trato automaticamente toda ausência como implementação obrigatoriamente errada.

### Runas, buffs e movimento

| Sistema | Valor real | Consequência quantitativa |
|---|---|---|
| Fôlego | Máximo/início 130 mana | +30 por round, sem +regen; 10 Setas em rajada em vez de 8 |
| Pressa | CD ×0,8 | Seta 0,28 s; Leque 0,96 s; Impulso 3,2 s |
| Passo Leve | +12% aditivo ao bônus de Aura | Andar 6,16; correr 8,4 m/s; com Aura Vento 7,535/10,275 m/s |
| Casca | Escudo 25 por 999 s | +25 EHP inicial; Guarda o substitui, não soma |
| Foco | Velocidade projétil ×1,2 | Seta Raio 84 m/s; com Aura 105 m/s; alcance por lifetime também aumenta |
| Eco | Recast custa ×0,7 | Seta 8,4; Orbe 21; Marca 24,5; só RMB recebe desconto |
| Sangue Frio | HP <30, dano ×1,2 em damage_mult | Exatamente 30 HP não ativa; dano é consultado no impacto |
| Sobrecarga | 10 s ou 3 casts pretendidos; custo 0; dano ×1,2 | Servidor não desconta cargas de clientes; detalhes em P0-01 |
| Aura Fogo + Sangue Frio + Core | ×1,2³ = 1,728 | Seta 31,7952 e Marca 75,5136, enquanto condições valem no impacto |
| Aura Raio + Pressa | CD ×0,68 | Seta 0,238; Impulso 2,72; Guarda 5,44 s |
| Maré + Aura Raio + Pressa | CD ×0,34 | Seta nominal 0,119 s, mas composer normal limita a ≥0,15 s; Impulso 1,36 s |
| Movimento base | 5,5/7,5/3 m/s; g=22; pulo 1,2 m | Velocidade inicial do pulo ~7,266 m/s; coyote 0,1 s; degrau 0,35 m |

Fontes: `scenes/player/player.gd:394`, `scenes/player/player.gd:404`, `scenes/player/player.gd:414`, `scenes/player/player.gd:447`, `scenes/player/player.gd:456`, `scenes/player/player.gd:471`, `data/player_tuning.tres:7`.

### TTK e economia de mana

Hipótese controlada: 100 HP, sem escudo, todos os hits acertam, alvo não sai da área, primeiro impacto em t=0, intervalos de CD exatos. A tabela de TTK isola **dano direto** para permitir comparação; não é previsão de duração de um duelo. Adicionar voo inicial, composição, confirmação, cobertura e latência. Para Marca, adicionar 0,9 s desde o primeiro cast (Raio 0,6). Discretização pode acrescentar ticks/frames.

| Magia | Fogo: hits / TTK / mana | Gelo | Raio | Vento |
|---|---|---|---|---|
| Seta | 6 / 1,75 s / 72 | 7 / 2,10 s / 84 | 7 / 2,10 s / 84 | 8 / 2,45 s / 96 |
| Orbe, teto central | 4 / 6 s / 120 | 4 / 6 s / 120 | 4 / 6 s / 120 | 5 / 8 s / 150 |
| Leque | 5 / 4,8 s / 90 | 6 / 6 s / 108 | 5 / 4,8 s / 90 | 6 / 6 s / 108 |
| Marca | 3 / 12 s / 105 | 3 / 12 s / 105 | 3 / 12 s / 105 | 4 / 18 s / 140 |

Os custos acima de 100 são viáveis com regeneração entre ataques lentos. Exemplo: Orbe a cada 2 s recupera ~18 mana, saldo −12 por ciclo; Marca a cada 6 s recupera até 66, acima do custo 35, se não houver outros casts.

Burn muda eficiência: cinco Setas Fogo entregam 92 direto; após ~2 s desde o primeiro impacto, quatro ticks de burn completam 100, por **60 mana**, se o jogador parar de disparar. Se continuar no CD, a sexta mata antes, em ~1,75 s. Uma Seta isolada vale até 30,4 HP/12 mana = **2,53 HP/mana**; Vento direto vale 1,13. Duas Marcas Fogo entregam 87,4 direto + até 24 de burn distribuídos no tempo, suficientes para matar sem terceira Marca. Esses totais pressupõem a janela completa do status.

Aura Fogo custa 30: cinco Setas buffadas custam mais 60 e causam 110,4 direto. TTK direto ~1,4 s entre primeiro e último impacto, mais lockout de 0,15 s após Aura e voo. Benefício de burst real, porém custo total 90 contra 72 sem Aura. Não é ganho automático de eficiência de mana.

Combos próximos, sob hipóteses ideais e sem buff: Leque + quatro Setas Fogo = 96,6 direto por 66 mana, completável com burn; Raio precisa Leque + cinco Setas =100 por 78; Gelo Leque + seis Setas =104,4 por90; Vento Leque + sete Setas =112,2 por102. São sequências que exploram CDs separados; o espaçamento mínimo entre **magias diferentes** é 0,15 s no composer. Orbe + Leque Fogo + três Setas somam 110,4 direto por84, no teto da explosão. Comparar isso com oponente móvel é obrigatório antes de nerfar números.

**Economia por round:** orçamento superior `100 + 12 × tempo efetivo de regeneração`; em 90 s, teto teórico 1.180 mana, mas limite de estoque e pausas desperdiçam parte. Com N casts separados por ≥0,5 s e sem bater no máximo, aproximação `100 + 12×(90−0,5N)`. Não usar essa fórmula para rajadas cujas pausas se sobrepõem. Cadência sustentável de uma magia sozinha é `max(CD, 0,5 + custo/12)`:

| Magia | Intervalo mínimo sustentável, s | Pressão sobre mana no CD base |
|---|---:|---|
| Seta | 1,50 | CD 0,35: esgota; 8 disparos/96 mana até t=2,45 |
| Orbe | 3,00 | CD 2: drena ~12 por ciclo |
| Semente | 5,00 | Recupera até54 entre casts; custo22 |
| Guarda | 8,00 | Recupera até90; custo25 |
| Impulso | 4,00 | Recupera até42; custo20 |
| Aura | 14,00 | Recuperação potencial162; custo30 |
| Leque | 2,00 | CD1,2: recupera8,4; drena9,6 por ciclo |
| Marca | 6,00 | Recupera até66; custo35 |
| Muralha | 10,00 | Recupera até114; custo30 |

Após oito Setas erradas sobram4 mana: a nona requer ~0,5+8/12 =1,167 s depois da oitava, chegando em t≈3,617. Eco permite 11 Setas a partir de uma primeira normal (`12+10×8,4=96`); Fôlego permite10 (`120`). Eco vence Fôlego em economia acumulada após gastar mais de100 mana-base em recasts, mas não dá reserva inicial para uma sequência variada. Pressa aumenta a velocidade de esgotamento, não a mana disponível.

## 2. Parecer e achados priorizados

**Não aprovar ainda a alfa com o contrato proposto.** Os principais bloqueios são divergência de estado cliente/servidor e regras que pontuam ou transferem vantagem incorretamente. O balanceamento relativo abaixo é hipótese baseada em números, sem taxa de vitória medida. P0 = bloqueia aceitação da alfa; P1 = corrigir antes da rodada de balanceamento; P2 = corrigir ou declarar desvio conscientemente. Esforço em dias de desenvolvimento + teste focado: pequeno ≤1, médio 1–3, grande 3–5; não somar como cronograma independente.

### P0-01 — Sobrecarga ilimitada por 10 s no servidor e bônus do terceiro cast perdido no host

**Evidência:** `scenes/net/net_match.gd:247` paga mana/CD, mas não decrementa `overcharge_casts`; a única redução fica em `scenes/player/player.gd:388`, caminho local. `scenes/spells/spell_node.gd:36` consulta `damage_mult()` no impacto, depois do consumo local.

**Impacto:** em dedicado ambos os jogadores são remotos: Core conserva três cargas autoritativas durante10 s. No limite nominal são29 Setas/348 mana-base gratuitos, em vez de três/36. O cliente comum continua sujeito à previsão local de mana, mas snapshots de mana cheia renovam a reserva; a divergência continua explorável sem cliente modificado. Em listen server o host consome a última carga antes do spawn e pode perder o bônus do terceiro ataque, ou dos projéteis anteriores ainda em voo. Zonas já existentes também ganham/perdem bônus ao capturar/expirar Core.

**Correção:** transação única no servidor: capturar custo/multiplicador no cast aceito, consumir exatamente uma das **3** cargas e replicar contador/tempo; armazenar multiplicador no objeto. Manter **10 s/+20%/3 casts** inicialmente. Testar 4º cast, terceiro projétil em voo e paridade host/remoto. **Esforço: médio.**

### P0-02 — Snapshot não restaura status, cooldown, morte nem forças; clientes jogam outra simulação

**Evidência:** `scenes/player/net_sync.gd:212` envia máscara de status, mas `scenes/net/net_match.gd:211` só aplica HP/mana/escudo. Não envia durações/intensidades/CDs. Hits/status/knockback são host-only (`scenes/spells/spell_node.gd:34`), enquanto cliente calcula velocidade por `_slow_strength` (`scenes/player/player.gd:417`). Rejeição apenas escreve warning (`scenes/net/net_match.gd:286`).

**Impacto:** slow/root não chegam à previsão local; movimento corrigido continuamente pelo servidor. Escudo/status/morte podem estar errados localmente, buffs visuais e timers divergem, cast recusado deixa CD local pago. O servidor pode rejeitar custos/CDs que HUD dizia disponíveis. Spec04 §4/6 e spec01 §6 não são satisfeitas.

**Correção:** snapshot autoritativo de estado de combate com versões/tempos restantes, intensidade de slow, impulso e `is_dead`; reconciliar CD/mana por request_id. Aplicar resultado de dano confiável uma vez e feedback correspondente. Frequência existente **30 Hz**, sem aumentar; timers compactos ou eventos+timestamp. **Esforço: grande.**

### P0-03 — Mortes simultâneas dão vitória pela ordem de execução

**Evidência:** `scenes/net/net_match.gd:126` conecta cada morte diretamente a `report_death`; `autoload/match_state.gd:140` chama `player_died`; `scenes/match/match_fsm.gd:141` encerra o round imediatamente. `both_died()` existe em linha148, mas só o teste a chama. Colapso percorre jogadores sequencialmente (`scenes/match/collapse_zone.gd:53`).

**Impacto:** dois jogadores a6 HP fora da zona: o primeiro processado morre e já concede o ponto ao segundo. A segunda morte não corrige placar; transição ainda agenda a remoção da zona durante o loop. Contradiz desempate por HP antes do tick da spec02 §5. Trade de projéteis/reflexão sofre do mesmo problema.

**Correção:** acumular mortes e HP inicial do tick, decidir uma única vez após dano de ambos. Mais HP pré-tick vence; HP igual gera empate conforme regra documentada. **Esforço: médio.**

### P0-04 — Três duelos no VPS não têm configuração nem prova de capacidade

**Evidência:** `autoload/net.gd:150` limita a sala a dois jogadores; `autoload/match_state.gd:9` tem uma FSM global. `server/dynmagic.service:11` inicia uma única instância/porta7777. CI (`.github/workflows/release.yml:46`) só comprova boot por300 frames, sem clientes/carga. Preset dedicado não evita a criação em código de HUD, magos, shaders, áudio e partículas: `scenes/net/net_match.gd:44`, `scenes/player/player.gd:99`, `autoload/audio_bus.gd:58`, `scenes/spells/projectile.gd:37`, `scenes/spells/explosion_fx.gd:34`.

**Impacto:** um processo não atende seis jogadores em três partidas. Três processos podem caber ou não: **RSS/CPU Linux não medidos**, portanto não afirmo OOM nem um consumo fictício. Teste de FPS no Windows/RX580 não valida 1vCPU compartilhada. Síntese de áudio no primeiro cast também executa no servidor headless; só música tem guarda headless.

**Correção mínima:** três instâncias independentes, portas de jogo **7777/7779/7780 UDP** (7778 continua descoberta), systemd template com nome/porta/dados separados; desligar apresentação/áudio/síntese no dedicado, preservar colisores. Proposta de gate, não medição: reservar **≥300 MB** para SO/outros serviços; grupo DynMagic **≤600 MB** total (ajustar para a carga real existente), sem swap/OOM; uso sustentado total do jogo **≤70% de um núcleo**, tick p99 **<16,67 ms** com três partidas e serviços reais. Medir memória agregada do grupo, CPU, tick e crescimento após **60 min/20 partidas**, incluindo Maré, reconnect e casts variados; seis clientes em outra máquina. Não baixar física para30 Hz antes dessa medição. **Esforço: médio/grande.**

### P1-01 — Marca Gelo transforma slow em root longo; Aura não limpa slow

**Evidência:** `scenes/spells/area_spell.gd:85` aplica primeiro o hit com slow1,5 s; linha90 aplica root via outro slow0,6 s. `scenes/player/player.gd:315` guarda intensidade máxima; `scenes/player/stats.gd:170` preserva a duração anterior se maior que o novo cap.

**Impacto:** alvo limpo fica parado **1,5 s**, não0,6; alvo já lento pode ficar parado3 s e novos slows prolongam a intensidade1. Marca vira confirmação de burst muito mais forte que descrito. `self_spell.gd:35` ativa Aura Gelo sem remover slow anterior, embora a spec diga “imune”.

**Correção:** root independente com **0,6 s**, não acumulável; slow separado limitado a50%/3 s; Aura limpa slow/root se imunidade incluir root (documentar explicitamente). Não baixar dano34,2 antes de corrigir duração. **Esforço: pequeno/médio.**

### P1-02 — Morte Súbita permite escudos novos e dano periódico de zonas

**Evidência:** `scenes/net/net_match.gd:505` só limpa escudo na entrada. `scenes/player/player.gd:363` desliga exclusivamente burn; `scenes/spells/zone.gd:47` e `scenes/spells/wall.gd:98` continuam dano. `scenes/spells/self_spell.gd:26`/linha39 recriam escudos.

**Impacto:** “primeiro acerto” vira um duelo de Guardas: Gelo recebe45 de escudo em1 HP; Aura ainda dá15. Rastro/zona Fogo e Muralha Raio matam por tick enquanto burn Fogo é desligado; escolha aleatória de overtime beneficia magias de maneira opaca. Persistências pré-overtime podem decidir antes de reação.

**Correção:** em sudden_death, escudo efetivo **0** inclusive novos casts, dano periódico ofensivo **0**, dano direto permanece; Colapso continua **12/s** como exceção explícita. Remover/neutralizar fontes periódicas e informar Guardas indisponíveis ou substituir efeito. Testar entrada em zona ativa e cast de Guarda após entrada. **Esforço: médio.**

### P1-03 — Falta reset completo de round e barreira para dano entre fases

**Evidência:** `scenes/net/net_match.gd:389` reseta Stats/composer/aura/guarda, mas não Core, dash, knockback, glide nem objetos antigos. `scenes/player/player.gd:279` não filtra fase. `scenes/player/player.gd:156` com frozen ainda processa status/dash/forças; `SpellNode.hit_amount` não verifica round_id.

**Impacto:** HP pode cair durante DRAFT/COUNTDOWN, sem terminar round porque FSM ignora mortes fora de combate; entrar em COMBAT já morto pode deixar round até timeout. Seed pode viver5 s e gerar zona4 s, ultrapassando ROUND_END3 + COUNTDOWN3 em draft rápido. Sobrecarga de10 s pode passar ao próximo round; o primeiro capturador recebe vantagem indevida adicional. Magias persistirem após morte dentro do round é requisito; atravessar o reset não é.

**Correção:** dar round_id às fontes; manter persistência durante ROUND_END se desejado, limpar todas no **início do novo DRAFT**; resetar campos transitórios e transporte/previsão por round, impedir dano fora de COMBAT/OVERTIME. Conferir HP100, mana100/130 e zero buffs na entrada do combate. **Esforço: médio.**

### P1-04 — Draft encerra a escolha de runa antes dos 20 s prometidos

**Evidência:** `scenes/match/match_fsm.gd:112` inicia segundo turno assim que A escolhe; segunda escolha auto-sorteia runas e entra em countdown. Spec02 §3 reserva20 s inteiros ao perdedor.

**Impacto:** duas escolhas rápidas podem roubar quase toda janela de catch-up; quem escolhe segundo controla o momento de confirmar a runa do outro. Bots reforçam isso escolhendo imediatamente (`scenes/net/net_match.gd:457`).

**Correção:** deadline de draft fixo **20 s**; A até10, B até20, runa até20. Se antecipação for desejada, exigir confirmação explícita de **ambos** incluindo runa. **Esforço: pequeno.**

### P1-05 — Core capturado através de altura/cobertura, reset por expiração de escudo e desempate por ordem

**Evidência:** `scenes/net/net_match.gd:479` fixa Core em(0,3,0) para A/B/C. `scenes/match/arcane_core.gd:64` elimina Y e não checa visibilidade; linha60 infere dano por HP+escudo; linha56 retorna no primeiro a completar. `scenes/arena/arena_builder.gd:82` não constrói rampa central nem marcador específico; C tem parede no centro (`:50`), não fresta.

**Impacto:** captura escondido ao pé do pilar; Core flutua em B/C e C não usa fresta como spec03 §4. Expirar Guarda parece dano e zera progresso sem ataque. Cura/ganho de escudo entre amostras pode mascarar dano. Captura simultânea favorece a ordem do dicionário; contestação não definida.

**Correção:** marcador por arena e acesso simétrico; medir cilindro **r=2 m e diferença vertical≤1,5 m**, exigir caminho visível até ponto de captura. Reset por evento autoritativo de dano positivo, nunca variação de escudo. Proposta: dois jogadores dentro = progresso pausado; captura2,5 s preservada ao sair. Essa contestação é decisão de design nova. **Esforço: médio.**

### P1-06 — Servidor não valida target, números finitos, recast ou lockout global

**Evidência:** `scenes/net/net_match.gd:232` aceita direction/target/is_recast fornecidos pelo cliente; `_validate` em linha253 só verifica vivo/frozen/CD/mana/origem. Não há tempo de último cast global. Spec04 §6 exige alcance de target. Comparação `distance > 1,5` também não rejeita NaN.

**Impacto:** cliente alterado pode plantar Marca/Muralha arbitrariamente longe, reivindicar Eco em toda magia e disparar combinações diferentes sem0,15 s; pacote inválido compromete simulação. Mesmo entre amigos, validação geométrica evita bugs de preview/cliente velho e preserva um resultado de QA confiável.

**Correção:** rejeitar componentes não finitos, direção nula; normalizar direção; validar/recalcular alvo **25 m Marca /4 m Muralha**, origem≤1,5 m e superfície/ocupação; recast só se igual à última magia aceita; lockout global **0,15 s** no servidor. Validar comprimento exato dos buffers (`autoload/net_codec.gd:26`). **Esforço: médio.**

### P1-07 — Projéteis e Muralhas desaparecem em momentos diferentes em cada peer

**Evidência:** `scenes/spells/projectile.gd:47` executa colisão e destrói projétil em todos os peers, apesar da spec04 §6 prometer detecção só no host. `scenes/spells/wall.gd:74` recebe dano autoritativo, mas não há RPC de HP/destruição; `scenes/net/net_match.gd:267` transmite apenas spawn sem ID/tick. `_steer` consulta mira local/interpolada a cada frame (`projectile.gd:85`).

**Impacto:** Muralha destruída no servidor continua sólida no cliente até5 s; cliente enxerga projétil acertar/errar diferente, principalmente Vento; correções de movimento contra paredes fantasmas. Sem avanço pelo atraso conhecido, remoto vê cast mais tarde.

**Correção:** ID+tick de spawn, evento de impacto/despawn confiável, HP de parede; previsão visual reconciliada, colisão de gameplay exclusiva do host. Replicar rumo/estado necessário ao Vento. **Esforço: grande.**

### P1-08 — Reconexão atualiza o retornante, mas não remapeia o jogador no cliente que permaneceu

**Evidência:** `scenes/net/net_match.gd:146` renomeia nó apenas no servidor; `autoload/net.gd:171` atualiza dicionários, mas só emite `joined` quando `first_time`; `_sync_players` depende desses sinais (`net_match.gd:37`). Bootstrap é enviado só ao retornante (`:162`).

**Impacto:** sobrevivente pode manter nó com peer_id antigo; snapshots do novo ID são ignorados por `_player(id)==null` (`net_match.gd:209`), casts também. Smoke que observa só retomada no host/retornante não prova a sessão do sobrevivente. Adicionalmente, bootstrap de overtime não restaura `_overtime_applied`: retomada de Morte Súbita pode reaplicar HP1 localmente e criar segundo Colapso sobre o restaurado (`:183`, `:503`, `:519`).

**Correção:** RPC de remapeamento para todos, ou sync de roster que preserve estado/objetos por identidade de slot; restaurar marcadores de overtime e timers de Core/Colapso. QA em **três processos**, observando ambos os clientes; reconnect durante cada overtime e com parede quebrada. **Esforço: médio.**

### P1-09 — Sprint autoritativo ignora composição remota

**Evidência:** `scenes/player/player.gd:90` altera `sprint_blocked` por evento do composer local. `scenes/player/net_sync.gd:203` atualiza bits e glifo remoto, sem atualizar o bloqueio; `_host_step` inclusive aplica input antes desses bits (`:158`).

**Impacto:** dedicado permite7,5 m/s na simulação durante mira, cliente prevê5,5 m/s; correções e vantagem em deslocamento. RMB rápido também não passa por SLOT_EFFECT/AIMING e o validator não barra sprint (`player.gd:373`). Spec05 §2 não é cumprida.

**Correção:** derive bloqueio autoritativo de composição válida antes de simular input; qualquer cast cancela sprint durante pelo menos lockout **0,15 s**; confirmar a regra de retomada ao segurar Shift. **Esforço: pequeno/médio.**

### P1-10 — Cobertura não protege de explosões/zonas e rastro atravessa obstáculos

**Evidência:** `scenes/spells/burst_projectile.gd:24`, `area_spell.gd:84`, `zone.gd:46` usam sobreposição sem LOS. `self_spell.gd:59` cria três zonas ao longo dos9 m teóricos antes do movimento/colisão. Muralha é colocada sem varredura/validação de volume (`scenes/player/spell_caster.gd:53`).

**Impacto:** Orbe na face de uma caixa acerta atrás; Seed/Marca anulam cobertura e podem capturar espaço sem exposição. Impulso bloqueado ainda incendeia o outro lado. Não há regra explícita de explosão atravessar cobertura nas specs; isso conflita com o papel tático descrito para arenas e merece decisão antes de balancear.

**Correção proposta:** LOS da explosão ao centro/cápsula para dano, raio atual preservado; rastro por deslocamento **real** a cada3 m, zonas1,2 m/2 s; rejeitar Muralha intersectando jogador/cobertura sólida. Se quiser dano atravessando paredes, documentar e desenhar essa área no preview. **Esforço: médio.**

### P1-11 — Nameplate revela adversário através da cobertura

**Evidência:** `scenes/player/player.gd:424` define `no_depth_test=true`; linha444 mostra HP/escudo/status sobre todos os jogadores remotos.

**Impacto:** localização e recursos do oponente visíveis através de paredes, destruindo emboscadas e leitura de risco de Core. Nome “debug” no comentário não condiciona execução à build debug.

**Correção:** remover nameplate de combate da release ou exigir LOS; HP inimigo só se decisão explícita. Manter debug por flag desativada por padrão. **Esforço: pequeno.**

### P1-12 — MD7 não tem duração máxima nem final garantido

**Evidência:** `scenes/match/match_fsm.gd:173` permite empate sem ponto; `:312` inicia outro round. Colapso para em raio5 m (`scenes/match/collapse_zone.gd:7`), inclusive decisivo que spec02 §6 diz garantir fim.

**Impacto:** duas pessoas podem sobreviver no centro, empatar HP/sem Core e repetir indefinidamente. Uma “MD7” pode ter13,20… rounds (o próprio ROADMAP relata13). Isso retém uma das três salas e torna a promessa de duração incorreta.

**Correção proposta:** manter primeiro a4, chamar empates de rounds extras; depois de **20 s** fechar5→0 m nos próximos **20 s**, persistindo dano; para empate exato repetido, cap de **2 empates consecutivos**, então round extra com objetivo simétrico de captura e desempate explícito. Outra opção é limite de partida **25 min** com empate final. Escolher/documentar uma; nenhuma deve sortear vitória silenciosamente. **Esforço: médio.**

### P1-13 — Risco de reinício de partida via estado do lobby ainda pronto

**Evidência:** `autoload/lobby.gd:64` aceita ready em qualquer fase e não verifica participante; `_push` em linha77 agenda auto-start se dois prontos, sem exigir lobby/`MatchState.active=false`. `start_match` não consome flags nem limita fase (`:59`). Peer_joined também chama `_push` (`:21`).

**Impacto:** uma requisição ready durante a partida pode agendar outro início, pois as flags não são consumidas no primeiro início. Após 2 s, `_begin` troca a cena e interrompe a sessão. É reproduzível por RPC fora de fase; não afirmo que a UI normal envie esse pedido. A desconexão apaga a flag de quem saiu, portanto a reconexão sozinha não basta para esse reinício.

**Correção:** aceitar ready e auto-start só em lobby sem partida ativa, de IDs em `Net.players`; limpar/consumir flags ao iniciar; revalidar fase após timer **2 s**. QA de reconnect e dois ciclos completos sem reinício indevido. **Esforço: pequeno.**

### P2-01 — Divergências elementais restantes não cobertas pela tabela de resolução

| Divergência da spec01 | Evidência | Impacto / proposta concreta | Esforço |
|---|---|---|---|
| Aura Gelo “+15 regeneração de escudo” vira concessão única | `scenes/spells/self_spell.gd:37` | Pode valer **zero** quando Guarda/Casca já tem>15. Definir unidade: proposta conservadora **15 totais regenerados em6 s (2,5/s), cap45**; se intenção era15/s, são90 e exige outro balanceamento. | Pequeno |
| Solo Gelo sem baixo atrito | `scenes/spells/burst_projectile.gd:71`, `scenes/player/player.gd:208` | Atualmente é slow30%. Implementar atrito/aceleração próprios ou aceitar/documentar slow30%/3 s na alfa; não chamar “escorregadio”. | Pequeno/médio |
| Impulso Gelo slide=true sem consumidor | `data/elements/frost.tres:21`, `scenes/spells/self_spell.gd:47` | Só distância11 m diferencia. Aceitar11 m/0,18 s como alfa e remover promessa de deslize; ou acrescentar desaceleração explícita0,3 s testada. | Pequeno |
| Semente Raio deveria chocar a cada1 s | `scenes/spells/zone.gd:6`, `:49` | Reaplica duas vezes mais; habilita +20% a cada hit espaçado≥0,5 s. Dar intervalo próprio **1 s** à zona Raio. | Pequeno |
| Muralha Fogo “queima quem atravessa” é sólida | `scenes/spells/wall.gd:42` | Não atravessável; queima por proximidade além da superfície. Proposta preservar sólido e descrever contato, ou layer não sólida como Raio se atravessar for requisito. | Pequeno |
| Orbe Vento “puxa antes de explodir” não muda posição antes do dano | `scenes/spells/burst_projectile.gd:29` | Pull não aumenta dano central daquele cast. Proposta atraso **0,15 s** antes do blast, preservando6 m/s, ou documentar puxão simultâneo sem promessa de centralizar. | Médio |
| Headshot ×1,5 só Seta/Orbe direto ausente | `scenes/player/player.tscn:29`, `scenes/spells/projectile.gd:49`, `burst_projectile.gd:13` | TTK atual ignora habilidade de headshot. Implementar hurtbox e bônus somente direto, ou retirar requisito da alfa. Ex.: Seta Fogo27,6; Gelo21,6; Raio24; Vento20,4. | Médio |
| Margem do Leque +0,5 m não está na tabela | `scenes/spells/area_spell.gd:12` | Corrigir descrição de alcance centro/superfície; preservar margem até teste de sensação. | Pequeno |
| Status genérico parece universal, execução não | `autoload/spell_db.gd:86`, `scenes/player/player.gd:299` | Grimório anuncia choque/empurrão em magias que não aplicam. Explicitar aplicação por célula; não ligar status em todas sem rebalancear. | Pequeno |

### P2-02 — Métricas de dano e precisão não medem o que o resultado anuncia

**Evidência:** `scenes/player/player.gd:294` ignora retorno de `take_damage`, reporta amount bruto; burn vai direto a Stats (`:367`) sem atribuição. `autoload/match_state.gd:162` conta cada tick como hit; resultados dividem hits/casts (`scenes/net/net_match.gd:562`). Só guarda casts por forma, não magia (`match_state.gd:154`).

**Impacto:** Semente com8 ticks pode aparecer como800% de precisão; overkill infla dano, burn fica ausente, magia mais usada da spec02 §7 não pode ser reconstruída. Métrica ruim orientará nerfs errados.

**Correção:** dano efetivo separado em HP/escudo, cast_id e unique_hit por alvo/cast; ticks somam dano sem aumentar precisão; gravar spell_key e burn_owner. Precisão entre **0–100%** em1v1 e relatório por round. **Esforço: médio.**

### P2-03 — Degrau automático subtrai altura duas vezes; kill plane ausente

**Evidência:** `scenes/player/player.gd:233` testa descida desde `moved` elevado; linha237 calcula `moved.origin - up + travel`. Travel já representa a descida. `scenes/arena/arena_builder.gd:82` só constrói shell/balcões/coberturas/spawns; não há teste Y<−10 no controlador.

**Impacto:** degrau de0,2 m pode resultar em posição abaixo da original e ser rejeitado, apesar do limite0,35; jogador que atravesse piso por bug não morre como spec03 §4 exige.

**Correção:** destino `moved.origin + travel`, verificar normal/clearance; testes de degraus0,2/0,35/0,36 m. Kill plane autoritativo em **Y<−10**, dano letal normal. **Esforço: pequeno/médio.**

### P2-04 — Buffs e defesas interagem por caminhos de dano incompatíveis

**Evidência:** burn usa `Stats.take_damage` (`player.gd:367`), zonas usam `hit_amount`, Muralha Raio chama diretamente `receive_hit` (`wall.gd:99`), Colapso usa Stats (`collapse_zone.gd:57`). Guarda Vento trata qualquer spell.form projectile como projétil (`player.gd:288`).

**Impacto:** burn ignora i-frame/choque/reflexão e atribuição; Muralha não ganha Aura/Sangue Frio/Core; primeiro tick de chão Fogo derivado de Orbe/Semente pode consumir toda Guarda Vento como se fosse projétil. Guarda expirada deixa referência até próximo hit: um escudo posterior pode reativar efeito antigo. Aura Raio não encurta seu próprio CD porque pagamento precede aplicação, coerente com “novos casts”, mas pouco óbvio.

**Correção:** evento de dano com tipo (`direct`, `periodic`, `environment`) e origem/cast_id, política explícita por tipo; Guarda Vento só intercepta colisão de objeto projétil, não zona; limpar active_guard ao expirar/quebrar seu escudo. Manter burn **4/s**, contato Raio **10/s** como números absolutos documentados inicialmente. **Esforço: médio.**

### P2-05 — Prévia e alcance efetivo não são a mesma coisa

**Evidência:** `scenes/player/aim_preview.gd:66` usa velocidade-base, mas `projectile.gd:25`/`:27` adicionam Aura/Foco. `_trace_arc` usa30 Hz contra física60. `scenes/player/spell_caster.gd:33` soma `player.y` a `aim.y` que já era absoluto. `_floor_below` ignora qualquer damageable, inclusive Muralha.

**Impacto:** Semente Foco/Aura cai longe do preview; Marca a partir de varanda tem origem vertical de busca errada após clamp; paredes temporárias podem ser atravessadas pelo posicionamento. Orbe de alcance30 m expira só depois do passo, excedendo até~0,367 m a60 Hz sem buffs (`projectile.gd:55`).

**Correção:** compartilhar cálculo de trajetória/buffs no preview e simulação; usar Y absoluto correto; distinguir personagem de superfície sólida; limitar último segmento ao restante dos **30 m**. **Esforço: médio.**

**Outro problema de simulação:** `scenes/player/net_sync.gd:128` reaplica `Player.apply_input` durante reconciliação, e esse caminho também avança burn, i-frame, Core, glide e dash (`scenes/player/player.gd:162`). Esses timers não são restaurados ao estado do snapshot antes do replay. Com correções repetidas, o cliente envelhece buffs mais de uma vez e pode produzir dano local de burn adicional. Separar replay de movimento de efeitos temporais ou incluir o estado completo correspondente ao ack, sem reenviar eventos; verificar duração real de **10 s** de Core e **0,1 s** de i-frame sob correções. Esforço médio, em conjunto com P0-02.

### P2-06 — Lacunas de contrato/documentação que afetam QA, sem exigir polimento total para alfa

| Contrato | Estado/evidência | Correção proposta / esforço |
|---|---|---|
| Morte: câmera orbitando cadáver3 s; dissolve/ragdoll (spec05 §5); spec02 fala câmera do killer | `scenes/net/net_match.gd:347` só congela; `scenes/player/mage_animation.gd:46` toca animação death | Escolher câmera de morte única, **3 s**; não marcar replay como implementado. Médio. |
| Spec06: modo Segurar e forçar confirmação | `scenes/player/spell_composer.gd:67`, `scenes/ui/settings_screen.gd:59` não oferecem os modos | Implementar ou declarar fora da alfa; manter Sequencial explicitamente. Pequeno/médio. |
| Spec06: remap pergunta antes de trocar; todas ações | `settings_screen.gd:123` remove tecla conflitante automaticamente; lista em`:4` não inclui pause/draft1–7 | Diálogo aceitar/cancelar e remap das ações de gameplay/draft; impedir perder teclas essenciais. Pequeno/médio. |
| Spec06: defaults por aba, borderless, brilho, outline, voz, cor aliado/inimigo e reduzir tremor | `settings_screen.gd:29`/`:55`/`:68`/`:87` só cobrem subconjunto; defaults só teclas; `autoload/settings.gd:93` sem voz | Registrar opções adiadas; voz/tremor sem sistema correspondente não bloqueiam duelo. Pequeno documental. |
| Grimório com descrição/prévia, não só parâmetros; dano flutuante em combate | `scenes/ui/grimoire_screen.gd:46` imprime parâmetros/status genérico; `net_match.gd:211` sem evento de dano | Texto por comportamento real e fonte de dano do P0-02; preview visual pode ficar para depois. Médio. |
| Barra Core só no raio e direção do dano real | `scenes/ui/hud.gd:203` mostra progresso>0 inclusive fora; `:182` usa perda HP+escudo e posição atual do inimigo | Checar proximidade; usar evento de dano; expiração de escudo e Colapso não apontam falsamente para inimigo. Pequeno. |
| Spec07: dissolve, outline inverted hull, loop extra de overtime; spec06 transição0,3 s | `scenes/spells/wall.gd:65` só queue_free; `autoload/scene_router.gd:27` fade0,3+0,3 s; `autoload/audio_bus.gd:131` música placeholder | Declarar desvios estéticos adiáveis; transição total atual~0,6 s. Revisão UX/arte. |
| Spec03: herança arena_base/StaticBody+Box; SDD FormDef/EffectDef/runas/overtime resources | `scenes/arena/arena_builder.gd:201` CSG gerado; `scenes/match/match_fsm.gd:25` lista hardcoded; SpellDB FORMS/EFFECTS | Diferença arquitetural, não bug de equilíbrio. Documentar implementação; pré-bake de colisão se perfil do VPS exigir. Pequeno documental/médio técnico. |
| Spec04: 2+4 espectadores; descoberta informa fase real | `autoload/net.gd:19` cinco conexões => dedicado2+3; `:302` sempre state=lobby | Alfa: **0 espectadores** para orçamento previsível ou corrigir teto para6; anunciar estado correto. Pequeno. |
| Spec08: RPCs apenas Net/MatchState/NetSync; SDD LAN vs dedicado posterior | `scenes/net/net_match.gd:231`, `autoload/lobby.gd:64` contêm RPCs; M9 já dedicado | Atualizar contrato para implementação, sem migração gratuita de RPCs. Pequeno documental. |

O histórico de ROADMAP/HANDOFF tem pendências já concluídas e resultados antigos; não trate “73 testes passam” como prova de comportamento das36 magias em rede. `tests/test_spell_resolution.gd:51` verifica números de recursos/modo, não executa colisões/status; `tests/test_match_fsm.gd:169` chama both_died diretamente e não testa a conexão real de mortes. CI mascara falha de import com `|| true` (`.github/workflows/release.yml:38`) e smoke aceita apenas mensagem de boot. Proposta: gates de integração abaixo, falha real em erro de script/RPC; esforço médio.

## 3. Assimetria, draft, snowball e overtime

### Escolhas dominantes e de baixo retorno

**Fogo** é candidato a melhor primeira escolha de pressão: maior dano direto, burn na Seta, chão/rastro e Aura. Não depende de habilidade secundária de área para extrair seu bônus. **Gelo** é candidato a melhor resposta defensiva:45 de Guarda,11 m de Impulso, slow e root atualmente exagerado; bugs de status tornam esse poder ruim de sentir no cliente. **Raio** troca dano por alcance/velocidade: Setas70 m/s e Leque9 m/30° são valor real, teleporte é imediato, mas choque está restrito à Semente/Guarda. **Vento** tem a pior eficiência letal, mas deslocamento/anti-projétil e mobilidade; não é “inútil” sem testar mapas e Core.

Orbe Raio **não adiciona8** sobre o mesmo oponente que já recebeu a explosão. Em1v1 o secundário serve como compensação de erro contra alguém fora do blast (e pode selecionar Muralha), não cadeia de dano extra. Semente Raio22 mana só acrescenta3,2 HP numa próxima Seta16 se o choque for consumido por ela; retorno é fraco em rajada curta, embora a reaplicação e Marca38 possam elevar valor. Não comparar seu recurso damage=0 com Seta sem contar controle, mas também não vender “combo de choque” universal.

Aura Gelo pode não dar nenhum escudo quando já existe Casca/Guarda; é a candidata mais clara a compra desperdiçada. Aura Raio de30 mana para economizar15% de CD não corrige falta de mana: usada para acelerar spam comum, pode piorar o resultado; ganha sentido em Core/Maré ou para mobilidade. Pressa tem o mesmo perfil. Foco melhora acerto em distância; seu valor não aparece em DPS parado.

**Propostas de experimentos após corrigir bugs**, não alterações silenciosas da spec: reduzir duração acumulada máxima de burn de6 para**3 s** mantendo4/s; experimentar Fogo ×**1,10** (Seta17,6/Orbe30,8/Leque22/Marca41,8) e Vento ×**0,90** (14,4/25,2/18/34,2). Isso igualaria Vento a Gelo em dano base e reduziria distância Fogo–Vento, preservando diferenças utilitárias. Executar uma alteração por rodada de teste; não aplicar ambos antes de medir acerto, mana vazia e dano de status. Para Orbe Raio, alternativa de1v1 é secundário **4 de dano no alvo principal** após0,15 s com LOS, mantendo8 só em outro alvo; não conceder ambos. Prioridade menor que consertar root/autoridade.

### Vantagem de draft

A primeira escolha alterna corretamente por round (`match_fsm.gd:273`), mas não é sorteada inicialmente: `autoload/match_state.gd:30` ordena IDs; listen host fica primeiro, dedicado usa menor peer_id. Sem empates, quem começou tem **4 primeiras escolhas num3–3**, inclusive o decisivo. O segundo escolhe com informação e o primeiro garante o elemento forte; não há dados para afirmar qual vale mais hoje. Com Fogo dominante, a exclusividade pode valer mais que contra-escolha. Fixar primeiro slot pela conexão é desnecessário: sortear o primeiro lado/first pick a cada **nova partida**, alternar depois; no decisivo usar ofertas de runa iguais para os dois se a meta for minimizar sorte. Esta última opção muda o design atual e precisa ser decidida.

Oferta de3 entre7 dá **3/7=42,86%** de chance de uma runa específica. Chance de ao menos Eco ou Fôlego =`1−C(5,3)/C(7,3)=71,43%`. Portanto catch-up não garante ferramenta econômica. Casca acrescenta25 EHP: Setas puramente diretas necessárias para125 são Fogo7/Gelo9/Raio8/Vento10, contra6/7/7/8 sem escudo. Pressa oferece burst/mobilidade; Sangue Frio só ajuda quando já a ≤29,99 HP. Esse pacote não é equivalente entre ofertas; precisa de amostra de partidas e escolha por runa.

### Runa do perdedor + Núcleo

Não há acúmulo intencional de runas entre rounds: vale a última derrota, ambos no3–3, nenhuma após empate (`match_fsm.gd:270`, `:297`). Core também é um por round. Portanto snowball **entre** rounds deveria ser baixo; bugs de reset/Sobrecarga introduzem justamente a persistência indesejada.

Dentro do round, vencedor do espaço central ganha mana gratuita, dano e desempate por HP igual. Se está à frente, esse é um snowball de posição legítimo, mas triplo. Três casts caros podem poupar **95–100 mana** (Marca35 + Orbe30 + Aura/Muralha30; ou duas Marcas eOrbe dentro de10 s), quase uma barra inteira; três Setas poupam36. O limite de cargas favorece preparar combo caro em vez de spam. No bug atual, isso vira pressão contínua gratuita10 s.

Catch-up pode inverter vantagem: Casca/Guarda absorvem ataques enquanto se captura, Eco sustenta contestação e Passo Leve facilita chegada. Na implementação a perda de escudo reseta captura, o que é coerente com dano, mas expiração espontânea não deveria resetar. Proposta inicial: **não nerfar Core antes de corrigir consumo**, manter3/10 s/+20%; medir captura→vitória, segmentada por HP/placar/runa. Gate exploratório: se capturar já à frente resultar em vitória>**80%** em amostra útil e jogabilidade permitir, experimentar bônus **+10%**, mantendo mana gratuita. Esse80% é limiar de investigação, não resultado observado nem regra universal de equilíbrio.

### Justiça dos overtimes

| Modo | Benefícios assimétricos reais | Problema/regra a validar |
|---|---|---|
| Colapso | Vento expulsa, Gelo prende, Fogo nega área; Guarda compra tempo | Tick6 HP,100 HP morrem em17 ticks (~8,5 s continuamente fora); com45 escudo25 ticks (~12,5 s). I-frame não evita Colapso. ArenaC divide centro e pode sustentar impasse; morte dupla está errada. |
| Morte Súbita | Velocidade70 m/s Raio, alcance9 m Leque, curva Vento e explosões tolerantes ao erro importam mais que dano | Zera vantagem de HP do combate, favorece quem estava perdendo; isso é regra deliberada, deve ser anunciado. Escudo recastável e zonas letais atuais quebram “primeiro acerto”. |
| Maré de Mana | Remove fraqueza econômica de burst; Pressa+Aura Raio atinge lockout global, Fogo maximiza DPS e Vento pode repetir mobilidade | CD reduz só para **novos** casts: CD existente não é reduzido; um cooldown iniciado perto do fim conserva redução depois do fim. Não é necessariamente bug, mas a regra é ambígua. Definir se remapeia CDs ativos ou documentar esse comportamento. |

Sorteio uniforme de3 regras acontece aos90 s; decisivo força Colapso. Conhecer o modo só no fim pode trocar vantagem de um duelo com base na build. Para alfa comparável, proposta de lobby/servidor: **Colapso fixo por padrão**, outros dois como modos de teste depois das correções. Dedicado atualmente não expõe configuração CLI de overtime/arena em `_parse_cli` (`autoload/net.gd:333`), e só host pode `Lobby.set_rules` (`autoload/lobby.gd:41`); adicionar opções documentadas em vez de depender de UI inexistente no VPS. Esforço pequeno.

### Duração MD7

Com draft completo, cada round custa `20+3+combate+overtime+3` s. Sem overtime e usando90 s: **116 s**, quatro rounds7min44s, sete13min32s. Com overtime máximo60: **176 s**, quatro11min44s, sete20min32s. Somar carregamento, pausas e15 s de resultados no dedicado (`net_match.gd:9`). Exemplo operacional com combate médio30 s e draft20:56 s/round → **3min44s a6min32s**. O código atual permite draft quase0 s; com combate30, seriam~2min24s a4min12s. Nenhuma dessas médias foi medida com humanos.

Empates adicionam até2min56s cada, sem limite total; desconexões/reconexões repetidas podem adicionar várias pausas de30 s. A promessa correta hoje é “primeiro a4, normalmente4–7 rounds pontuados”, não sete rounds máximos nem duração garantida. Corrigir P1-12 antes de vender duração previsível para amigos alternando vagas nas três salas.

## 4. Gate de QA proposto para liberar amigos

Revisão estática e cálculos aritméticos apenas; não executei Godot/import/testes, para não gerar logs/imports fora do único arquivo autorizado. Não houve benchmark do VPS nem playtest humano nesta revisão. Os seguintes testes são **pendentes**, não resultados:

1. Rodar as36 combinações em dedicado contra jogador real com posição/HP determinísticos, comparando dano/status/escudo/CD em servidor e dois clientes. Incluir hit atrás de cobertura, shield expiry e headshot conforme decisão da alfa.
2. Core: terceiro/quarto cast, projétil em voo, captura simultânea, dano durante captura, rampa/altura A/B/C; runa e Core não atravessam reset.
3. Cada overtime: dois jogadores com6 HP fora no mesmo tick; ambos a1 HP com Guarda/zona já ativa; entrada/saída de Maré com cooldown existente; empate em3–3.
4. Reconnect de cada lado em COMBAT/DRAFT e três overtimes, mantendo o outro cliente aberto e verificando movimentação, cast, roster, Core, objetos e ausência de auto-restart do lobby.
5. Duas partidas consecutivas por sala, desistência/W.O., último round→resultados→lobby, sem objetos/status herdados. Recusa de cast restaura previsão e não trava mana/CD.
6. Três servidores/seis clientes externos sob RTT 80–150 ms/perda 2%, mais serviços habituais; 60 min, Maré/zonas/Semente/Muralha/primeira síntese de sons/reconnect. Medir orçamento P0-04 e contagem de nós/memória por ciclo, sem inferir vazamento só de objeto retido ao encerrar teste.

## Discordancias provaveis com UX/tech

- **UX:** manter20 s de draft parece lento, mas encurtar sem confirmação rouba a escolha de runa. Aceitaria acelerar só com confirmação explícita de ambos.
- **UX:** nameplate através de parede facilita achar o amigo, mas invalida cobertura e furtividade; remover para avaliar balanceamento.
- **UX/design:** fixar Colapso na primeira alfa reduz variedade, mas permite medir equilíbrio sem modos atualmente inconsistentes. Não remover os outros modos definitivamente.
- **Design:** buffs no momento do impacto permitem combos emergentes; proponho snapshot no cast para Core cumprir “3 magias” e dar paridade host/cliente. Status periódicos precisam de política própria explícita.
- **Tech:** três processos são caminho menor que criar matchmaking/multi-arena dentro de singletons. Só aceitá-los após medir RAM/CPU agregados; não exigir reescrita de servidor preventivamente.
- **Tech:** remover trabalho visual/headless deve preservar colisão e simulação. Não cortar tickrate nem lag compensation para atingir orçamento antes de perfil real.
- **QA:** testes de resolução e FSM passam mesmo com runtime errado. Integração de36 comportamentos/duas visões e mortes simultâneas tem precedência sobre aumentar contagem de testes unitários.
- **Produto:** adiar dissolve, prévia do grimório e ajustes cosméticos é compatível com alfa; adiar autoridade, reset, pontuação e estabilidade de três salas não é.
