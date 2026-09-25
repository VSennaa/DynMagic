# Spec 07 — Arte e pipeline

## 1. Direção

| Referência | O que tirar | O que não tirar |
|---|---|---|
| Bleach | Contraste forte, rastros de energia, silhuetas afiadas, flashes brancos no impacto, capa/manto em movimento | Traço de mangá, hachura |
| Witch Hat Atelier | Magia como desenho: círculos rúnicos, glifos, tinta, pena, sensação de ofício | Traço fino de ilustração |
| Sea of Thieves | Proporções cartoon, cores saturadas, água/céu estilizados, materiais pintados | Realismo de iluminação |

Resumo: **"grimório vivo"**. Magia é tinta que ganha forma. Arenas parecem pátios de uma academia arcana em ruínas, com pedra clara, madeira escura e estandartes.

## 2. Fase 1 — Shader-first (M1 a M6)

Tudo dentro do Godot, sem ferramenta externa.

- `toon.gdshader`: rampa de luz em 3 faixas, rim light, especular em bloco, cor base + textura de ruído para aspecto pintado.
- `outline.gdshader`: casca invertida (inverted hull) nos personagens; contorno por pós-processo (profundidade + normal) na arena.
- `rune_circle.gdshader`: círculo procedural com glifo (textura), anel externo animado (liso/dentado/pontilhado), cor por uniform.
- `ink_dissolve.gdshader`: dissolve com ruído para morte e fim de muralha.
- Céu: `ProceduralSkyMaterial` saturado + nuvens planas.
- Personagem placeholder: cápsula + chapéu cônico + manto (primitivas CSG), com cor do elemento.
- Braços em 1ª pessoa placeholder: mãos de luva simples com 4 poses.

### VFX por elemento (GPUParticles3D)

| Elemento | Linguagem |
|---|---|
| Fogo | Pinceladas laranja em espiral, faíscas quadradas, fumaça escura com contorno |
| Gelo | Cristais facetados, pó branco, anéis de geada no chão |
| Raio | Linhas quebradas em zigue-zague (mesh gerada), flash branco, estalo |
| Vento | Fitas curvas translúcidas, folhas de papel com glifos |

## 3. Fase 2 — Pipeline de assets (M7)

Autorizado pelo usuário em **2026-09-25**: Blender **5.2.1 LTS**, somente headless, modelagem procedural com Python. Sem downloads, Tripo/Meshy, serviços pagos ou mcp-blender nesta rodada. Substitui o plano anterior de geração por API.

Fluxo:

```
tools/blender/<asset>.py + common.py
  → modelagem em metros, bevels, cores planas, runas escavadas
  → aplicar transforms → export GLB Y-up + relatório JSON de geometria
  → assets/models/<asset>.glb
  → scenes/assets/<asset>.tscn → Toon.material(cor) em todas as superfícies
```

Orçamento: personagem ≤ 15.000 triângulos; cada prop ≤ 3.000. Rig é opcional na rodada 3; animações e conexão dos braços ao controlador ficam para uma etapa posterior.

Regras de importação:

- Escala 1 unidade = 1 m. Eixo Y para cima.
- Colisão continua sendo primitiva (spec 03). Malha gerada nunca vira colisão.
- Todo material importado é trocado pelo toon + outline. Isso garante o mesmo estilo entre assets de fontes diferentes.

## 4. Áudio

- v1: pacotes CC0 (Kenney, Sonniss GDC) + síntese simples.
- Magia em 3 camadas (spec 01 §5).
- Música: tema de menu, loop de combate com camada extra no overtime.

## 5. Critérios de aceite

- [ ] Toon + outline aplicados em 100% das malhas visíveis.
- [ ] Os 4 elementos são distinguíveis em escala de cinza (teste de silhueta e forma das partículas).
- [ ] Nenhum VFX passa de 2.000 partículas vivas por magia.
- [ ] Asset gerado por IA passa o checklist de importação antes de entrar no repositório.

## 6. Assets gerados

