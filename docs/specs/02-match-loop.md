# Spec 02 — Loop de partida

## 1. Formato

- 1v1, 2v2 e 3v3: eliminação, melhor de 7 rounds (primeiro a 4 vence). 5v5 mantém Controle MD3, sem runas/Sobrecarga, conforme `docs/reviews/r2-decisions.md`.
- 1 vida por round. HP 100, mana 100.
- Round de combate: 90 s.
- Troca de lado (spawn norte/sul) a cada round.
- Placar 3-3 leva ao **round decisivo** (seção 6).

## 2. Máquina de estados (`MatchState`, só no host)

```
LOBBY
  └─► LOADING            carrega arena, espera os 2 jogadores confirmarem
       └─► DRAFT         20 s (A escolhe 10 s, B escolhe 10 s), relógio mostra 0:00
            └─► COUNTDOWN 3 s, jogadores presos no spawn
                 └─► COMBAT 90 s
                      ├─ morte ─────────────► ROUND_END (3 s, replay da câmera do killer)
                      └─ tempo 0 ───► OVERTIME ─► ROUND_END
ROUND_END
  ├─ alguém com 4 ──► MATCH_END ─► RESULTS
  ├─ placar 3-3 ────► DRAFT (decisivo)
  └─ senão ─────────► DRAFT
```

Toda transição é decidida pelo host e enviada por RPC `match_phase_changed(phase, t_end_server, payload)`. O cliente só desenha.

Desconexão de um jogador em qualquer fase: pausa de 30 s. Se não voltar, o outro vence por W.O.

## 3. Draft (fase 0:00)

Cada jogador tem **1 elemento por round**. O elemento é escolhido de novo em todo round, em ordem.

Ordem:

1. **Lado A escolhe** (10 s). Lado A = jogador no spawn norte naquele round.
2. **Lado B escolhe** (10 s). O elemento de A aparece travado. B não pode escolher o mesmo.
3. O perdedor do round anterior escolhe 1 runa entre 3 sorteadas durante os 20 s inteiros, em paralelo.

Como os lados trocam a cada round, a primeira escolha alterna entre os jogadores.

| Round | Escolhas |
|---|---|
| 1 | Elemento (A primeiro, depois B) |
| 2+ | Elemento de novo, na ordem do lado + runa para o perdedor do round anterior |
| Decisivo | Elemento na ordem do lado + runa para os dois |

- Sem escolha no fim do tempo: o host sorteia entre os elementos válidos.
- Os dois jogadores nunca têm o mesmo elemento no mesmo round.
- A runa vale só para o round seguinte.
- Duração total da fase: 30 s no primeiro round (15 s por lado), 20 s nos seguintes. Encerra cedo somente quando todos confirmam elemento e, quando oferecida, runa.

### Runas de adaptação (R9 aprovado)

A oferta contém uma runa de **recurso** (Fôlego/Eco), uma de **deslocamento/execução** (Passo Leve/Foco) e **defesa** (Casca). Pressa e Sangue Frio estão fora deste pool experimental. No decisivo, todos recebem a mesma oferta; cada cliente recebe somente sua própria escolha até o fim do draft. Não há acúmulo entre rounds. Em times de eliminação, todos os integrantes do time perdedor recebem a oferta.

| Runa | Efeito |
|---|---|
| Fôlego | Mana máxima 130 |
| Passo Leve | +12% velocidade de movimento |
| Casca | Começa o round com escudo de 25 |
| Foco | Projéteis +20% velocidade |
| Eco | Recast de magia confirmada (`RMB`) custa −30% mana |

## 4. Aquisição de vantagem

