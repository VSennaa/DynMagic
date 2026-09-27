# Gauntlet M13 — peça "Céu, bisel, sujeira e fogo" (DeepSeek)

Status: pronto (2026-09-26).

Veredito do crítico cego (Gemini) na rodada d2 contra a referência (Valorant Skirmish / Sea of Thieves), distância "longe":
1. Geometria primitiva: faltam **biséis** nas arestas para pegar luz e suavizar silhuetas.
2. Texturas repetitivas: faltam **gradientes, desgaste de borda e sujeira**.
3. Fogo dos braseiros são **triângulos estáticos opacos**.
4. **Céu morto e desbotado** achata o horizonte: falta cúpula estilizada pintada.

Edite **somente** os arquivos citados abaixo. Outro agente edita rede, partida, HUD e `scenes/arena/arena_builder.gd`: não toque neles.

## Tarefas
1. **Céu pintado** — crie `shaders/stylized_sky.gdshader` (`shader_type sky`): gradiente de três faixas (zênite `#4F7FC4`, meio `#9FB6E0`, horizonte quente `#F4CFA0`), sol com disco duro e halo largo seguindo `LIGHT0_DIRECTION` (cor `#FFE2B0`), e **nuvens estilizadas** em camadas (ruído fbm quantizado em 3 degraus, bordas duras tipo toon, lado iluminado creme `#FFF4E0` e sombra lilás `#B7A6D6`), movendo devagar com `TIME`. Em `scenes/arena/arena_environment.tres`, troque o `ProceduralSkyMaterial` por um `ShaderMaterial` com esse shader (mantenha todos os outros parâmetros do ambiente).
2. **Bisel falso + sujeira** em `shaders/toon.gdshader`, só no ramo `procedural_surface`: (a) escurecer 0–25% a 0,4 m das arestas horizontais inferiores de cada parede/caixa (sujeira que sobe do chão — já existe um `foot`, amplie com ruído de manchas); (b) clarear 15% uma faixa de ~4 cm nas arestas externas de cada bloco de pedra (topo e lado esquerdo do tijolo, simulando bisel pegando luz); (c) manchas de desgaste de baixa frequência (ruído 0,3–0,6 m) que clareiam/escurecem ±8%. Não mude a API nem os uniforms existentes; novos uniforms com padrão que mantenha objetos texturizados intactos.
3. **Fogo dos braseiros** em `scenes/arena/arena_dressing.gd`: em cada braseiro, adicione `ElementFx.trail(&"fire", Color("ff5a1f"), 36)` posicionado na boca do braseiro (emitindo para cima), e um `OmniLight3D` quente (`#FFB060`, energia 1,2, alcance 4 m, sem sombra) piscando levemente (energia ±15% com ruído no `_process` de um pequeno script ou `Tween` em loop). Esconda/remova a malha de chama triangular estática do modelo se ela for um mesh separado (senão deixe e só reduza a escala).

## Verificação
- `Godot_v4.7.2-stable_win64_console.exe --headless --path D:\DynMagic --import` sem erro de script vindo dos seus arquivos.
- Capture com janela: `Godot_v4.7.2-stable_win64_console.exe --path D:\DynMagic res://tools/gauntlet_capture.tscn -- --tag e1` e abra `build/gauntlet/e1_b_spawn.png`, `e1_a_mid.png`, `e1_a_overview.png`; descreva o céu, os biséis e o fogo.
- Sem commit. Ao terminar, troque o Status para "pronto" e liste o que mudou.

Console Godot: `C:\Users\vinic\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.

## O que mudou
1. **Céu** — novo `shaders/stylized_sky.gdshader` (`shader_type sky`): gradiente de três faixas (zênite `#4F7FC4`, meio `#9FB6E0`, horizonte `#F4CFA0`), sol com disco duro + halo largo seguindo `LIGHT0_DIRECTION` (`#FFE2B0`), nuvens fbm em camadas quantizadas em 3 degraus (lado iluminado `#FFF4E0`, sombra `#B7A6D6`) movendo com `TIME`. `scenes/arena/arena_environment.tres` trocou `ProceduralSkyMaterial` por `ShaderMaterial`; demais parâmetros do ambiente mantidos.
2. **Bisel + sujeira** — em `shaders/toon.gdshader`, só no ramo `procedural_surface`: bisel falso (~4 cm no topo/lado esquerdo do tijolo, +15%, `bevel_strength`), sujeira com manchas na base (0–0,4 m, até 25%, `grime_strength`) e desgaste de baixa frequência ±8% (`wear_strength`). API/uniforms existentes intactos; objetos texturizados inalterados.
3. **Fogo** — em `scenes/arena/arena_dressing.gd`: cada braseiro ganhou `ElementFx.trail(&"fire", Color("ff5a1f"), 36)` na boca (emitindo para cima) + `OmniLight3D` quente (`#FFB060`, energia 1,2, alcance 4 m, sem sombra) com flicker ±15% via Tween em loop; malhas estáticas `FacetedFlame` ocultas.

## Verificação
- `--import` sem erro de script vindo destes arquivos.
- `res://build/check_suites.tscn` → **106 testes, 0 falhas**.
- Captura `-- --tag e1` gerou os 9 PNGs (`build/gauntlet/e1_{a,b,c}_{spawn,mid,overview}.png`). Modelo sem entrada de imagem: conferência estrutural headless confirmou céu `ShaderMaterial`, 4 braseiros com fogo (direção +Y) + luz e 12 malhas de chama ocultas. Sem commit.