Rodada 3, 2026-09-25. Fontes: `tools/blender/`; binários e relatórios: `assets/models/`; wrappers: `scenes/assets/`. Cores planas sem texturas externas. Contagens da malha base (LOD 0), verificadas também depois da importação Godot.

| Asset | Triângulos | Descrição / dimensões X × Y × Z em metros |
|---|---:|---|
| `mage.glb` | 1.304 | Mago estático de 1,80 m; origem nos pés, frente −Z; chapéu pontudo largo, manto, luvas, botas e runas. Sem rig/animações. |
| `fp_arms.glb` | 2.368 | Total das quatro poses com ambos os braços: `OpenPalm`, `Fist`, `PalmDown`, `Cast`; origem comum para câmera, frente −Z. Wrapper mostra apenas uma pose por vez. |
| `cover_low.glb` | 319 | Pedra chanfrada com runas escavadas; 1,5 × 1,0 × 1,5. |
| `cover_high.glb` | 326 | Pedra chanfrada com runas escavadas; 1,5 × 2,2 × 1,5. |
| `cover_bar.glb` | 696 | Barra de pedra com três runas em cada face frontal/traseira; 4,5 × 1,4 × 1,2. |
| `pillar.glb` | 326 | Pilar chanfrado com runas escavadas; 3 × 3 × 3. |
| `banner.glb` | 288 | Tecido vinho com espessura, bordas douradas e sigilo; 2,7 m de altura. |
| `brazier.glb` | 280 | Base de pedra, cuba dourada e chama facetada estática; 1,62 m de altura. |
| `spawn_arch.glb` | 646 | Portal de pedra, pilares com runas escavadas, lintel e sigilo; 8,5 × 5 × 1,159. |
| `arcane_core.glb` | 204 | Cristal facetado suspenso sobre pedestal rúnico; 1,88 m de altura. Só o cristal gira/flutua em runtime. |

Integração: `Player._add_nameplate()` usa o mago apenas no jogador remoto; `ArcaneCore.create()` instancia cristal/pedestal; `ArenaBuilder` troca somente visuais de coberturas com tamanho exato. As caixas CSG mantêm `use_collision = true` e `visible = true`, mas usam `layers = 0`; o wrapper visual é um irmão com a mesma rotação e origem no chão. Nichos e peças de medidas especiais continuam no greybox. Nenhum GLB contém colisão.

`asset_visual.gd` substitui cada superfície importada por `Toon.material(color)`, preservando a paleta e compartilhando materiais por cor. Outline usa o pós-processo existente das câmeras. Os braços estão disponíveis como asset/wrapper com seleção `pose`; não foram conectados ao jogador nem animados, conforme o escopo de integração restrito da rodada. Estandarte, braseiro e portal estão prontos para posicionamento, ainda fora das arenas.

Reprodução na raiz do projeto:

```powershell
$env:BLENDER_USER_CONFIG = 'D:/DynMagic/.blender_tmp/config'
$env:BLENDER_USER_SCRIPTS = 'D:/DynMagic/.blender_tmp/scripts'
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 -P tools/blender/mage.py -- --preview
# Troque mage pelo nome de qualquer asset. --preview salva em build/assets/ e é opcional.
$g = 'C:/Users/vinic/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
& $g --headless --path D:/DynMagic --import
& $g --headless --path D:/DynMagic res://tools/verify_assets.tscn
& $g --path D:/DynMagic res://tools/assets_gallery.tscn -- --capture D:/DynMagic/build/assets/godot-gallery.png
```

Validação: `verify_assets` compara triângulos/dimensões importados com os relatórios, toon de todas as superfícies, origem no solo, seleção exclusiva das poses, ausência de colisões importadas, modelo remoto e pedestal estacionário. Raycasts físicos verificam o topo de cada cobertura e bloqueio entre spawns nas três arenas. Galeria inspecionada com toon e outline reais. Todos os geradores foram executados novamente com relatórios geométricos idênticos; alguns GLBs diferiram binariamente entre execuções, sem alteração das contagens/dimensões verificadas.

Pendentes: revisão artística do usuário, rig/animações, braços no controlador/camada sem clipping e posicionamento dos props decorativos.