1. **Runa do perdedor.** Mecânica de catch-up que não pune quem vence.
2. **Núcleo Arcano (R8).** Pedestal visível e inativo desde o começo. Anúncio/anel aos 20 s; captura habilitada aos 30 s. Ficar 2,5 s no raio de 2 m, no mesmo piso, captura uma vez por round. Inimigos presentes pausam a captura; aliados não contestam nem aceleram. Dano, inclusive absorvido por escudo, reseta o progresso do atingido. Ao sair, há 1 s de tolerância e então perda de 1 s de progresso por segundo fora. Sobrecarga: 3 conjurações ou 10 s, mana grátis, **sem bônus de dano**, sem reset de cooldown/cargas. G mantém o custo-base reservado durante o buff; a reserva é liberada ao disparar e o custo corrente é aplicado nessa validação. Não se pode guardar uma magia sem mana para cobrir a reserva-base, mesmo com Sobrecarga ativa.
3. **Contra-escolha.** Quem escolhe o elemento em segundo vê a escolha do oponente e pode responder a ela.

### Ritmo do round

- 0–20 s: sondagem/preparação; 20–30 s: anúncio da disputa.
- 30–60 s: disputa e conversão da vantagem; o Núcleo não reaparece depois de capturado.
- 60–90 s: convergência. No Colapso padrão, círculo de aviso em R=5 indica quais aproximações ficarão fora da zona, sem causar dano.
- 90–110 s: Colapso R=24→5; 110–125 s: fechamento final R=5→2, mantendo 12 dano/s.
- Limite absoluto continua em 150 s (90+60), com o mesmo desempate. Morte Súbita e Maré preservam suas durações e seu Colapso até R=5; o experimento R=2 vale apenas para Colapso padrão em eliminação.

## 5. Overtime (relógio chega a 0:00 com os dois vivos)

O padrão do alfa é **Colapso** (D3). No lobby, o host pode fixar Colapso, Morte Súbita ou Maré de Mana, ou escolher "Aleatório". O nome da regra aparece em destaque por 2 s.

| Regra | Comportamento | Fim |
|---|---|---|
| **Colapso** | Zona circular fecha das bordas até um raio de 5 m no centro em 20 s e depois até 2 m em mais 15 s (eliminação). Fora da zona: 12 dano/s | Morte. Se os dois morrem no mesmo tick, vence quem tinha mais HP antes do tick |
| **Morte Súbita** | HP dos dois vai para 1. Escudos removidos. Status de dano por tempo desativado | Primeiro acerto. Depois de 30 s, entra Colapso |
| **Maré de Mana** | Mana infinita, cooldowns −50% por 20 s | Depois de 20 s, entra Colapso |

Timeout absoluto: 60 s de overtime. Depois disso, vence quem tem mais HP. Empate de HP: vence quem capturou o Núcleo. Sem captura: round empatado e ninguém pontua.

## 6. Round decisivo (3-3)

- Rotação: **A,A,B,B,C,C,A**, anunciada no lobby. Cada par repete a geometria com lados/primeira escolha trocados; o decisivo retorna a A. Rounds adicionais por empate permanecem em A.
- Nas opções fixa e aleatória, preserva-se a regra anterior do decisivo: sorteio entre A/B/C sem repetir a arena anterior.
- O intervalo mostra a arena repetida, os elementos rivais e a causa do fim/capturador do Núcleo no último round.
- Os dois recebem runa.
- Overtime sempre Colapso, para garantir fim.

## 7. Estatísticas de fim de partida

Por jogador: rounds vencidos, dano causado, dano recebido, precisão por forma, magia mais usada, Núcleos capturados, tempo médio de composição (tecla até conjuração).

O cliente mede da primeira tecla de forma até o disparo, incluindo espera de input em buffer e mira. Envia a duração com o pedido; o host só acumula conjurações aceitas. Cancelamentos, timeouts, rejeições e recasts (`RMB`, sem tecla de forma) não entram na média. Sem amostras, resultados mostram `—`.

## 8. Critérios de aceite

- [ ] Partida MD7 completa roda do lobby até os resultados em LAN.
- [ ] O cliente nunca muda fase sozinho.
- [ ] Draft em ordem: B só escolhe depois de A. O host rejeita elemento repetido.
- [ ] A primeira escolha alterna entre os jogadores a cada round.
- [ ] A runa do oponente fica oculta até o fim do draft.
- [ ] Cada regra de overtime pode ser forçada por flag de debug e termina o round.
- [ ] Desconexão gera W.O. depois de 30 s.
- [ ] Teste cobre todas as transições da FSM, incluindo 3-3 e empate de round.
