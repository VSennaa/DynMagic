# Gauntlet M13 — peça "Arquitetura e props" (DeepSeek)

Status: pronto (2026-09-26).

O crítico cego (Gemini) comparou nossas arenas com a referência (Valorant Skirmish / Sea of Thieves) e apontou: "arquitetura monolítica: planos chapados sem pilares, rodapés, suportes ou alturas variadas" e "espaço estéril: faltam props que deem escala". Cor, luz e material das paredes já foram resolvidos em outra peça; **não mexa** em `shaders/`, `vfx/`, `scenes/arena/arena_environment.tres`, nem nas cores exportadas do builder.

## O que fazer
Crie `scenes/arena/arena_dressing.gd` (class_name `ArenaDressing`, `extends RefCounted`, só funções estáticas) e chame-o **uma vez no fim de `build()`** em `scenes/arena/arena_builder.gd` (única alteração permitida nesse arquivo, mais o que for preciso para passar referências). Todo o dressing fica sob um nó `Dressing` (Node3D) dentro do `Layout`, é **só visual** (sem colisão) e **não pode avançar mais de 0,2 m** para dentro da área jogável (não mudar métricas de corredor/cobertura do R3).

1. **Rodapé (plinth):** faixa de 0,55 m de altura, 0,18 m de profundidade, ao pé de todas as paredes do casco (use os nós `Wall*` e `Spawn*` existentes para achar posição e comprimento), cor = `wall_color.darkened(0.25)`.
2. **Cornija:** faixa no topo de cada parede, 0,35 m de altura, 0,3 m de balanço para os dois lados, cor = `wall_color.lightened(0.12)`.
3. **Pilastras:** a cada ~6 m ao longo das paredes laterais e de fundo, 0,9 m de largura, 0,18 m de profundidade, altura total da parede, cor = `wall_color.darkened(0.1)`; com capitel (0,3 m, 1,2 m de largura) no topo.
4. **Tampa nas coberturas:** em cada caixa de cobertura (os `CSGBox3D` criados por `_build_cover`), uma laje de topo 0,12 m de espessura com 0,08 m de balanço, cor = `cover_color.lightened(0.2)`.
5. **Props existentes sem uso** (`assets/models/*.glb`, instancie via `scenes/assets/<nome>.tscn` se existir, senão o `.glb`): `spawn_arch` na boca de cada spawn (centralizado na abertura da parede de fundo da arena, virado para o centro); `brazier` nos dois cantos internos de cada spawn; `banner` pendurado nas paredes laterais a cada ~12 m, a 5 m de altura, alternando lados; `pillar` nos quatro cantos da arena. Escala coerente (um mago tem 1,8 m).
6. Todos os materiais novos via `Toon.material(cor)` (ganham a alvenaria pintada automaticamente); props `.glb` passam pelo `asset_visual.gd` se usar a cena wrapper.

## Verificação
- `Godot_v4.7.2-stable_win64_console.exe --headless --path D:\DynMagic --import` sem erro de script.
- `res://build/check_suites.tscn` com 0 falhas, e os `tests/check_arena_spaces.tscn` e `tests/check_cloister.tscn` passando (rode headless).
- Capture com janela: `Godot_v4.7.2-stable_win64_console.exe --path D:\DynMagic res://tools/gauntlet_capture.tscn -- --tag d1` e confira `build/gauntlet/d1_*.png` (abra algumas e descreva o que vê).
- Sem commit. Ao terminar, troque o Status no topo para "pronto" e liste o que mudou.

Console Godot: `C:\Users\vinic\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.

## O que mudou

- **Novo** `scenes/arena/arena_dressing.gd` (`class_name ArenaDressing`, `extends RefCounted`, só funções estáticas). Cria um nó `Dressing` (Node3D) dentro do `Layout`, sem colisão, chamado uma vez no fim de `build()`.
  1. **Rodapé**: faixa 0,55 × 0,18 m ao pé de todas as paredes `Wall*`/`Spawn*` (posição/comprimento lidos do nó), `wall_color.darkened(0.25)`.
  2. **Cornija**: faixa 0,35 m no topo, balanço 0,3 m para os dois lados, `wall_color.lightened(0.12)`.
  3. **Pilastras**: a cada ~6 m nas paredes laterais e de fundo, 0,9 × 0,18 m, altura total, `wall_color.darkened(0.1)`, com capitel 0,3 m / 1,2 m no topo.
  4. **Tampa nas coberturas**: laje 0,12 m + balanço 0,08 m em cada caixa de cobertura (grupo `cover`), `cover_color.lightened(0.2)`.
  5. **Props** (via wrappers `scenes/assets/*.tscn` → `asset_visual.gd`): `spawn_arch` na boca de cada spawn (virado para o centro), `brazier` nos dois cantos internos de cada spawn, `banner` nas paredes laterais a cada ~12 m alternando lados (topo a 5 m), `pillar` nos quatro cantos da arena.
  6. Materiais novos via `Toon.material(cor)` (alvenaria pintada automática).
- **`scenes/arena/arena_builder.gd`**: única alteração — `ArenaDressing.apply(self, wall_color, cover_color)` no fim de `build()`.
- **Verificação**: `--import` sem erro; `check_suites.tscn` 92 testes / 0 falhas; `check_arena_spaces.tscn` e `check_cloister.tscn` 0 falhas (sightline 38,18 m inalterado); capture `-- --tag d1` gerou `build/gauntlet/d1_{a,b,c}_{spawn,mid,overview}.png`. Checagem estrutural confirmou 12 plinths, 12 cornijas, 24 pilastras/capitéis e 14 props por arena. Sem commit.
