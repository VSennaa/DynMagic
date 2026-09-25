# Spec 05 — Controle do jogador

## 1. Nós

```
Player (CharacterBody3D)
├─ CollisionShape3D        cápsula r=0,35 m, h=1,8 m
├─ Head (Node3D)           y=1,6 m
│  ├─ Camera3D             FOV configurável (padrão 95)
│  │  └─ FPArms            braços em 1ª pessoa, SubViewport ou camada de render própria
│  └─ CastOrigin (Marker3D) 0,3 m à frente, 0,2 m abaixo da câmera
├─ ThirdPersonModel        visível só para o oponente (camadas de render)
│  └─ RuneCircle           círculo de composição visto pelo oponente
├─ Hurtbox (Area3D)        cabeça (×1,5 dano) e corpo
├─ SpellComposer (Node)
├─ Stats (Node)            HP, mana, escudo, status, cooldown
└─ NetSync (Node)          previsão, reconciliação, interpolação
```

## 2. Movimento

| Parâmetro | Valor |
|---|---|
| Andar | 5,5 m/s |
| Correr (segurar `Shift`) | 7,5 m/s, não conjura enquanto corre; a primeira tecla do composer cancela o sprint |
| Agachar (`Ctrl`) | 3 m/s, altura 1,2 m |
| Pulo | 1,2 m de altura |
| Aceleração no chão / no ar | 60 / 15 m/s² |
| Gravidade | 22 m/s² |
| Coyote time | 0,1 s |
| Degrau automático | 0,35 m |

Sem mira com zoom. Sem queda de dano por altura.

## 3. Vida, mana, status

- HP 100. Sem regeneração de HP.
- Mana 100, regenera 12/s. A regeneração pausa por 0,5 s depois de cada conjuração.
- Escudo absorve dano antes do HP e some quando acaba a duração.
- Status acumula duração do mesmo tipo até o máximo de 2× a duração base. Não acumula intensidade.
- Headshot: ×1,5 só para Seta e Orbe (acerto direto).

## 4. Conjuração em 1ª pessoa

- Tecla de forma: os braços fazem uma pose (mão aberta, punho, palma ao chão) e o círculo rúnico aparece na frente das mãos.
- Tecla de efeito: o anel externo do círculo muda de estilo.
- Disparo (na hora para magia rápida, no `LMB` para magia confirmada): animação de 0,12 s.
- Modo de mira: uma mão fica erguida com o círculo rúnico aceso. Movimento normal, sem sprint.
- Na conjuração, o projétil sai de `CastOrigin` com direção corrigida para o ponto que a mira toca (raycast de 100 m).
- Lockout de 0,15 s depois de cada conjuração. Inputs nesse tempo entram no buffer.

## 5. Morte

- HP em 0: modelo em ragdoll simples ou dissolve com shader de tinta.
- Câmera vai para 3ª pessoa orbitando o cadáver por 3 s.
- O `SpellComposer` limpa. Magias persistentes do morto continuam até expirar.

## 6. Critérios de aceite

- [ ] Movimento idêntico no modo offline e no modo host.
- [ ] Nenhum dos parâmetros acima está hardcoded: todos vêm de `PlayerTuning.tres`.
- [ ] O projétil sempre sai na direção do ponto sob a mira, mesmo com parede perto.
- [ ] Braços em 1ª pessoa não atravessam paredes (camada de render separada).
