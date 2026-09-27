# Gauntlet M13 — peça "Quebrar a repetição e fogo com volume" (DeepSeek)

Status: pronto (2026-09-27).

## O que mudou
- `shaders/toon.gdshader` (ramo `procedural_surface`, coords de mundo): decalques novos — musgo/hera no pé das faces verticais em manchas (ruído 3–6 m, verde `#6E8B4E`→`#9DB36A`, mais forte longe do sol, nunca no chão), rachaduras finas escuras em ~10% dos blocos (1–2 traços dentro do bloco), poeira/areia clareando+amarelando ~0,5 m junto às bases das paredes no chão, e variação de tom do chão em manchas de 4–8 m (±10% valor + leve hue). Novos uniformes: `sun_dir` (direção do sol da arena), `arena_half` (meia-extensão 14×19) e intensidades `moss/crack/dust/region_strength`.
- `shaders/flame_mesh.gdshader` (novo): spatial, unshaded, `blend_add`, `cull_disabled`, `depth_draw_never`; chama em teardrop erodida por ruído rolando para cima com `TIME`, 3 bandas toon (núcleo `#FFF1C2`, meio `#FFB13B`, borda `#FF5A1F`).
- `scenes/arena/arena_dressing.gd`: cada braseiro ganha malha de chama `Flame` (3 quads cruzados verticais ~0,6 m, sem sombra) com o shader novo; as partículas viram faíscas menores (14, escala 0,3–0,6, em y≈1,55) por cima da chama; a luz tremulando continua; `FacetedFlame` segue oculto.
- `scenes/arena/arena_environment.tres`: `ssao_intensity` 2,2, `ssao_detail` 0,8, `glow_hdr_threshold` 1,5 (glow só no fogo) e `glow_intensity` 0,35. SDFGI/VoxelGI não ligados.
- Verificação: `--import` limpo; `res://build/check_suites.tscn` → **114 testes, 0 falhas**; captura com janela `-- --tag l3` gerou os 9 PNGs (`build/gauntlet/l3_{a,b,c}_{spawn,mid,overview}.png`). Sem commit.

Crítico cego (Gemini) na rodada e3, distância "longe": (1) texturas repetem em grade, faltam decalques e variação; (2) fogo dos braseiros parece sprite 2D barato; (3) iluminação ainda chapada.

Edite **somente**: `shaders/toon.gdshader`, `shaders/particle_glyph.gdshader`, `vfx/element_fx.gd`, `scenes/arena/arena_dressing.gd`, `scenes/arena/arena_environment.tres`, novos arquivos em `shaders/` e `vfx/`. Outros agentes editam arenas (`scenes/arena/*` exceto dressing/environment), rede/partida e `assets/`: não toque.

## Tarefas
1. **Decalques procedurais** no ramo `procedural_surface` de `toon.gdshader`, em coordenadas de mundo, com máscaras de ruído de baixa frequência (células de 3–6 m) para não repetir:
   - **Musgo/hera** subindo do pé das paredes em manchas (verde `#6E8B4E` → `#9DB36A`), mais forte em faces viradas para longe do sol; nunca no chão central.
   - **Rachaduras** finas e escuras em ~10% dos blocos (padrão dentro do bloco, 1–2 traços).
   - **Poeira/areia** acumulada no chão junto às paredes (clareia e amarela 0,5 m ao redor da base).
   - **Variação de tom entre regiões** do chão (manchas grandes de 4–8 m, ±10% valor e leve hue).
2. **Fogo com volume** nos braseiros (`arena_dressing.gd` + VFX): adicione uma **malha de chama** (3–4 quads cruzados verticais, ~0,6 m) com shader novo `shaders/flame_mesh.gdshader` (spatial, unshaded, blend_add, sem culling): forma de chama por ruído rolando para cima com `TIME`, 3 bandas toon (núcleo `#FFF1C2`, meio `#FFB13B`, borda `#FF5A1F`), borda erodida. Mantenha as partículas de faísca por cima (menos, menores). A luz tremulando continua.
3. **Profundidade de luz**: em `arena_environment.tres`, teste `ssao_intensity` 2,2 e `ssao_detail` 0,8, e um leve `glow` só no fogo (limiar alto). Não ligue SDFGI/VoxelGI (custo).

## Verificação
- `C:\Users\vinic\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path D:\DynMagic --import` sem erro vindo dos seus arquivos; `res://build/check_suites.tscn` com 0 falhas.
- Captura com janela: `...console.exe --path D:\DynMagic res://tools/gauntlet_capture.tscn -- --tag l3`. Não descreva as imagens se não puder vê-las; só confirme que foram geradas.
- Sem commit. Troque Status para "pronto" e liste o que mudou.
