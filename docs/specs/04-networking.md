# Spec 04 — Rede

## 1. Topologia

- **Listen server:** um jogador hospeda (host = servidor + jogador); o outro entra como cliente.
- Transporte: `ENetMultiplayerPeer`, porta UDP **7777** (configurável).
- Descoberta LAN: broadcast UDP na porta **7778**.
- Máximo 2 jogadores + até 4 espectadores (espectador fica fora de v1, mas a API reserva o papel).
- Tick de física: 60 Hz. Snapshot do host para o cliente: 30 Hz.

## 2. Descoberta LAN

```
Host:    a cada 1 s, broadcast em 255.255.255.255:7778
         {"g":"dynmagic","v":<proto>,"name":<lobby>,"port":7777,"players":1,"state":"lobby"}
Cliente: escuta 7778, lista lobbies com v igual e remove os que somem por 3 s.
```

- `PacketPeerUDP` com `set_broadcast_enabled(true)`.
- Também existe entrada manual por IP.
- Versão do protocolo (`NET_PROTOCOL_VERSION`) diferente: o lobby aparece desabilitado com o aviso "versão diferente".

Protocolo atual: **2** (tempo de composição no pedido de conjuração e recuperação de estado na reconexão).

## 3. Handshake

1. O cliente conecta. O host recebe `peer_connected`.
2. O cliente envia `rpc_hello(proto_version, player_name, settings_hash)`.
3. O host valida a versão. Se falhar: `rpc_reject(reason)` e desconecta.
4. O host envia `rpc_lobby_state(state)`.
5. Os dois marcam "pronto". O host inicia `LOADING`.
6. Os dois enviam `rpc_loaded()`. O host vai para `DRAFT`.

## 4. Autoridade

| Estado | Dono | Sincronização |
|---|---|---|
| Fase e relógio da partida | Host | RPC reliable em cada mudança + tempo do servidor |
| Posição e velocidade do jogador | Host (com previsão no cliente) | Input do cliente → host; snapshot do host → cliente |
| Rotação da câmera (yaw/pitch) | Cliente | Vai junto com o input; o host confia (LAN) |
| HP, mana, escudo, status, cooldown | Host | Snapshot |
| Sequência do `SpellComposer` | Cliente | O slot atual e o modo de mira vão no input para mostrar o círculo rúnico ao oponente |
| Elemento do round | Host | Definido no draft; o cliente não envia elemento ao conjurar |
| Magias ativas (projéteis, zonas, muralhas) | Host | Spawn/despawn por RPC reliable; projétil é simulado nos dois lados de forma determinística |
| Núcleo, colapso | Host | Snapshot |

## 5. Movimento

- O cliente envia `InputFrame` a cada tick físico, sem reliability, com os 3 últimos frames repetidos para cobrir perda:
  ```
  InputFrame { seq:u32, move:Vector2, yaw:f32, pitch:f32,
               buttons:u8 (jump, crouch, sprint), composer_state:u8 }
  ```
- O cliente aplica o input no próprio `CharacterBody3D` na hora (previsão) e guarda um histórico de 1 s.
- Snapshot do host traz `last_processed_seq` + posição/velocidade autoritativas.
- Reconciliação: se o erro for maior que 5 cm, volta para o estado do servidor e reaplica os inputs pendentes. Erro menor: corrige suavemente em 100 ms.
- O oponente é mostrado com interpolação e buffer de 100 ms.
- Impulsos (dash) são previstos. Teleporte de Raio é aplicado só depois da confirmação do host, com efeito visual local imediato.

## 6. Conjuração

```
Cliente: disparo (rápida) ou LMB (confirmada) ─► toca VFX/som local de conjuração
        ─► rpc_id(1, "req_cast", seq, form, effect, origin, dir, target_point, client_time)
Host:   usa o elemento do round registrado no draft
        valida (vivo, fase COMBAT/OVERTIME, mana, cooldown, origem até 1,5 m da posição autoritativa,
                target_point dentro do alcance da magia)
        ├─ ok   ─► aplica custo ─► spawn autoritativo ─► rpc "spell_spawned"(id, spell_key, owner, origin, dir, server_tick)
        └─ erro ─► rpc_id(peer, "cast_rejected", seq, reason) ─► cliente cancela o VFX
```

- Projéteis: os dois lados simulam a partir de `origin`, `dir`, `speed` e `server_tick`. O cliente adianta o projétil pelo atraso conhecido. **Só o host** detecta colisão e aplica dano.
- Leque (instantâneo): o host usa compensação de lag. Ele guarda 250 ms de histórico de posição e volta o alvo para `client_time` antes de testar o cone.
- Resultado de dano: `rpc "damage_applied"(target, amount, source_spell, new_hp, status)` reliable. Serve para hitmarker e número de dano.

## 7. Orçamento de banda

Cliente → host: ~64 B × 60 Hz ≈ 4 KB/s. Host → cliente: snapshot ~200 B × 30 Hz ≈ 6 KB/s + eventos. Sem problema em LAN.

## 8. Canais ENet

| Canal | Modo | Uso |
|---|---|---|
| 0 | reliable | Lobby, fase, spawn/despawn de magia, dano, chat |
| 1 | unreliable | InputFrame |
| 2 | unreliable_ordered | Snapshot |

## 9. Ferramentas de teste

- Lançar 2 instâncias locais: `godot --path . -- --host` e `godot --path . -- --join 127.0.0.1`.
- Simulador de rede em debug: latência, jitter e perda configuráveis no host (wrapper sobre o envio).
- Overlay de rede (`F3`): ping, perda, erro de reconciliação, tick.

## 10. Critérios de aceite

Reconexão: o host reserva o slot pelo nome normalizado do handshake (espaços externos removidos, até 24 caracteres; comparação exata). Durante os 30 s, pausa a simulação da arena e mantém jogador, magias e estatísticas. Outro nome é rejeitado. O novo peer assume o slot; após carregar a arena, recebe estado autoritativo de jogadores, efeitos e objetos ativos antes da retomada. O prazo não é acelerado por `--match-speed`; expiração resulta em W.O. Não há migração de host.

- [ ] O cliente encontra o host pela descoberta LAN em menos de 2 s.
- [ ] Versão incompatível é rejeitada com mensagem clara.
- [ ] Com 80 ms de latência simulada e 2% de perda, o próprio movimento não tem correção visível em linha reta.
- [ ] O cliente não consegue causar dano sem validação do host.
- [ ] Desconectar e reconectar em até 30 s volta para a partida (mesmo nome de jogador).
- [ ] 2 instâncias locais jogam uma partida completa sem erro no log.
