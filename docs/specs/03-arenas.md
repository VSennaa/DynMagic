# Spec 03 — Arenas

## 1. Layout base (comum às 3 variantes)

Inspirado na imagem de referência (Skirmish do Valorant). Não é uma réplica.

```
            ┌───────┐
            │ SPAWN │  7 × 7 m, norte
      ┌─────┘       └─────┐
     ◤│                   │◥
    ◤ │                   │ ◥   alas laterais: varandas elevadas (+1,5 m)
   ▐  │      ARENA        │  ▌  acessíveis por rampa, limitam a borda
    ◣ │    28 × 38 m      │ ◢
     ◣│                   │◢
      └─────┐       ┌─────┘
            │ SPAWN │  7 × 7 m, sul
            └───────┘
```

- Área principal: 28 m (X) × 38 m (Z). Pé-direito: 8 m, com teto invisível.
- Corredores de spawn: 7 × 7 m, com barreira até o fim do COUNTDOWN.
- **Alas laterais** (as cunhas vermelhas da referência): varandas elevadas em 1,5 m com rampas nas pontas. Dão altura para Marca e Semente e risco de exposição. Borda com parapeito de 1 m.
- **Simetria de rotação de 180°** no eixo Y (centro da arena). O spawn norte vê exatamente o que o spawn sul vê.
- Nichos de cobertura na parede (os pequenos retângulos nas bordas da referência): 1,5 × 1 m.
- Grade de 0,5 m para todo o greybox.

## 2. Tipos de cobertura

| Tipo | Tamanho (L × P × A) | Uso |
|---|---|---|
| Caixa baixa | 1,5 × 1,5 × 1,0 m | Cobertura agachado, dá para pular em cima |
| Caixa alta | 1,5 × 1,5 × 2,2 m | Bloqueia linha de visão |
| Par de caixas | 3 × 1,5 × (1,0 + 2,2) m | Degrau para subir |
| Barra | 4,5 × 1,2 × 1,4 m | Cobertura longa |
| Pilar central | 3 × 3 × 3 m | Quebra a linha de visão spawn-spawn |

Toda cobertura bloqueia projéteis. Muralha de Vento é a exceção documentada na spec 01.

## 3. Variantes

### Arena A — "Claustro" (referência: painel esquerdo)
- Pilar central 3 × 3 m no centro.
- 2 caixas baixas no eixo X central, a 5 m do pilar.
- 4 pares de caixas giradas 20° a 30°, 1 em cada quadrante.
- 4 nichos de parede (2 por lado).
- Leitura: simétrica e aberta. Arena de aprendizado. Favorece projéteis.

### Arena B — "Pátio Partido" (referência: painel central)
- 1 caixa alta pequena no centro exato.
- 2 barras horizontais a 11 m do centro, na frente de cada spawn.
- 2 grupos em "L" giradas (barra + caixa), diagonais opostas.
- 2 caixas altas soltas, diagonais opostas.
- Nicho grande em uma parede de cada lado, com posição espelhada pela rotação.
- Leitura: diagonais longas. Favorece Marca e Impulso.

### Arena C — "Espinha" (referência: painel direito)
- **Espinha central:** muro segmentado de 12 m no eixo Z, com 2 frestas de 1 m.
- 2 blocos em "L" colados à espinha, lados opostos.
- Estruturas em "T" nas duas paredes laterais (a meia altura).
- 2 pares de caixas e 2 caixas altas soltas nos quadrantes.
- Leitura: combate em corredores. Favorece Leque, Muralha e emboscada.

A variante é escolhida no lobby: Fixa A, B, C, Rotação (padrão: A, B, C e repete) ou Aleatória.

## 4. Elementos dinâmicos

- **Núcleo Arcano:** pedestal no centro geométrico. Na Arena A fica em cima do pilar, com rampa curta. Na Arena C fica numa fresta da espinha.
- **Zona de Colapso:** cilindro com shader de borda. Centro no centro da arena.
- **Kill plane:** Y = −10 m. Mata e conta como morte normal.

## 5. Implementação

- `arena_base.tscn`: piso, paredes, alas, spawns, iluminação, WorldEnvironment, ponto do Núcleo, colapso.
- `arena_a.tscn`, `arena_b.tscn`, `arena_c.tscn` herdam de `arena_base` e só adicionam o nó `Cover`.
- Cobertura com `StaticBody3D` + `BoxShape3D`. Nada de colisão de malha complexa em v1.
- Posições de cobertura geradas por script de editor (`tools/build_arena.gd`) a partir de uma tabela com metade do mapa. O script espelha a outra metade por rotação de 180° e garante a simetria.
- Iluminação: 1 `DirectionalLight3D` com sombra suave + `LightmapGI` ou SDFGI desligado para performance.

## 6. Critérios de aceite

- [ ] Nenhum ponto de spawn tem linha de visão para o outro spawn.
- [ ] Teste automático: raycast do spawn norte para o sul bate em cobertura nas 3 variantes.
- [ ] Todas as coberturas são alcançáveis ou contornáveis sem ficar preso (teste com o Impulso).
- [ ] O script de espelhamento gera posições com diferença de no máximo 1 mm.
- [ ] 144 FPS numa GPU média (GTX 1660) em 1080p.
