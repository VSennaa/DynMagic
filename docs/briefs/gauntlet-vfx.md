# Gauntlet M13 — peça "VFX por elemento" (DeepSeek)

Status: pronto (2026-09-26).

Problema (revisão A02): os quatro elementos usam o mesmo `BoxMesh` em `vfx/element_fx.gd`; só a cor muda. Em cinza, não dá para distinguir Fogo, Gelo, Raio e Vento.

## O que fazer
Edite **somente** `vfx/element_fx.gd`, crie `shaders/particle_glyph.gdshader` e `tools/vfx_capture.gd` + `tools/vfx_capture.tscn`. Não toque em mais nada (outro agente edita cenas, arenas e rede).

1. Troque o `BoxMesh` por `QuadMesh` com billboard (`BaseMaterial3D.BILLBOARD_PARTICLES` ou shader com billboard) usando `shaders/particle_glyph.gdshader` (spatial, `unshaded`, `blend_add` para Fogo/Raio, `blend_mix` para Gelo/Vento), que desenha a forma por SDF no UV — sem texturas externas:
   - **Fogo:** gota de chama (lágrima apontando para cima), núcleo branco-amarelo `#FFE9A8` → borda `#FF5A1F`, borda dura (toon, 2 degraus).
   - **Gelo:** losango/estilhaço alongado com uma aresta clara `#E8FBFF`, corpo `#6FD3FF`, sem glow; cai girando devagar.
   - **Raio:** traço em zigue-zague (3 segmentos) fino e muito brilhante `#F3E6FF` com halo `#C98BFF`; vida curta, tremido.
   - **Vento:** fita curva (arco de ~120°) semitransparente `#7CF2B0`, alongada na direção do movimento; gira em órbita.
   - Parâmetros por elemento via `INSTANCE_CUSTOM`/uniform `shape` (0–3). Rotação aleatória por partícula onde fizer sentido.
2. **Duas camadas** por sistema: a das formas acima + um brilho de núcleo (poucas partículas maiores, forma circular suave, 30% alpha) para dar volume. Total ainda ≤ 2.000 partículas (spec 07).
3. **Curvas de escala** (`scale_curve`): Fogo cresce e some, Gelo começa grande e encolhe, Raio pisca (0→1→0 rápido), Vento estica.
4. Mantenha a API pública (`trail`, `burst`) e as assinaturas.
5. `tools/vfx_capture.tscn`: cena que, rodando com janela 1920×1080, mostra os 4 elementos lado a lado (trail + burst de cada, fundo cinza médio `#5A5F6B`, câmera fixa, chão plano), espera 1 s e salva `res://build/gauntlet/<tag>_vfx.png` (tag via `-- --tag X`, padrão `v0`), depois sai. Também salve uma versão em escala de cinza `<tag>_vfx_gray.png` (converta a imagem antes de salvar).

## Verificação
- `Godot_v4.7.2-stable_win64_console.exe --headless --path D:\DynMagic --import` sem erros de script.
- Rode `tools/vfx_capture.tscn` com janela (sem `--headless`) com `-- --tag v1` e confira que as duas imagens existem.
- `res://build/check_suites.tscn` com 0 falhas.
- Sem commit. Ao terminar, troque o Status no topo por "pronto" e liste o que mudou.

Console Godot: `C:\Users\vinic\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.

## O que mudou

- `vfx/element_fx.gd`: `BoxMesh` → `QuadMesh` com billboard no vertex shader; cada elemento agora é um glifo SDF distinto via `shaders/particle_glyph.gdshader` (`shape` 0–3). Fogo = gota de chama (núcleo `#FFE9A8` → borda `#FF5A1F`, toon 2 degraus, `blend_add`); Gelo = estilhaço/losango alongado (aresta `#E8FBFF`, corpo `#6FD3FF`, `blend_mix`, cai girando); Raio = zigue-zague de 3 segmentos (núcleo `#F3E6FF` + halo `#C98BFF`, `blend_add`, vida curta/turbulência); Vento = fita em arco de ~120° (`#7CF2B0`, `blend_mix`, translúcida, orbita). Rotação aleatória por partícula onde faz sentido (Gelo).
- Duas camadas por sistema: glifos + brilho de núcleo (poucas partículas maiores, círculo suave, 30% alpha). Formas ≤ 1.600 + brilho ≤ 400 → total ≤ 2.000 partículas vivas (spec 07).
- Curvas `scale_curve` por elemento: Fogo cresce, Gelo começa grande e encolhe, Raio pisca (0→1→0), Vento estica.
- `blend_add`/`blend_mix` vêm do mesmo `.gdshader` (ShaderMaterial não tem blend em runtime): variante aditiva é reconstruída trocando o token do `render_mode`.
- API pública `trail`/`burst` e assinaturas preservadas.
- `tools/vfx_capture.gd` + `.tscn`: janela 1920×1080, 4 elementos lado a lado (trail + burst), fundo `#5A5F6B`, chão plano, espera ~1 s e salva `build/gauntlet/<tag>_vfx.png` + `<tag>_vfx_gray.png` (conversão para cinza antes de salvar), `-- --tag X` (padrão `v0`).

## Verificação

- `--import` sem erros de script.
- `res://build/check_suites.tscn`: **92 testes, 0 falhas**.
- `res://tools/vfx_capture.tscn` (com janela) `-- --tag v1`: `build/gauntlet/v1_vfx.png` e `v1_vfx_gray.png` gerados; os quatro matizes aparecem da esquerda para a direita (fogo/gelo/raio/vento) e a versão em cinza é realmente cinza com faixa de luminância ampla.
