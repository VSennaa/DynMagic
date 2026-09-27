# Gauntlet M13 — peça "Color grade e contorno" (DeepSeek)

Status: pronto (2026-09-27).

Lacunas do crítico cego: "falta um color grade unificado" e (revisão A10) "contorno com espessura fixa em pixels".

Edite **somente**: `scenes/arena/arena_environment.tres`, `shaders/outline.gdshader`, `vfx/toon.gd`, novos arquivos em `shaders/`. Outros agentes editam arenas, rede, partida e assets: não toque.

## Tarefas
1. **Color grade**: crie uma LUT 3D procedural (`Texture3D` gerada por script `tools/build_grade_lut.gd` salvando `shaders/grade_lut.tres`, ou `adjustment_color_correction` com `GradientTexture1D`/`Texture3D`) com: sombras levemente puxadas para lilás `#3B3350`, meios-tons quentes, altas levemente creme `#FFF3DD`; saturação +8% nos meios, contraste suave em S. Aplique em `arena_environment.tres` (`adjustment_color_correction`). Deve ser sutil: nada de cor chapada.
2. **Contorno por distância** em `shaders/outline.gdshader`: espessura 2,0 px perto (< 5 m) caindo para 0,8 px longe (> 40 m), usando a profundidade linear; mantenha a cor da tinta atual. Evite serrilhado no horizonte (sem contorno no céu).
3. Não mude a API de `Toon.add_outline()`.

## Verificação
- `C:\Users\vinic\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path D:\DynMagic --import` sem erro dos seus arquivos; `res://build/check_suites.tscn` 0 falhas.
- Captura com janela: `...console.exe --path D:\DynMagic res://tools/gauntlet_capture.tscn -- --tag c1` (o contorno só aparece em câmeras de jogador; tudo bem).
- Sem commit. Troque Status para "pronto" e liste o que mudou.

## O que mudou
1. **Color grade** — LUT 1D procedural (`GradientTexture1D`, gerada por `tools/build_grade_lut.gd`, salva em `shaders/grade_lut.tres`) aplicada como `adjustment_color_correction` em `scenes/arena/arena_environment.tres`. A LUT 1D é a opção persistível do Godot 4 (o `Texture3D`/`ImageTexture3D` é só runtime — `PROPERTY_USAGE_RESOURCE_NOT_PERSISTENT`, não serializa para `.tres`). Curva por canal: sombras levemente lilás `#3B3350` (lift ~0,02–0,03), meios quentes (R +0,012 / B −0,018), altas levemente creme `#FFF3DD` (branco → `(1.0, 0.993, 0.978)`), contraste suave em S (0,10). `adjustment_saturation` mantido em 1,08 (+8%).
2. **Contorno por distância** — `shaders/outline.gdshader`: `thickness` fixo substituído por `thickness_near`/`thickness_far`/`distance_near`/`distance_far` (2,0 px < 5 m → 0,8 px > 40 m, via `smoothstep` sobre a profundidade linear); cor da tinta mantida; corte de céu suavizado (`smoothstep(55, 80, d)`) para evitar serrilhado no horizonte e nunca desenhar contorno no céu.
3. `Toon.add_outline()` inalterado (o quad continua com os defaults do shader, que agora aplicam a espessura por distância).

