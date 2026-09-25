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

Ferramentas (instalar só no M7):

- **Blender 4.x** + **[mcp-blender](https://github.com/RFingAdam/mcp-blender)**: modelagem, limpeza, rig e export controlados pelo Claude.
- **Tripo** (API paga): geração estilizada de personagem e props. Melhor opção para visual hand-painted.
- **Meshy** (opcional): props genéricos com PBR bom.
- **Poly Haven**: texturas base (CC0).

Fluxo:

```
Prompt/concept ─► Tripo (image/text-to-3D) ─► Blender via MCP:
   decimar (personagem ≤ 15k tris, prop ≤ 3k), retopo leve, UV,
   rig Mixamo-compatível, pintar sobre textura
─► export .glb ─► Godot import (material trocado pelo toon.gdshader)
```

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
