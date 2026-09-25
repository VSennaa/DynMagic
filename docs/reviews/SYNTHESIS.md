# Síntese das revisões — rumo ao alfa 1.0

Fontes: `claude-gdd.md` (design/GDD), `claude-ux.md` (UX e sensação), `codex-tech.md` (rede, servidor), `codex-systems.md` (números, QA). Medição real da VPS feita pelo Claude em 2026-09-25 (seção 4).

## 1. Consenso (todos concordam — só executar)

| # | Item | Quem apontou | Esforço |
|---|---|---|---|
| C1 | Plaquinha do inimigo visível através de paredes (`player.gd:420`, `no_depth_test`) | todos | S |
| C2 | Confirmação de acerto para o atacante: evento `damage_applied` (agregado a cada 100 ms), hitmarker, som, número | GDD, UX | M |
| C3 | Morte e fim de round/partida com banner: quem venceu, por quê, magia final | GDD, UX | S–M |
| C4 | Ids crus na tela (`cold_blood`, `sudden_death`, `burn 2.3s`, `projectile 40%`, `fire`) → nomes em português + descrição de runas e elementos | GDD, UX, Sys | S |
| C5 | Painel do draft recriado a cada segundo (engole cliques) | UX | S |
| C6 | Sobrecarga (Núcleo) ilimitada para o convidado por 10 s | GDD, Sys | S |
| C7 | Morte simultânea decidida pela ordem de execução (`both_died()` nunca chamado) | GDD, Sys, Tech | S |
| C8 | Runa do perdedor sorteada assim que B escolhe o elemento (spec dá 20 s) | GDD, Sys, Tech | S |
| C9 | Reset de round incompleto; dano entre fases; lobby "pronto" pode reiniciar a partida | Sys, Tech | S–M |
| C10 | Servidor confia no cliente: posição de Marca/Muralha, números não saneados, recast/lockout | Tech, Sys | M |
| C11 | Snapshot não leva status/cooldown/morte/forças; muralha destruída continua sólida no cliente | Tech, Sys | M |
| C12 | Reconexão não remapeia o jogador no cliente que ficou; nome funciona como senha → token de sessão | Tech, Sys | M |
| C13 | "Entrar por IP" sem porta (salas 2 e 3 da VPS inacessíveis); mostrar IP do host; motivo de queda | Tech, UX | S |
| C14 | Onboarding: tela "Como jogar", treino guiado, cartão 3×3 no Tab | GDD, UX | S–M |
| C15 | Servidor headless roda HUD, animação, áudio sintetizado e FPS de cliente (144) | Tech (+ medição) | M |
| C16 | Primeira escolha do draft fixa pelo id (host sempre abre, inclusive no round 7) → sortear no início da partida | GDD, Sys | S |
| C17 | Magia recusada (sem mana/recarga/host) sem feedback; recarga local fica errada | UX, Tech | S |
| C18 | Documentação desalinhada (SDD §1 "3 teclas", specs 03–06, notas de release) | GDD, Sys | S |

## 2. Conflitos (precisam de decisão)

| # | Tema | Posições | Recomendação |
|---|---|---|---|
| D1 | **Seta + RMB domina** (1,33 dano/mana, CD 0,35 s) | GDD: 3 cargas + recast só em magias confirmadas · Sys: mexer só em números · UX: RMB é acessibilidade | 3 cargas na Seta + recast só em confirmadas |
| D2 | **Elementos** (Fogo mata com ~5 Setas, Vento com 8) | GDD: achatar (1,05/0,95/1,0/0,95) · Sys: primeiro cortar queimadura para 3 s, depois Fogo 1,10 / Vento 0,90, uma mudança por teste | Sys (incremental, medido) |
| D3 | **Overtime** (decisão sua: aleatório) | UX+Sys: Colapso fixo no alfa · GDD: Morte Súbita só se diferença de HP ≤ 15 | Colapso padrão no alfa; Aleatório como opção do lobby |
| D4 | **Draft** 10 s/lado | UX: 15 s no 1º round · Sys/Tech: janela fixa, fecha antes só se os dois confirmarem | Janela fixa com confirmação; 15 s no round 1 |
| D5 | **Informação do inimigo** | GDD: barras no topo, sem plaquinha · UX: ícone de Choque precisa aparecer | Barras no topo + ícones de status sobre o inimigo só com linha de visão |
| D6 | **Roda da mira** Q topo / E baixo-esq / R baixo-dir | UX: arco Q-E-R da esquerda para a direita (ordem do teclado) | Arco Q-E-R + marca de "rápida/confirmada" |
| D7 | **Previsão de cast no cliente** | UX: som/flash imediato · Tech: rollback complexo | Som + flash local já; previsão completa depois |
| D8 | **Replay do abate** (spec 02) | GDD/UX: cortar, fazer câmera de morte + cartão de dano | Cortar replay |
| D9 | **Tiro na cabeça** (na spec, não implementado) | GDD: remover · Sys: decidir | Remover da spec |
| D10 | **Nomes** | Raio × Tempestade, Leque × Cone, Overtime/Draft/Round | Glossário único travado (sugestão: Raio, Leque, Prorrogação, Escolha, Round) |
| D11 | **Espectador no alfa** | Tech: desligar no 1º alfa | Manter, sem bloquear o alfa |
| D12 | **Telemetria local** (JSON no host) | GDD: sim, com aviso · Tech: privacidade | Sim, com aviso no lobby |
| D13 | **3 duelos na VPS** | Tech: 3 processos (`dynmagic@.service`) · Claude: 1 processo multi-sala | Ver seção 4 |

## 3. Ordem proposta até o alfa 1.0

1. **Integridade** (C1, C6–C12, C16, C17): sem isso o placar não vale.
2. **Leitura** (C2–C5, C14, D5, D6, D10): o jogo se explica sozinho.
3. **Servidor** (C13, C15, D13): 3 salas na VPS com medição de 1 h.
4. **Balance** (D1–D4) com telemetria (D12) em playtest.
5. Docs (C18) em cada passo.

## 4. VPS — medição real (v0.3.1, 2026-09-25)

- Debian 13, **1 vCPU** Haswell, **929 MB RAM**, 6 GB swap (1,3 GB já usados), 7 GB de disco livre. Outros serviços: Docker (2 containers), nginx, python (~190 MB), hermes (~180 MB), opencode.
- Servidor parado: **~85 MB RSS**, 1–4% CPU cada. Três parados: RAM disponível caiu para **85 MB** (entrou em swap).
- Partida com 2 bots remotos (daqui → VPS): **~14% CPU** por duelo, 0 erros de rede, 2 rounds completos.
- Conclusão: CPU cabe (3 duelos ≈ 45%). **Memória é o gargalo.**
- Caminho: (1) C15 — servidor sem apresentação e 60 Hz fixo, medir de novo; (2) 3 processos com `MemoryMax` via `dynmagic@.service` (menor mudança, isola crash); (3) se não couber: plano de 2 GB ou mover hermes/python. Multi-sala num processo só se a medição exigir (esforço L).
