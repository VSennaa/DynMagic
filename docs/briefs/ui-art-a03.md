# Brief — arte de UI sem uso (A03) e docs (A06) (DeepSeek)

Status: pronto (2026-09-26).

Revisão de arte técnica (`docs/reviews/r2-deepseek-art.md`, A03/A06):
- `tools/build_ui_theme.gd:192` tem o painel de pergaminho desligado (`if false and textured ...`). Motivo histórico: texto creme ilegível sobre pergaminho claro.
- `assets/ui/title_banner.png` existe e não é usado em nenhuma tela.
- `assets/ui/menu_backdrop.png` pesa ~2,7 MB.
- `docs/HANDOFF.md` diz escala do viewmodel 0,72, mas `scenes/player/first_person_arms.gd` usa `ARMS_SCALE = 0.56`.

## O que fazer (edite só estes arquivos)
`tools/build_ui_theme.gd`, `ui/dynmagic_theme.tres` (gerado), `scenes/ui/ui_kit.gd`, `scenes/ui/main_menu.gd`, `assets/ui/menu_backdrop.png` (+ `.import` se mudar), `docs/HANDOFF.md` (só a linha da escala do viewmodel), `docs/specs/07-art-pipeline.md`.

1. **Pergaminho legível:** reative o painel de pergaminho **só** para uma nova variação de tema `ParchmentPanel` (PanelContainer) com texto escuro `#2A2233` (crie também a variação `ParchmentLabel`). Os painéis padrão continuam escuros. Use o pergaminho no card de "Como jogar"/glossário se existir (`scenes/ui/glossary.gd`) **sem** mudar a lógica — só `theme_type_variation`; se não houver lugar natural, deixe as variações prontas e documente.
2. **Faixa de título:** em `UiKit.title()`, quando `size >= 56`, desenhe `assets/ui/title_banner.png` atrás do título (TextureRect com 9-slice via `NinePatchRect`, margens da spec 07 §8), centralizado; tamanhos menores ficam como estão. Confira no menu principal que o título continua legível.
3. **Fundo mais leve:** reduza `menu_backdrop.png` para ≤ 900 KB sem perda visível (por exemplo, salvar via Godot `Image.save_webp` com qualidade 0.9 como `menu_backdrop.webp` e trocar a constante `PAINTING` em `ui_kit.gd`; mantenha o PNG antigo apagado só se nada mais o referenciar — procure com grep).
4. **Docs:** corrija a escala do viewmodel no HANDOFF para 0,56; registre as variações novas e o arquivo do fundo na spec 07 §8.
5. Rode `Godot_v4.7.2-stable_win64_console.exe --headless --path D:\DynMagic --script res://tools/build_ui_theme.gd` para regenerar o tema.

## Verificação
- `--headless --path D:\DynMagic --import` sem erro de script dos seus arquivos; `res://build/check_suites.tscn` com 0 falhas.
- Sem commit. Troque Status para "pronto" e liste o que mudou.

Console Godot: `C:\Users\vinic\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`. Outro agente edita arenas, rede e partida agora: não toque em nada fora da lista.
