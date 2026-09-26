# Revisão de arte técnica — v1.1.0-alpha

Data: 2026-09-26. Papel: artista técnico. Escopo pedido: `shaders/*`, `vfx/*`, `scenes/arena/arena_builder.gd`, `assets/models/*.json`, `tools/blender/*.py`, `scenes/player/first_person_arms.gd`, `scenes/player/mage_animation.gd`, `ui/*` (mais o necessário para julgar a integração: `scenes/assets/asset_visual.gd`, `scenes/ui/ui_kit.gd`, `tools/build_ui_theme.gd`, `scenes/spells/zone.gd`, `scenes/spells/explosion_fx.gd`).

**Parecer: pipeline sólido e orçado; a arte ainda está em nível de greybox-limpo, não no alvo "Sea of Thieves / Witch Hat Atelier".** Os números de geometria estão todos dentro do orçamento e a substituição de materiais por um toon único funciona. Os problemas relevantes são de **leitura visual** (identidade dos elementos, luz toon em fontes pontuais) e de **conteúdo morto** (assets/PNGs gerados que não entram no jogo). Nenhum bloqueador de release.

Pré-requisito: `AGENTS.md` manda atualizar `docs/HANDOFF.md` ao fim da sessão; a tarefa proibiu alterar qualquer arquivo além deste relatório, então o handoff **não** foi tocado.

Limitações: revisão **estática**. Não executei Godot, testes, exportação, nem renderizei capturas (isso criaria arquivos). Não revalidei o registro de 84 testes. As reproduções abaixo são procedimentos, não resultados. Onde não há certeza, está marcado.

---

## P1 — Importante

### A01 — Luz toon não atenua por distância; fontes pontuais nunca chegam a 0

- **Problema:** `light()` usa `ATTENUATION` apenas para escolher a faixa (`band`), não para escalar a energia. Como `band` tem piso `shadow_floor = 0.42`, qualquer superfície dentro do alcance da luz recebe no mínimo 42% de `LIGHT_COLOR`, independentemente da atenuação. O brilho não decai a 0: ele salta de 0.42 para 0 na borda do alcance/culling de cluster.
- **Evidência:** `shaders/toon.gdshader:39-43` (o termo `DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * band` não multiplica por `ATTENUATION`); fontes pontuais em `scenes/spells/bolt.tscn:18-20` (`OmniLight3D`, energia 1.5, alcance 3.0), `scenes/spells/orb.tscn:17`, `scenes/spells/seed.tscn:17`. O flash de cast é uma `OmniLight3D` isolada em `scenes/player/first_person_arms.gd:61-65`.
- **Impacto:** cada projétil tinge a área ao redor com um piso constante da cor do elemento, com transição visível na borda do alcance; com várias magias ativas a cor acumula. Em Forward+ o culling de cluster esconde parte do efeito, mas o piso de 0.42 permanece onde a luz é processada.
- **Correção:** multiplicar o termo difuso e o rim por `ATTENUATION` (direcional tem `ATTENUATION == 1`, então o Sol não muda): `DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * band * ATTENUATION / PI * 1.6;`. Se o piso de sombra for proposital como ambiente, ele deve vir do ambiente (Environment) e não de cada luz.
- **Esforço:** S.

### A02 — Identidade visual dos elementos não existe no VFX: as quatro magias são o mesmo cubo

- **Problema:** a spec pede linguagens distintas (fogo com faíscas quadradas, gelo com cristais facetados, raio com linhas em zigue-zague, vento com fitas/papel). Na prática todas as partículas são `BoxMesh`, diferenciadas só por tamanho, gravidade, spread, velocidade, órbita e turbulência. O critério de aceite "os 4 elementos são distinguíveis em escala de cinza (silhueta e forma das partículas)" fica atendido só por movimento/escala, não por forma.
- **Evidência:** `vfx/element_fx.gd:8-13` (só parâmetros numéricos por elemento) e `:64-65` (`BoxMesh` para todos). A tabela prometida está em `docs/specs/07-art-pipeline.md:25-32`.
- **Impacto:** em combate, Fire/Frost/Storm/Wind leem igual de longe; a "identidade vem de cor/VFX" (decisão travada no handoff §3) não se sustenta sem cor.
- **Correção:** adicionar um campo `mesh` ao dicionário `LOOKS` e montar a malha por elemento: prisma/cristal de baixo poli para gelo, quad fino longo para vento, e uma malha segmentada (ou `ImmediateMesh`/linha) para o raio. Manter `particles.draw_pass_1` como ponto único de troca.
- **Esforço:** M.

### A03 — Pacote de UI parcialmente morto: pergaminho desligado, faixa de título sem uso, fundo de 2,7 MB

