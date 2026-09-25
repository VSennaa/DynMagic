# Spec 02 — Loop de partida

## 1. Formato

- 1v1, melhor de 7 rounds (primeiro a 4 vence).
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
- Duração total da fase: 20 s.

### Runas (lista inicial)

| Runa | Efeito |
|---|---|
| Fôlego | Mana máxima 130 |
| Pressa | −20% em todos os cooldowns |
| Passo Leve | +12% velocidade de movimento |
| Casca | Começa o round com escudo de 25 |
| Foco | Projéteis +20% velocidade |
| Eco | Recast (`RMB`) custa −30% mana |
| Sangue Frio | Abaixo de 30 HP, +20% dano |

## 4. Aquisição de vantagem

1. **Runa do perdedor.** Mecânica de catch-up que não pune quem vence.
2. **Núcleo Arcano.** Spawna no centro da arena aos 30 s de combate (60 s no relógio). Captura: ficar 2,5 s dentro de um raio de 2 m sem tomar dano. O progresso é mantido se o jogador sair. Dar dano no capturador reseta o progresso dele. Recompensa: **Sobrecarga** por 10 s ou 3 magias, o que acabar antes. Magias custam 0 de mana e causam +20% de dano. O Núcleo spawna só 1 vez por round.
3. **Contra-escolha.** Quem escolhe o elemento em segundo vê a escolha do oponente e pode responder a ela.

## 5. Overtime (relógio chega a 0:00 com os dois vivos)

O padrão do alfa é **Colapso** (D3). No lobby, o host pode fixar Colapso, Morte Súbita ou Maré de Mana, ou escolher "Aleatório". O nome da regra aparece em destaque por 2 s.

| Regra | Comportamento | Fim |
|---|---|---|
| **Colapso** | Zona circular fecha das bordas até um raio de 5 m no centro em 20 s. Fora da zona: 12 dano/s | Morte. Se os dois morrem no mesmo tick, vence quem tinha mais HP antes do tick |
| **Morte Súbita** | HP dos dois vai para 1. Escudos removidos. Status de dano por tempo desativado | Primeiro acerto. Depois de 30 s, entra Colapso |
| **Maré de Mana** | Mana infinita, cooldowns −50% por 20 s | Depois de 20 s, entra Colapso |

Timeout absoluto: 60 s de overtime. Depois disso, vence quem tem mais HP. Empate de HP: vence quem capturou o Núcleo. Sem captura: round empatado e ninguém pontua.

## 6. Round decisivo (3-3)

- Arena sorteada entre A, B e C, sem repetir a anterior.
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