- **Problema:** o `parchment_panel.png` foi gerado e documentado (spec 07 §8), mas a integração está explicitamente desligada com `if false`. O `title_banner.png` não é referenciado por nenhuma tela/tema — só pelo verificador. O `menu_backdrop.png` tem **2,7 MB** e é carregado como `TextureRect` a cada tela de menu.
- **Evidência:** `tools/build_ui_theme.gd:192` (`if false and textured and ... parchment_panel`); busca por `title_banner` retorna apenas `tools/verify_assets.gd:210` (só existência/tamanho). Tamanho real do backdrop: 2.692.971 bytes; os botões, por outro lado, são reduzidos para 256×64 em tempo de build (`build_ui_theme.gd:134-140`), o que funciona.
- **Impacto:** dois PNGs produzidos (incluindo o painel mais elaborado) não pagam seu custo; o backdrop adiciona ~2,7 MB ao import/carregamento sem compressão específica.
- **Correção:** decidir o destino — (a) usar o pergaminho como variante clara de painel nas telas de leitura (grimório/ajuda) e a faixa no `UiKit.title()`, ou (b) remover ambos da pasta e da validação. Recomprimir o backdrop (WebP/JPEG de alta qualidade, ou `Lossless`/`VRAM` no `.import`) visando < 500 KB.
- **Esforço:** S.

### A04 — Espelhamento do viewmodel depende de `replace` de string e de cast não checado

- **Problema:** o shader espelhado para canhoto é criado trocando literalmente `"render_mode diffuse_toon, specular_toon;"` no código do toon. Se essa linha mudar (ex.: entrar `cull_disabled` fixo, ou reordenação), o espelho perde o `cull_disabled` silenciosamente e o viewmodel fica com faces invertidas/pretas. Além disso, `_prepare_meshes` faz `... .duplicate() as ShaderMaterial` sem checar null: qualquer superfície cujo override não seja `ShaderMaterial` aborta na atribuição `mat.shader`.
- **Evidência:** `scenes/player/first_person_arms.gd:58-59` (construção por `replace`), `:141-143` (`as ShaderMaterial` sem guarda). Hoje funciona porque todos os wrappers usam `asset_visual.gd` → `Toon.material` (`scenes/assets/asset_visual.gd:20-30`), mas a invariável não é verificada.
- **Correção:** criar um `toon_viewmodel.gdshader` dedicado (ou um `#define`/`render_mode` controlado por uniform não é possível; um segundo arquivo é o caminho limpo) e trocar a guarda para `if material is ShaderMaterial` antes de reatribuir. Adicionar um teste em `tools/verify_assets.gd` que confirme `cull_disabled` no shader espelhado (já existe um check de `code.contains("cull_disabled")` em `verify_assets.gd:193`; falta o caso de o `replace` não casar).
- **Esforço:** S.

---

## P2 — Desejável

### A05 — `ink_dissolve.gdshader` prometido e inexistente

- **Evidência:** `docs/specs/07-art-pipeline.md:20` promete dissolve para morte e fim de muralha; `shaders/` tem só `toon`, `outline`, `rune_circle`, `ground_ring`. A morte hoje é a queda da animação (`mage_rig.py:85-88`) e a muralha some sem transição.
- **Ação:** implementar com ruído (ou remover da spec). Se implementar, um material por instância com `ShaderMaterial` + parâmetro de progresso, e a parede já usa `queue_free`.
- **Esforço:** M (implementar) / S (ajustar spec).

### A06 — Deriva de documentação: escala do viewmodel

- **Evidência:** `scenes/player/first_person_arms.gd:10` define `ARMS_SCALE = 0.56`; `docs/HANDOFF.md:249` afirma "arms scale 0.72 at REST_OFFSET". A spec 07 não fixa o valor.
- **Ação:** corrigir a linha do handoff (ou o código, se 0.72 for a intenção). Sem impacto de runtime.

### A07 — Arte gerada sem uso: estandarte, braseiro, portal, e `fp_arms` obsoleto

- **Evidência:** `banner.glb`, `brazier.glb`, `spawn_arch.glb` existem e são verificados, mas nenhum `tscn`/`.gd` de arena os instancia (busca sem resultado fora de docs/wrappers). `fp_arms` foi substituído por `fp_staff_arm` (spec 07 §8) e continua no pacote e na verificação. A spec admite "prontos para posicionamento, ainda fora das arenas" (07 §6).
- **Impacto:** ~0,9 MB de GLB + atlas e tempo de verificação sem retorno visual; o cenário greybox fica sem os elementos que davam o clima "academia arcana em ruínas" (estandartes/braseiros).
- **Ação:** posicionar os três decorativos no `ArenaBuilder` (sem colisão, conforme a regra "malha gerada nunca vira colisão") ou movê-los para backlog explícito e removê-los do verificador; remover `fp_arms` do pipeline.
- **Esforço:** S (remover) / M (posicionar bem).

### A08 — Orçamento de triângulos não é o gargalo; o alvo estilístico sim

- **Evidência:** todos os 16 assets dentro do orçamento (`assets/models/*.json`): mago **1.304**/15.000, boneco **1.992**/3.000, cajados 478–572/3.000, coberturas 319–696/3.000, portal 646/3.000. O mago tem 36 objetos de malha e formas `profile()` facetadas (`tools/blender/mage.py`), resultando em silhueta angular.
- **Ação:** não é bug. Registrar que o próximo ganho visual não vem de subir contagem, e sim de formas (chapéu/manto), textura pintada e poses. O rig de 8 ossos é suficiente para o que existe.

### A09 — Fallback de cor plana do toon está morto para assets texturizados

- **Evidência:** `tools/blender/paint.py:88` zera `mat.diffuse_color = (1,1,1,1)` ao final do bake; `scenes/assets/asset_visual.gd:26-29` chaveia o material por `str(color)+":"+texture_id`. Como todos os assets têm atlas próprio e `albedo_color` branco, a chave é sempre `white:atlas`, então cada asset colapsa em **um** material (bom para draw calls) e a alegação de compartilhamento "por cor/textura" (spec 07 §7) na prática só usa textura.
- **Ação:** documentar o comportamento real ou preservar a cor na exportação para permitir assets mistos (com e sem atlas) sem virar branco. Baixo impacto hoje.

### A10 — Contorno com espessura fixa em pixels

- **Evidência:** `shaders/outline.gdshader:11` (`thickness = 1.2`) e corte em `:35` (`step(d, 80.0)`). O corte de 80 m é folgado (arena 28×38 m), mas 1,2 px fixo afina o traço em 4K e engrossa em 720p.
- **Ação:** escalar por `VIEWPORT_SIZE.y`/altura base (ex.: `thickness * (720.0 / VIEWPORT_SIZE.y)`) para manter a espessura aparente.
- **Esforço:** S.

---

## Critérios de aceite da spec 07 §5

| Critério | Situação | Nota |
|---|---|---|
| Toon + outline em 100% das malhas visíveis | **Quase** | `asset_visual` cobre GLBs; `ArenaBuilder._box` usa `Toon.material` (`arena_builder.gd:207`); outline é pós-processo na câmera local (`player.gd:124`) e no menu (`main_menu.gd:72`). O viewmodel isolado não tem outline (por design). |
| 4 elementos distinguíveis em cinza | **Parcial** | Ver A02: mesma malha de partícula; diferenciação por movimento/escala. |
| Nenhum VFX > 2.000 partículas por magia | **Atendido por sistema** | `vfx/element_fx.gd:41` aplica `mini(amount, 2000)`. Não há teto somado quando trail + burst + zona coexistem. |
| Checklist de importação de asset de IA | **N/A** | Pipeline é procedural (Blender Python), sem IA generativa. |

---

## Pontos fortes

- Substituição de material uniforme e cacheada (`asset_visual.gd`, `Toon.material`), com o atlas entrando como `albedo_texture`; nenhum material importado vaza para a cena.
- `ground_ring.gdshader` cumpre bem a tarefa 5 do M11: Área = varredura sólida de uma vez (`mode 0`, `explosion_fx.gd:43-46`), Contínuo = borda pontilhada + arco de tempo (`mode 1`, `zone.gd:42-43`), ambos `unshaded`. Posicionamento evita z-fighting (`explosion_fx.gd:39`, `zone.gd:16`).
- `mage_animation.gd` mascara o estado remoto com `& 3` (`:73`) e `SpellComposer.State` tem exatamente 4 valores (`spell_composer.gd:8`) — correto, sem colisão de bits.
- Viewmodel com `World3D`/câmera própria em camada 20, FOV separado e lateralidade ao vivo: arquitetura correta para evitar clipping de parede.
- Pipeline Blender reproduzível e auditável: JSON de geometria por asset, `expected_size` assertado na exportação (`common.py:163-165`) e preview opcional.

## Resumo executivo

| ID | Prio | Item | Esforço |
|---|---|---|---|
| A01 | P1 | Luz toon sem atenuação (fontes pontuais) | S |
| A02 | P1 | Elementos sem identidade de forma no VFX | M |
| A03 | P1 | UI: pergaminho desligado, banner sem uso, fundo 2,7 MB | S |
| A04 | P1 | Espelho do viewmodel frágil (`replace` + cast) | S |
| A05 | P2 | `ink_dissolve` prometido e ausente | M/S |
| A06 | P2 | Escala do viewmodel 0,56 vs 0,72 no handoff | S |
| A07 | P2 | Estandarte/braseiro/portal e `fp_arms` sem uso | S/M |
| A08 | P2 | Baixo poli é escolha, não orçamento | — |
| A09 | P2 | Fallback de cor plana inativo em assets texturizados | S |
| A10 | P2 | Contorno em pixels fixos | S |

Ordem sugerida: A01 e A04 (baratos e de risco), depois A03, depois A02 (o que mais muda a leitura em partida).
