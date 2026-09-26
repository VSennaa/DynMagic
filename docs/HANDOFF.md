# DynMagic — Handoff Notes for AI Agents

Last update: 2026-09-25. Written so any AI agent (Claude, Codex, Gemini, etc.) can continue work without the original conversation.

## 0. Active agent

Active agent: none (round 8 DeepSeek PARTIAL — only task 1 of 7 done, changes uncommitted). Task 1 (hit/damage feedback) implemented and tested (`--import` clean, 77 tests 0 failures, headless LAN pair ran clean). Tasks 2–7 NOT started: Arrow 0.3 s pacing + charge pips, melee on V, pre-cast on G, area/lingering readability, compact snapshot, version 1.1.0 + release notes. ARROW PACING BUG STILL PRESENT. Pending from earlier rounds: VPS 1 h load test, `status.json` queue and `web/` site (no VPS/network access); true third-person death cam.

### Handoff brief for DeepSeek (round 8 — alpha 1.1, ROADMAP M11; 2026-09-25)
Active agent while running: DeepSeek (openclaude). Claude reviews, commits, tags `v1.1.0-alpha` and then sets up the web route on the VPS.
Rules: same as round 7 (no git commit/push, no `.git`/`addons/`/`.github/`, no downloads/installs, static typing, UI text in Portuguese). Godot console: `C:\Users\vinic\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`. After EACH task: `--import`, `res://build/check_suites.tscn` (must stay 0 failures), and for gameplay tasks the headless LAN pair `-- --host --bot --match-speed 10` + `-- --join 127.0.0.1 --bot --match-speed 10`. Tick the item in ROADMAP M11 and add a line here.
Tasks, in order (user decisions are binding):
1. **Hit / damage feedback** (`scenes/ui/hud.gd`, `autoload/audio_bus.gd`): stronger hit sound, bigger damage number, red screen-edge flash + short camera shake (new Settings toggle `screen_shake`, default on) when taking damage, distinct kill marker when a hit kills.
2. **Arrow pacing** (`scenes/player/player.gd`, `scenes/net/net_match.gd`): keep 3 charges / 1.2 s but add a minimum 0.3 s between Arrow shots (local and host); show the Arrow charges (3 pips) in its HUD cooldown grid cell.
3. **Melee on V** (new input action `melee`, key V, remappable in settings): staff swing, 1.8 m range, 70° cone, 12 damage, 0.8 s cooldown, no mana, host-authoritative like casts (request -> validate -> apply), first-person arm thrust + sound.
4. **Pre-cast on G** (new action `precast`, key G): once a spell is fully composed (quick spell right after the effect key, or while AIMING), G stores it instead of casting; its mana cost is reserved (not spendable, drawn as a striped segment on the mana bar); G again fires it (confirm spells enter aiming); F cancels and releases the mana. One stored spell at a time. Host validates the reservation like a cast. Add tests for the reservation math.
5. **Area vs Lingering readability**: area spells get a sharp one-shot ground ring flash; lingering effects keep a pulsing dotted ring plus a visible remaining-time ring. Keep VFX unshaded.
6. **Snapshot size**: replace the `put_var` gameplay blob in `autoload/net_codec.gd` with compact fields (status ids + remaining as half floats, non-zero cooldowns only, arrow charges, overcharge, is_dead bit). Target < 600 B for 2 players; keep `tests/test_net_serialization.gd` passing and extend it.
7. Version `1.1.0` (project.godot, export_presets `1.1.0.0`) and a `v1.1.0-alpha` section at the top of `docs/release-notes.md` (Portuguese, player-facing).
Leave for Claude: sound/music quality, animation and projectile art, spell identity pass, release tag, VPS web route.
Set `Active agent: none (round 8 DeepSeek ...)` when you stop, listing what is undone.

### Round 8 status (2026-09-26 ~01:30, Claude) — DONE, released as v1.1.0-alpha
Active agent: none. Claude finished round 8 after DeepSeek did task 1 (and task 2 in part): task 2 verified; task 3 melee on V (`Player.try_melee/perform_melee`, `NetMatch.request_melee` host-authoritative, arm swing, `build/check_melee.tscn` 0 failures); task 4 pre-cast on G (`SpellComposer.stored/press_precast`, `Stats.can_afford(cost, reserved)`, host mirror `request_store`, striped mana segment); task 5 ground rings (`shaders/ground_ring.gdshader`: area = one-shot solid ring, lingering = dotted pulsing edge + time-left arc; render check `build/check_rings.tscn`); task 6 compact snapshot codec (`NetCodec.GAMEPLAY_FIELDS` must match `ReconnectState.PLAYER_FIELDS`, 2 players < 600 B, no MTU warning); task 7 version 1.1.0 + release notes. Also fixed: saved settings without the new actions no longer error on load; `export_presets.cfg` preset renamed by the editor back to "Windows Desktop" (the release workflow depends on that name). 84 tests, 0 failures; LAN headless and exported exe smoke-tested. Seen once: a 2.02 m reconciliation spike mid-combat that did not reproduce in two more runs — watch it.
Lesson: stopping a background PowerShell task does not kill `openclaude`/`opencode` children; kill the node process too (see memory).
Next (M11 leftovers, Claude): sound/music quality, animation and projectile art, spell identity pass; then post-alpha site/DNS and the dedicated-server full-match telemetry check.

### Round 8 result — DeepSeek (2026-09-25, STOPPED EARLY, 1/7 tasks)

Stopped on budget before task 2. Only **task 1 (hit/damage feedback)** is implemented; tasks 2–7 are untouched. No commit, no `.git`/`addons/`/`.github/` changes, no downloads.

- **Task 1 DONE — Hit / damage feedback.** `autoload/audio_bus.gd`: new sample groups `hit_strong`, `kill`, `hurt` (CC0 impacts). `autoload/settings.gd`: new `screen_shake` bool (default on) persisted under `[game]`. `scenes/ui/settings_screen.gd`: "Tremor de câmera ao levar dano" checkbox. `scenes/player/player.gd`: `SHAKE_TIME`/`SHAKE_AMPLITUDE`, `add_camera_shake(strength)`, `_update_shake(delta)` offsetting `_camera.position` (local player only, gated by the setting, reset each round). `scenes/ui/hud.gd`: full-screen red edge-flash `ColorRect` + inline `canvas_item` shader driven by a `strength` uniform, larger/red damage number on a killing hit, distinct `ABATE` kill marker, `hit_strong`/`kill` sounds on our hits, and on taking damage a flash + `add_camera_shake` + `hurt` sound in `_update_damage_arrow`.
- **Verification (task 1):** `--import` clean; `res://build/check_suites.tscn` → **77 tests, 0 failures**; headless LAN pair `-- --host --bot --match-speed 10` + `-- --join 127.0.0.1 --bot --match-speed 10` ran rounds with players synced and no script errors. Known headless warnings unchanged: snapshot MTU (1876 B > 1392; this is task 6) and the first-person arms material under the headless renderer (pre-existing).
- **NOT DONE (tasks 2–7):** 2 Arrow 0.3 s minimum between shots + 3 charge pips in the HUD grid cell; 3 melee on V (action `melee`, host-authoritative, 1.8 m / 70° / 12 dmg / 0.8 s CD, arm thrust + sound); 4 pre-cast on G (action `precast`, reserve mana with a striped bar segment, fire/cancel, host validation, tests); 5 area vs lingering readability (one-shot ground ring vs pulsing dotted + remaining-time ring, unshaded); 6 compact snapshot (replace `put_var` gameplay blob, < 600 B, extend `tests/test_net_serialization.gd`); 7 version `1.1.0` + `v1.1.0-alpha` release notes. ROADMAP M11 line for task 1 ticked; lines for tasks 2–7 left unticked.

### Round 7 result — DeepSeek fallback (2026-09-25)

Resumed the Codex round 7 brief from phase 1. Codex had already landed C1/C6/C7/C8/C9/C11/C12/C16/C17 (commit `42f141b`) plus uncommitted HUD work; each M10 item was audited against the code, the done ones ticked in `docs/ROADMAP.md`, and the rest implemented in phase order (1→4). No commit, no `.git`/`addons/`/`.github/` changes, no downloads.

- **Phase 1 (integrity):** closed the gaps Codex left — `scenes/spells/spell_node.gd` captures the damage multiplier at spawn (3rd Overcharge cast keeps +20%; zones no longer gain/lose it when the Core changes hands) and `scenes/net/net_match.gd` validates target range and compose time (C10).
- **Phase 2 (readability):** new `scenes/ui/glossary.gd` (D10 names for elements, forms, effects, statuses, runes, overtime, arenas, reasons) applied across HUD/results/draft/scoreboard; new `scenes/ui/how_to_play.gd`+`.tscn` and menu entry (C14); `scenes/ui/hud.gd` hitmarker + damage numbers + round/death banner + damage card (C2/C3); `autoload/match_state.gd` 100 ms `damage_dealt` aggregation; `scenes/net/net_match.gd` draft panel refreshed in place (C5) and Tab 3×3 spell card; `scenes/ui/crosshair_wheel.gd` Q-E-R arc with quick/confirm marks (D6); training hint line.
- **Phase 3 (server):** `autoload/net.gd` accepts `host:port`, stores host address + disconnect reason, parses `--overtime`/`--arena`; lobby shows the host IP and the local-telemetry notice; dedicated server skips HUD/model/audio and pins 60 Hz physics (C15); server systemd template `server/dynmagic@.service` + `server/dynmagic@.env.example` + README section for three rooms with `MemoryMax`/`CPUQuota` (D13). Queue/`status.json` and the website remain undone (no VPS access).
- **Phase 4 (balance):** Arrow = 3 charges recharging 1/1.2 s and RMB recasts only confirmed spells (D1, mirrored in host validation and replicated through `ReconnectState`); element multipliers set to 1.05/0.95/1.0/0.95 (D2); host writes a local telemetry JSON per match under `user://telemetry` (D12); headshot removed from spec 05 (D9); SDD/specs 02/06/release notes aligned (C18). Version bumped to `1.0.0` (`project.godot`, `export_presets.cfg` 1.0.0.0) with the `v1.0.0-alpha` section in `docs/release-notes.md`.

**Verification:** `--import` clean after each phase; **77 tests, 0 failures** (`build/r7-tests-final.log`, updated tests for D1/D2/D3 plus a new `tests/test_telemetry.gd` for D12); LAN headless host+bot / join+bot finished rounds by kill and hp with 0 script errors (`build/r7-host2.log`, `build/r7-client2.log`); dedicated server + two `--lobby --bot` clients ran both remotes with no HUD/model/audio and no presentation errors (`build/r7-ded2*.log`). Known headless warnings unchanged: snapshot MTU (gameplay blob ~1.8 KB > 1392; LAN works, worth compacting) and the first-person arms material under the headless renderer.

### Handoff brief for Codex (round 7 — alpha 1.0, ROADMAP M10; 2026-09-25)
User asked: skip further review, Codex implements M10, Claude commits afterwards. Read `docs/reviews/SYNTHESIS.md` (consensus C1–C18, decisions D1–D13, user decisions in §5) and the four reports in `docs/reviews/` for evidence (file:line). Work through ROADMAP M10 phases 1 → 4 in order, ticking `[x]` as you go.
- You may edit anything in the project except `.git`, `addons/`, `.github/`. Keep GDScript static typing (untyped_declaration is an error), match surrounding style, UI text in Portuguese, identifiers in English.
- User decisions (binding): Seta 3 charges (1 per 1.2 s) + RMB recast only for confirmed spells; element multipliers Fogo 1.05 / Gelo 0.95 / Raio 1.0 / Vento 0.95; overtime default Colapso, Aleatório as lobby option + `--overtime`/`--arena` server flags; VPS gets 2 GB and runs 3 processes via a `server/dynmagic@.service` template with MemoryMax (write the template + README section; do not ssh anywhere).
- Other conflicts: follow the "Recomendação" column of SYNTHESIS §2 (glossary Raio/Leque/Prorrogação/Escolha/Round, wheel as Q-E-R arc with quick/confirm mark, both HP bars on top + enemy status icons only with line of sight, death cam + damage card without replay, remove headshot from spec, local telemetry JSON with lobby notice, draft fixed windows with confirmation, 15 s in round 1).
- Test after each phase: `--import`, the godot-ai test suites in `tests/` (update/add tests for changed rules), and a headless LAN match: host `-- --host --bot` + client `-- --join 127.0.0.1 --bot` (both `--headless`). A dedicated check: `-- --server` + two `--join 127.0.0.1 --lobby --bot` clients (they auto-ready).
- Bump version to `1.0.0` (project.godot `config/version`, export_presets file/product version `1.0.0.0`) and write the `v1.0.0-alpha` section at the top of `docs/release-notes.md` (Portuguese, player-facing).
- Do not download export templates, install software or touch the network. You cannot commit: leave changes uncommitted, list them here, and set `Active agent: none (round 7 ...)` when you stop, noting anything left undone.


Rodada 3 concluída em 2026-09-25, sem commit; arquivos, triângulos e pendências na seção 12. Round 2 (video settings, compose metrics, reconnect) was reviewed, tested (73/73 + bot match) and committed by Claude.

### Handoff brief for Codex (round 6 — elemental staffs, one-handed viewmodel, UI art; 2026-09-25)
**Rodada 6 concluida em 2026-09-25, sem commit.** Tarefas executadas na ordem solicitada; arquivos de UI/menus/settings do agente paralelo preservados.

- **Cajados:** `staff_fire` **488**, `staff_frost` **478**, `staff_storm` **516**, `staff_wind` **572** triangulos. Todos 1,60 m, origem na empunhadura, atlas painted procedural Cycles EMIT 512x512. Geradores `tools/blender/staffs.py` + `staff_<element>.py`; GLBs/JSON/imports em `assets/models/`, atlas em `assets/textures/`, wrappers em `scenes/assets/`.
- **Viewmodel:** `fp_staff_arm` **300 tris**, apenas antebraco direito e mao de luva fechada. `first_person_arms.gd` conserva viewport/mundo isolados e FOV; anima idle/compose/aim/cast em runtime, flash 0,12 s, troca por `composer.element_id`, oculta na morte. `Settings.changed` aplica lateralidade ao vivo com escala X negativa; culling desativado apenas na variante local do toon, normais transformadas pelo Godot. Manga estendida para esconder o corte traseiro na mira. Assets antigos preservados, sem uso no viewmodel atual.
- **Terceira pessoa:** `mage_rig.py` adiciona `hand_R` (8 ossos, mago permanece 1.304 tris); `mage_animation.gd` usa BoneAttachment3D e troca o elemento. Walk reduz o balanco armado; cast ajusta braco/punho para apontar o cajado a frente. GLB/texturas do mago regenerados. `player.gd` nao precisou de alteracao.
- **UI art:** 11 PNGs RGBA em `assets/ui/`, gerados por `tools/blender/ui_art.py`: pergaminho 512x512 com margem 32 px, quatro botoes 512x128, quatro cantos runicos 128x128, faixa de titulo 1024x256 e patio ao entardecer 1920x1080. Materiais procedurais rasterizados offline pelo Blender/Cycles. Arquivos e todas as margens 9-slice documentados na spec 07, secao 8. Integracao nas telas/tema fica com o agente de UI.
- **Verificacao:** import final sem erros de scripts/assets; `tools/verify_assets.tscn`: **0 falhas**, incluindo geometria/UV/texturas, altura/origem de pega, mao unica, trocas local/remota dos quatro elementos, osso/socket, direcao frontal no cast, lateralidade ao vivo, FOV, morte/respawn, 11 PNGs e colisoes A/B/C. `git diff --check` passou. Galerias de cajados/mago, viewmodel direito/esquerdo/mira e PNGs de UI inspecionados; Godot Vulkan Forward+ na RX 580. Logs/capturas: `tools/blender/validation/r6-*` (ignorados). Runner geral nao repetido nesta rodada.
- **Limites/ambiente:** persistem avisos de certificados, gravacao de editor settings/cache em AppData e 2 objetos retidos no verificador. Nenhum commit/download/alteracao de rede ou gameplay. Revisao artistica humana e benchmark continuam pendentes. Proximo passo: agente de UI consumir o pack pelas margens da spec 07; revisao/commit por agente autorizado. `tools/build_ui_theme.gd.uid` apareceu durante import do script paralelo; nao editado/removido por Codex.

User feedback: the two-handed first-person arms look strange. Replace them with ONE right hand holding a staff (no left hand), staff style per element, with a left-handed option. Claude edits UI/menus/theme (`scenes/ui/*`, `autoload/settings.gd`, `autoload/scene_router.gd`, `ui/*`) in parallel — do not touch those.
You may edit: `tools/blender/*`, `assets/*`, `scenes/assets/*`, `scenes/player/first_person_arms.gd`, `scenes/player/mage_animation.gd`, `scenes/player/player.gd` (remote body/staff only), `tools/verify_assets.gd`, `tools/assets_gallery.gd`, `docs/specs/07-art-pipeline.md`.
1. Staffs (Blender, baked hand-painted textures like round 5, ≤ 3k tris each, ~1.6 m, grip origin): `staff_fire` (charred wood, ember crystal, flame-shaped head), `staff_frost` (pale wood, ice-shard crown), `staff_storm` (dark metal, forked prongs with a violet orb), `staff_wind` (light twisted wood, feathers/ribbons, green gem). Colours follow the element palette (fire #FF5A1F, frost #6FD3FF, storm #C98BFF, wind #7CF2B0).
2. First-person viewmodel: right forearm + gloved hand gripping the staff (new `fp_staff_arm` asset with poses/animations: idle sway, compose (staff raised), aim (staff forward), cast (thrust/flash)). No left hand. Pick the staff from `player.composer.element_id` and swap it when the element changes. Keep the separate viewport/FOV (`Settings.viewmodel_fov`). **Left-handed**: when `Settings.left_handed` is true, mirror the viewmodel to the left side (mirror the node, fix face culling/normals), updating live on `Settings.changed`.
3. Third-person mage: attach the element staff to the right hand bone; animations should read naturally with it (cast pose points the staff).
4. UI art pack in `assets/ui/` (PNG, baked from Blender procedural materials): parchment panel 9-slice (with 32 px margins), button frames normal/hover/pressed/disabled (ink-and-gold, rune notches), 4 rune corner ornaments, a title banner, and a painted 1920×1080 menu backdrop (arcane courtyard at dusk, toon style). List each file and its 9-slice margins in `docs/specs/07-art-pipeline.md`.
Verify with `--import`, `tools/verify_assets.tscn`. You cannot commit. Update this file (round 6 status) and set `Active agent: none` when done.
### Handoff brief for Codex (round 5 — textures, rig, animations; ROADMAP M8, 2026-09-25)
**Rodada 5 concluída em 2026-09-25, sem commit.** Tarefas executadas na ordem: texturas, rig/animações, braços locais. Somente os caminhos autorizados foram editados; alterações paralelas de Claude preservadas.

- **Texturas:** 11 atlas PNG sRGB de 512 × 512 em `assets/textures/`, UVs e bake procedural Cycles EMIT por `tools/blender/paint.py` integrado a `common.py`. Pinceladas anisotrópicas, gradientes e realce de cantos; pedra, madeira, tecido, palha, dourado e cristal. Todos os 11 GLBs regenerados; contagens/dimensões anteriores preservadas. Godot extrai cópias dos atlas em `assets/models/`; manter essas cópias/imports na revisão. Toon aceita textura opcional com branco por padrão; wrapper conserva albedo e compartilha materiais por cor/textura.
- **Mago:** 1.304 triângulos (limite 15.000), 1,80 m; `mage_rig.py`, rig de 7 ossos, pesos graduais no manto e clips idle/walk/cast/dash/death no GLB. Novo `scenes/player/mage_animation.gd`, ligado apenas ao corpo remoto em `player.gd`; lê composer sincronizado sem modificar NetSync, trata deslocamento interpolado, teleporte, morte e novo round.
- **Braços:** novo `scenes/player/first_person_arms.gd`, conectado à câmera local em `player.gd`. Viewport transparente com mundo próprio/camada 20, FOV sincronizado, abaixo do HUD; poses por forma/mira, flash de cast 0,12 s e ocultação na morte. Captura com parede a 0,25 m confirma ausência de clipping pelo mundo.
- **Validação:** import sem erros de scripts/assets; `tools/verify_assets.tscn`: **0 falhas**, incluindo UV/textura, rig/clips, deformação, controle remoto, braços e colisões A/B/C. Runner existente: **73 testes, 0 falhas**. Galeria, cinco poses do mago e braços renderizados/inspecionados em Vulkan Forward+ na RX 580. Logs e PNGs em `tools/blender/validation/` (ignorados pelo `.gitignore` local; `.gdignore` evita importá-los). Spec 07 §7 e somente os três itens Codex de M8 atualizados.
- **Arquivos de código:** `tools/blender/common.py`, `mage.py`, novos `paint.py`, `mage_rig.py`, `.gitignore`; `scenes/assets/asset_visual.gd`; `shaders/toon.gdshader`; `vfx/toon.gd`; dois scripts novos de animação acima e seus UIDs; apenas os dois pontos de integração visual em `scenes/player/player.gd`; `tools/verify_assets.gd`, `tools/assets_gallery.gd` (opções `--animations`/`--first-person`). Mais assets e documentos autorizados.
- **Limites:** continuam erros ambientais de certificados, cache/editor settings em AppData; verificador aponta 2 objetos retidos ao sair e runner geral os 7 objetos/3 recursos já conhecidos. Revisão artística humana, benchmark da viewport adicional na GPU-alvo e partida LAN visual completa não realizados nesta rodada. Nenhum commit, download ou mudança nos arquivos de rede/servidor/áudio. Próximo passo: revisão/integração por Claude; rodada 5 está **done**.

Claude edits networking/server/audio files in parallel (`autoload/net.gd`, `autoload/lobby.gd`, `autoload/match_state.gd`, `autoload/audio_bus.gd`, `scenes/net/*`, `scenes/ui/lobby_screen.gd`, `export_presets.cfg`, `.github/*`, `audio/*`). Do not touch those.
You may edit: `tools/blender/*`, `assets/*`, `scenes/assets/*`, `shaders/toon.gdshader` (add an optional albedo texture uniform, keep defaults working), `vfx/toon.gd`, `scenes/player/player.gd` (only the remote-body/animation and first-person-arms parts), new files under `scenes/player/` for animation, `tools/verify_assets.gd`, `tools/assets_gallery.gd`, `docs/specs/07-art-pipeline.md`, `docs/ROADMAP.md` (M8 Codex items only).
Tasks, in order:
1. Textures: extend the generators with UV unwraps and procedural hand-painted materials (brush-stroke noise, edge highlights, soft gradients) baked to PNG albedo maps (≤ 1024², in `assets/textures/`). Stone, wood, cloth, straw, gold trim, crystal. Toon shading must still read the flat look; add `albedo_texture` support to the toon shader/material helper.
2. Mage rig + animations (idle, walk, cast, dash, death) exported in the glb; a small controller script plays them on the remote mage from velocity, composer state (synced as `remote_composer_bits` in NetSync — read only) and `Stats.died`.
3. First-person arms on the local player's camera: separate render layer / camera-attached so they never clip walls; poses follow `SpellComposer` (idle, form chosen, aiming, cast flash).
Verify with `--import`, `tools/verify_assets.tscn`, and the Godot tests if possible. Keep ≤ 15k tris for the mage. You cannot commit. Update this file with results and set round 5 to done.
### Handoff brief for Codex (round 4 — training dummy model, 2026-09-25)
**Concluído em 2026-09-25, sem commit.** Modelo com **1.992 triângulos** (limite 3.000), dimensões **1,229 × 1,80 × 0,80 m**, origem no centro da base e frente −Z. Poste/braços de madeira, base redonda de pedra, saco com palha, amarras/costuras, alvo rúnico plano no peito e pequeno chapéu pontudo; GLB Y-up e cores planas.

- **Arquivos entregues:** `tools/blender/training_dummy.py`, `assets/models/training_dummy.glb`, `assets/models/training_dummy.json`, `scenes/assets/training_dummy.tscn`; somente listas de assets em `tools/verify_assets.gd` e `tools/assets_gallery.gd`, linha na tabela “Assets gerados” da spec 07 e este status no handoff. Helpers, gameplay e UI preservados.
- **Validação:** gerador Blender headless com config/scripts em `.blender_tmp/`; import Godot concluído sem erros de importação/scripts; `ASSET_OK training_dummy 1992 tris bounds=(1.229, 1.8, 0.8)` e `ASSET_CHECKS: 0 failures`. Validados toon por superfície, dimensões/contagem, origem no solo e ausência de colisões importadas; verificações existentes das arenas A/B/C também passaram. `git diff --check` passou. Sem revisão visual nesta rodada.
- **Ambiente:** persistem erros de certificados e permissões de logs/configuração do Godot em AppData. O `.glb.import` criado automaticamente foi removido após a verificação para manter a entrega nos caminhos autorizados; o próximo `--import` o recria. Nenhum commit; integração do boneco ao treino fica com o agente de gameplay.

Claude is editing gameplay/UI files in parallel. Touch ONLY these paths: `tools/blender/training_dummy.py`, `assets/models/training_dummy.glb` (+ its .json report), `scenes/assets/training_dummy.tscn`, the asset list in `tools/verify_assets.gd` / `tools/assets_gallery.gd`, and the "Assets gerados" table in `docs/specs/07-art-pipeline.md`.
- Model a stylised training dummy (Witch Hat Atelier workshop feel, Sea of Thieves proportions): wooden post on a round stone base, straw/cloth torso sack tied with rope, crossbar arms, a painted rune target on the chest, small pointed hat. 1.8 m tall, origin at the base centre, facing −Z, ≤ 3 000 triangles, flat colours only.
- Same pipeline as round 3: `common.py` helpers, headless Blender with `BLENDER_USER_CONFIG`/`BLENDER_USER_SCRIPTS` under `.blender_tmp/`, GLB Y-up, geometry JSON report, Godot wrapper applying `Toon.material` via `asset_visual.gd`.
- Run `--import` and `tools/verify_assets.tscn` until 0 failures. You cannot commit. Update this file (files + triangle count) and set `Active agent: none` for round 4 when done.
### Handoff brief for Codex (round 3 — Blender assets, user-approved 2026-09-25)
**Concluído no escopo autorizado; ver seção 12 antes de continuar.**
The user asked for Codex to generate the art assets in Blender. Blender 5.2.1 LTS is installed at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (verified headless). No paid services (no Tripo/Meshy): model procedurally with Blender Python.
- Run Blender only headless: `& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/<script>.py -- <args>`. If the sandbox blocks writes to AppData, set `$env:BLENDER_USER_CONFIG` and `$env:BLENDER_USER_SCRIPTS` to a folder under `D:\DynMagic\.blender_tmp\` (add it to .gitignore).
- One script per asset in `tools/blender/` (reproducible: running it rebuilds the .glb). Shared helpers in `tools/blender/common.py` (clear scene, bevel, flat colour material, export glTF binary Y-up, 1 unit = 1 m, apply transforms).
- Output `.glb` files to `assets/models/`. Style (spec 07): cartoon proportions like Sea of Thieves, chunky bevelled shapes, flat base colours only (the Godot toon shader replaces materials), mage aesthetic between Bleach and Witch Hat Atelier (pointed hat, long cloak, rune details).
- Assets, in order:
  1. `mage.glb` — full-body mage for the opponent view: pointed wide-brim hat, cloak, gloved hands, boots; ≤ 15k tris; origin at the feet, facing -Z, 1.8 m tall. A simple armature (root, spine, head, arms) is welcome but optional.
  2. `fp_arms.glb` — first-person gloved forearms + hands; 4 poses as separate objects or shape keys: open palm, fist, palm down, cast (spec 05 §4).
  3. Arena props matching `ArenaBuilder` sizes (spec 03 §2): `cover_low.glb` 1.5×1.0×1.5, `cover_high.glb` 1.5×2.2×1.5, `cover_bar.glb` 4.5×1.4×1.2, `pillar.glb` 3×3×3 — carved stone with bevels and rune engravings; plus `banner.glb`, `brazier.glb`, `spawn_arch.glb`.
  4. `arcane_core.glb` — floating faceted crystal on a small carved pedestal.
- Godot integration (keep gameplay code untouched except where listed):
  - `scenes/assets/*.tscn` wrappers that instance each .glb and apply `Toon.material(color)` to every MeshInstance3D (spec 07 §3: all imported materials replaced).
  - `Player._add_nameplate()`: replace the placeholder capsule with the mage scene.
  - `ArcaneCore.create()`: replace the prism mesh with the crystal scene.
  - `ArenaBuilder`: optionally swap cover visuals for the prop meshes while keeping the CSG boxes for collision (hide their mesh, keep `use_collision`). Only if it stays simple and tests pass.
  - Run `--headless --path D:\DynMagic --import` after adding .glb files and fix any import errors.
- Record triangle counts and a short description of each asset in `docs/specs/07-art-pipeline.md` (new section "Assets gerados"). Update ROADMAP M7 checkboxes.
- You cannot commit (read-only .git in your sandbox). Leave changes uncommitted and list them here; Claude reviews and commits. Set `Active agent: none (round 3 Blender assets reviewed and committed by Claude, 2026-09-25: 73/73 tests, verify_assets 0 failures, in-game check OK)` when you stop.
### Handoff brief for Codex (round 2, done)

**Conclu?do em 2026-09-25; altera??es sem commit para revis?o do Claude. Evid?ncias e arquivos na se??o 11.**
- Codex cannot commit (read-only .git in its sandbox): leave changes uncommitted and list them in this file; Claude commits after review.
- Round 2 tasks, in order:
  1. Settings: add resolution, render scale (50–100%), shadow quality and antialiasing (off/FXAA/MSAA 2x/4x) to the Video tab, persisted in user://settings.cfg (spec 06 §3).
  2. Match stats: track average compose time per player (first slot key to cast) on each client and send it to the host with the cast request; show it in the results panel (spec 02 §7).
  3. Reconnect: a player who reconnects within the 30 s pause with the same name takes back their slot (spec 04 §10, spec 02 §2). Keep it host-authoritative.
  4. Add tests where the logic is pure (settings round trip, compose-time averaging).
- Round 1 brief (done) kept below for reference.
- Current milestone: M6 Polimento (see ROADMAP M6). M0–M5 are done; milestone reviews are pending with the user (do not stop for them).
- Progresso desta sessão: formas brancas corrigidas no especular toon; legendas implementadas; carga de 20 zonas + 20 projéteis medida. Detalhes e evidências na seção 10.
- Próximos passos:
  1. Corrigir RPCs de `NetSync` após desconexão do host, reproduzidos no teste do draft (seção 10).
  2. Implementar transição de pincelada de tinta (spec 06 §4; atualmente há apenas fade).
  3. Revisão visual/áudio com o usuário, teste com duas janelas e performance na GTX 1660. Exportação depende de autorização para baixar templates.
  4. Música: pasta `audio/` sem assets; pergunta sobre download CC0 enviada, sem resposta até este registro. Manter bloqueada até autorização.
- Tools: Godot console binary at `C:\Users\vinic\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`. Without the Godot AI MCP, check scripts with `--headless --path D:\DynMagic --import` and run tests by opening the editor only if needed; multiplayer smoke tests are headless (see §5 notes).
- Do not touch: `addons/godot_ai/` (vendored plugin), `project.godot` autoload/plugin sections, `.claude/`.
- Do not download export templates or install paid services. Codex must leave changes uncommitted. Update this file and set `Active agent: none (round 3 Blender assets reviewed and committed by Claude, 2026-09-25: 73/73 tests, verify_assets 0 failures, in-game check OK)` when stopping.

## 1. What this project is

1v1 first-person dynamic-magic arena in Godot 4.7, LAN multiplayer. Players compose each spell by pressing 2 hotkeys (Form, Effect) on top of the element they drafted for the round. Full game loop: menu, lobby, draft, rounds, overtime, results, settings.

Source of truth: [`docs/SDD.md`](SDD.md) and [`docs/specs/01..08`](specs/). Task-level plan and loop protocol: [`docs/ROADMAP.md`](ROADMAP.md). Read the SDD first, then the spec for the area you touch. If code and spec disagree, the spec wins unless the user says otherwise; update the spec when the user changes a decision.

## 2. User and working style

- User writes in Portuguese (Brazil). Reply in Portuguese. Docs are in Portuguese; code, identifiers and comments in English.
- User prefers terse replies (they used "caveman" compressed style). No filler.
- User makes design decisions. Ask before changing any decision listed in SDD §2. Batch questions (max ~5 per round).
- User account: viniciosrodrigo.martins@gmail.com (identification only).

## 3. Locked decisions (summary of SDD §2)

| Topic | Decision |
|---|---|
| Camera | First person, visible arms |
| Spell grammar | Element (fixed for the round) + Form (Projectile/Self/Area) + Effect (Direct/Burst/Lingering). 4 elements: Fire, Frost, Storm, Wind. 36 spells total, 9 per round |
| Keys | `Q`/`E`/`R` pick option 1/2/3 of the current slot. `F` cancels. `LMB` confirms. `RMB` recasts last spell or cancels aiming |
| Cast modes | Quick (fires when the effect key is pressed): Bolt, Cone, all 3 Self spells. Confirm (aim preview + `LMB`): Orb, Seed, Mark, Wall |
| Draft | Every round each player picks exactly 1 element. Side A (north spawn) picks first (10 s), then side B (10 s). No duplicate element between the two players in the same round. Repeating your own element from the previous round is allowed. Sides swap every round, so first pick alternates |
| Match | Best of 7 (first to 4). 1 life per round, 90 s combat. 3-3 goes to a decisive round |
| Advantage | Loser of previous round picks 1 of 3 random runes. Arcane Core spawns at map center at 30 s of combat (capture gives Overcharge). No secondary element (user rejected it to keep complexity low) |
| Overtime | Random among Collapse (shrinking zone), Sudden Death (both at 1 HP), Mana Surge. Host can pin one rule in the lobby |
| Character | Single base mage. Identity comes from element colors/VFX |
| Maps | 3 variants (A "Claustro", B "Pátio Partido", C "Espinha") of a 28×38 m arena inspired by Valorant Skirmish maps. 180° rotational symmetry |
| Network | LAN, listen server, host-authoritative, ENet UDP 7777, LAN discovery via UDP broadcast on 7778 |
| Art | Shader-first (toon + outline + rune circles). M7 autorizado em 2026-09-25 com Blender 5.2.1 LTS headless + Python procedural; sem Tripo/Meshy, serviços pagos ou mcp-blender nesta rodada. Aesthetic: Bleach energy + Witch Hat Atelier rune magic, cartoon like Sea of Thieves |

## 4. Environment (user's Windows 11 machine)

| Item | Location / version |
|---|---|
| Project | `D:\DynMagic` (Git com histórico; nesta sessão `.git` é somente leitura e novos commits foram bloqueados) |
| Godot | 4.7.2 stable. `C:\Users\vinic\Downloads\Godot_v4.7.2-stable_win64.exe\` (this is a folder). GUI: `Godot_v4.7.2-stable_win64.exe`; console: `Godot_v4.7.2-stable_win64_console.exe`. Not on PATH |
| Node | 24.20.0 |
| Python | 3.14.7 |
| uv / uvx | 0.12.19, installed with `pip install --user uv`. Scripts dir `C:\Users\vinic\AppData\Roaming\Python\Python314\Scripts` added to user PATH (new shells only) |
| Git | 2.55 |

## 5. Godot MCP

Chosen: **Godot AI** by hi-godot (https://github.com/hi-godot/godot-ai), plugin v4.2.3, MIT. Picked over Coding-Solo/godot-mcp because it drives the live editor (46 tools, scene/node/script/material/particle editing) instead of only launching the project and reading logs.

- Plugin installed at `D:\DynMagic\addons\godot_ai\` and enabled in `project.godot`.
- Source: the user's download `Downloads\godot-ai-plugin.zip` was the v3→v4 migration bootstrap. The real v4 plugin came from its `migration_payload/godot-ai-v4-plugin.zip`. SHA-256 verified against the bundled manifest (`bff05c14...cdb417`).
- Architecture: MCP client (stdio) → `godot-ai attach` → Python server (HTTP 127.0.0.1:8000, authenticated) → editor plugin (WebSocket 127.0.0.1:9500).
- The editor must be open with the plugin enabled for the MCP tools to work.
- Client registration: open the "Godot AI" dock in the editor and press **Configure** next to your client. Do not hand-write a bare HTTP URL; it cannot authenticate. Claude Code is already configured (user scope).
- Tests: the Godot AI `test_run` tool runs `res://tests/test_*.gd` suites that extend `McpTestSuite` (`addons/godot_ai/testing/test_suite.gd`: `assert_true`, `assert_eq`, `assert_ne`, `assert_gt`, `setup`, `teardown`). GUT is not installed. **Every test suite must start with `@tool`**, otherwise the runner reports it as "cannot instantiate". Run `filesystem_manage(op="scan")` after adding a suite.
- Editor quirks: autoloads added while the editor runs are not visible to editor-side script compilation until the editor restarts. In the editor, `can_instantiate()` is false for non-@tool scripts and `InputMap` holds editor actions only; tests must read `ProjectSettings` (`input/<action>`) and script method lists instead. `--check-only --script` does not load autoloads, so it reports false "Identifier not found" errors for autoload names.
- Logic classes that editor tests instantiate (e.g. `Stats`) must be `@tool` and guard `_ready`/`_process` with `Engine.is_editor_hint()`; otherwise `.new()` returns a placeholder instance with no behavior.
- Injecting input into the running game: separate `input_key` calls take seconds each, longer than the 2.5 s composer timeout. Use `game_manage(op="input_sequence")` with steps `{action, pressed, at_frame}` (frame-timed). Presses a few frames apart can still be missed by `is_action_just_pressed`; space steps ~10+ frames. `SpellComposer` polls actions in `_process` (only while the mouse is captured).
- Player children run `_ready` before `Player`, so they must use `player.get_node(...)` instead of the player's `@onready` vars.
- Confirm spells expire after 4 s of aiming: put the whole compose + `cast` timeline in one `input_sequence` call.
- Collision layers: layer 1 = world, players and solid spells; layer 2 = barriers that stop projectiles but not players (wind Wall). Players mask layer 1 only; projectile rays use the default all-layers mask.
- Multiplayer: `--host`/`--join` load `scenes/net/net_match.tscn` (Arena A, one Player per peer with a `NetSync` child). Add `--bot` to a client for scripted movement and Bolt casts; `NetMatch` prints `[net]` state every 2 s.
- Multiplayer smoke test: start two console instances with `--headless --path D:\DynMagic --quit-after <frames> -- --host --name A` and `... -- --join 127.0.0.1 --name B`, redirect stdout to files and grep `[net]` lines.
- Input bindings use `keycode` (not `physical_keycode`). Revisit in M6 remapping if non-QWERTY layouts matter.

## 6. Status by milestone (SDD §6)

| Milestone | Status |
|---|---|
| Design (SDD + specs 01–08) | Done, decisions validated by user |
| M0 Setup | Done 2026-09-24: MCP verified, folder skeleton, 7 empty autoloads, 16 input actions, smoke suite 4/4 passing, first commit |
| M1 Sandbox | Done 2026-09-24 (review pending with user): FPS controller, Stats, SpellDB, SpellComposer, all 9 fire spells, dummy, Arena A greybox, temporary HUD |
| M2 Grimório | Done 2026-09-24 (review pending): 4 elements, 36 spells with element variants, status effects, rune circle, element VFX |
| M3 Rede | Done 2026-09-24 (review pending): ENet host/join, LAN discovery, codec, prediction/reconciliation, interpolation, host-validated casts, lag compensation, simulator, F3 overlay, 5-min soak OK |
| M4 Loop | Done 2026-09-24 (review pending): full MD7 bot run OK, stats, Core capture + overtime tie-break seen live. Runes not yet seen live |
| M5 Arenas | Done: A/B/C via ArenaBuilder, symmetry + sight-line tests, per-round rotation |
| M6 Polimento | Em progresso: menus/LAN/lobby, configurações/remap/paletas, grimório, draft/pausa/resultados/HUD, toon + outline, áudio sintetizado e legendas. Fluxo de UI com host renderizado + cliente headless validado; carga local validada. Pendentes: RPC ao desconectar, pincelada de transição, revisão com duas janelas/áudio, música, performance na GPU-alvo e exportação Windows (download de templates precisa de autorização) |
| M7 | Rodada 3 concluída: 10 GLBs procedurais + wrappers toon, mago/Núcleo/coberturas integrados; 73 testes e validação de assets/colisões passaram. Sem commit. Rig/animações, braços em runtime, posicionamento decorativo e revisão artística pendentes; seção 12. |

## 7. Next steps

Follow `docs/ROADMAP.md`: take the first unchecked task. Summary:

1. Concluir M6: corrigir RPC pós-desconexão, transição de tinta, revisão com duas janelas e áudio, performance na GPU-alvo; música e templates de exportação aguardam autorização para download. Os três primeiros itens do handoff anterior foram concluídos (seção 10).
2. Revisar e commitar a rodada 3 descrita na seção 12 (Claude; Codex não pode commitar). Revisões dos marcos com o usuário continuam pendentes.
3. Continuar M7 após revisão: rig/animações do mago; conectar braços/poses ao controlador e animação de cast 0,12 s com camada sem clipping; posicionar estandartes/braseiros/portais. A geração procedural já foi autorizada e concluída, sem serviços pagos.

## 8. Useful commands

```powershell
$g = "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
& $g --headless --path D:\DynMagic --import            # reimport / check script errors
& $g -e --path D:\DynMagic                              # open editor
& $g --path D:\DynMagic -- --host [--bot] [--match-speed 10] [--sim-latency 40 --sim-jitter 10 --sim-loss 0.02]
& $g --path D:\DynMagic -- --join 127.0.0.1 [--bot]     # CLI skips menu/lobby and loads net_match directly
```

## 9. Rules for the next agent

- Website (2026-09-25): `web/` is published at **http://vsennaa.duckdns.org/dynmagic/** (VPS `vinicios@45.39.210.28`, key `~/.ssh/id_ed25519`, nginx route `location /dynmagic/` with `alias /var/www/dynmagic/` inside the first server block of `/etc/nginx/sites-enabled/default`; backups in `/root/default.bak.*`). Redeploy: scp `web/` to `/tmp/dynmagic-web` and copy into `/var/www/dynmagic/`. A dedicated DNS name comes later.
- VPS game server (2026-09-26): `dynmagic@room1` runs v1.1.0-alpha on **vsennaa.duckdns.org UDP 7777**, name "DynMagic VPS", Colapso + arena rotation (`/etc/dynmagic/room1.env`), ~55 MB RSS, enabled at boot. Update with `server/install.sh <tag>` (see server/README.md). Tested: two bot clients from Windows joined, auto-started and played. The provider firewall already lets UDP 7777 through (no ufw on the box).
- License (user 2026-09-25): PolyForm Noncommercial 1.0.0 (`LICENSE.md`) + `NOTICE.md` (required notice, extra permission for monetized videos/streams, third-party components).

- Update this file at the end of every work session: status table, next steps, any new decision.
- Record every new user decision in SDD §2 and in the relevant spec.
- Keep GDScript statically typed (untyped declarations are errors in `project.godot`).
- Commits are authorized (2026-09-24): commit after each finished roadmap task. Remote (2026-09-25): `origin` = `git@github.com:VSennaa/DynMagic.git` (public), pushed over SSH with the repo-only deploy key `~/.ssh/dynmagic_github` (set in repo-local `core.sshCommand`). Pushing `main` is authorized. Do not install paid services without asking the user.
- Dedicated server (M9): `--server [--name X] [--port N]` (headless) hosts without a local player; `scenes/net/server_lobby.tscn` idles, `Lobby` auto-starts when both clients are ready, `NetMatch` returns everyone to the lobby 15 s after results. Linux preset "Linux Server" (dedicated_server export) + `server/README.md` + `server/dynmagic.service`; CI smoke-tests it.
- Spectators: `Net.join(ip, port, true)` / `--spectate` / "Entrar como espectador"; stored in `Net.spectators`, never in `Net.players`; `SpectatorCamera` (1/2 follow, 0 free). Use it to inspect remote-only visuals (mage animations).
- Viewmodel: `Settings.viewmodel_fov` (default 60, 54-68, CS2 reference) drives the first-person arms camera; arms scale 0.72 at REST_OFFSET in `first_person_arms.gd`.
- Tag v0.2.0 exists without a release (CI smoke test failed: stdout lost on `timeout` kill). Fixed with `--quit-after`; first published server package is v0.2.1.
- Releases: push an annotated tag `vX.Y.Z`; `.github/workflows/release.yml` exports Windows x64 on GitHub Actions and publishes `DynMagic-vX.Y.Z-windows-x64.zip` with `docs/release-notes.md`. v0.1.0 published 2026-09-25 and its exe was re-tested over LAN. Local build: `godot --headless --path D:\DynMagic --export-release "Windows Desktop" build/windows/DynMagic.exe` (templates 4.7.2 installed in %APPDATA%\Godot\export_templates).
- Quota handoff: the user wants work handed to Codex CLI (skill `handoff-codex`) when the Claude 5-hour limit reaches 90%. Codex CLI 0.156.1 is installed at `C:\Users\vinic\AppData\Local\Programs\OpenAI\Codex\bin\codex.exe` (2026-09-24).
- Standing goal (2026-09-24): keep working through milestones without stopping at reviews until the Claude 5-hour quota nears its limit; at 90% hand off to Codex (`handoff-codex`) and schedule a resume after the reset (no later than 05:30).
- Loop mode: the user runs `/loop Siga docs/ROADMAP.md (protocolo de loop no topo)`. Under the standing goal, milestone reviews are recorded as pending instead of stopping.
- Key code map: `scenes/player/` (Player, Stats, SpellComposer, SpellCaster, NetSync, AimPreview, RuneCircle), `scenes/spells/` (SpellNode base, Projectile/Burst/Lingering, SelfSpell, AreaSpell, Zone, Wall), `scenes/match/` (MatchFsm, ArcaneCore, CollapseZone), `scenes/net/net_match.gd` (networked match, draft panel, results, scoreboard), `scenes/ui/` (menus, UiKit, Hud), `autoload/` (Net, NetCodec, MatchState, Lobby, SpellDB, Settings, AudioBus, SceneRouter).

## 10. Codex session progress (2026-09-24)

- **Formas brancas:** reproduzidas pelo fluxo real de botões Menu → Jogar LAN → Criar sala → Pronto → Iniciar, com cliente `--join 127.0.0.1 --lobby --bot`. Ocultar remoto e outline não altera as manchas. Desativar somente `SPECULAR_LIGHT` elimina ambas; desativar o especular ambiental não elimina. Causa: especular toon amplo/saturado sobre piso e paredes. Ajuste mínimo em `shaders/toon.gdshader`: limiar 0.96 → 0.995, intensidade 0.25 → 0.035, preservando o brilho em blocos. Capturas: `build/draft_original.png`, `draft_no_remote.png`, `draft_no_outline.png`, `shading_original.png` (esta última já contém a correção, mesma câmera norte).
- **Legendas:** opção persistida em Settings, evento de conjuração de AudioBus e texto no HUD. Alcance 30 m, direção relativa à câmera, até três mensagens por 2,5 s; desligadas por padrão, funcionam com volume zerado. `tests/test_sound_caption.gd` cobre direções/rotação/alcance. Asserções de integração áudio/HUD, expiração, limite e toggle passaram; captura 1280×720 inspecionada em `build/captions.png`. Gravação real de `user://settings.cfg` entre sessões não foi exercitada devido ao sandbox.
- **Carga:** `F8` no treino (debug) liga/desliga `TrainingStress`: 20 zonas reais + 20 projéteis reais dos quatro elementos, reposição automática, velocidades normais. Logs a cada 2 s; `--fps` mostra contador. Após a correção do shader: **351–352 FPS** sob carga de 10 s, baseline **413–414 FPS** por 6 s; 1920×1080, Vulkan Forward+, VSync off, sem limite, AMD Radeon RX 580 2048SP. Captura `build/stress.png`, log `build/stress-final.log`. Toggle e remoção da carga verificados. Não substitui teste prolongado/GTX 1660.
- **Validação:** import final sem erros de scripts do projeto; 63 testes, 0 falhas pelo `McpTestRunner` via CLI (`build/check_suites.tscn`). Harnesses e capturas em `build/` são locais/ignorados pelo Git. Há avisos de certificados, cache/configuração sem permissão e recursos retidos ao sair; não representam uma execução totalmente sem avisos.
- **Ferramentas:** MCP `editor_state` exige aprovação, indisponível com política `never`. CLI renderiza normalmente. Use `--log-file D:\DynMagic\build\<name>.log`; não alterar plugins/autoloads. `.git` somente leitura: `git add` falhou ao criar `index.lock`; **nenhum commit desta sessão**. Mudanças prontas no workspace; separar commits de legendas, carga e shader quando permitido, preservando o handoff preexistente.
- **Pendência encontrada:** ao fechar o host, o cliente emite `RPC 'receive_inputs' on yourself is not allowed` durante o fade para menu. `NetSync._on_input_sampled` continua enviando após `Net.close`; conferir também callbacks atrasados de `simulate_send`. Reprodução/log em `build/draft-client.log`. Nenhum ajuste fora do escopo foi feito.
- **Música:** nenhum asset CC0 no repositório. Download perguntado ao usuário, ainda sem resposta; nada baixado. Templates de exportação e Blender/Tripo também não foram instalados.

## 11. Codex round 2 ? conclu?do (2026-09-25)

- **V?deo:** resolu??o (720p?4K), escala 50?100% com valor vis?vel, sombras baixa/m?dia/alta e Off/FXAA/MSAA 2?/4? na se??o V?deo. `VideoSettings` cont?m os dados puros; `Settings` aplica na hora e grava/carrega em `user://settings.cfg`. Padr?o 1080p preservado. Tela cheia mant?m o modo do desktop e usa a resolu??o-base 3D documentada na spec 06. N?o alterados plugins nem se??es de autoload de `project.godot`.
- **Composi??o:** primeira tecla de forma at? conjura??o, incluindo mira/buffer; dura??o enviada no RPC. Host acumula apenas casts aceitos, valida amostras finitas e plaus?veis e exibe m?dia por jogador nos resultados. Recast, cancelamento, timeout e rejei??o n?o entram; aus?ncia de amostras mostra `?`. Protocolo de rede incrementado para **2**: os dois execut?veis devem usar esta vers?o.
- **Reconex?o:** nome normalizado exato recupera o slot dentro da pausa de 30 s. Host mant?m a inst?ncia do jogador, remapeia peer/FSM/estat?sticas/progresso do N?cleo, espera carregamento e envia bootstrap autoritativo de posi??o, HP/mana/escudo, runas, status/cooldowns, buffs, ?ltima magia, objetos ativos e colapso. Simula??o da arena para durante a pausa. Nomes diferentes e entradas ap?s expira??o s?o rejeitados; prazo n?o escala com `--match-speed`. W.O. continua autoritativo; sem migra??o do host.
- **Desconex?o:** `NetSync` n?o envia input sem servidor; callbacks do simulador carregam a gera??o da sess?o e s?o descartados ap?s `Net.close`. `MatchState` s? processa partidas ativas do host. Estas prote??es cobrem a causa descrita na se??o 10; o smoke visual com host fechado durante fade/lat?ncia ainda deve ser repetido.
- **Valida??o:** **73 testes, 0 falhas** (`build/round2-tests.log`), incluindo ConfigFile round trip/defaults/limites, m?dia por jogador/amostras inv?lidas, composi??o com mira/buffer/cancelamento/recast, remapeamento de slot, prazo e bootstrap de Stats. Import sem erros de scripts do projeto; `git diff --check` passou.
- **Integra??o real ENet:** `build/r2_probe.py` / `probe-*.log`: host e cliente mediram aproximadamente **0,40 s**, transmitidos por RPC; reconex?o preservou identidade da inst?ncia, HP 37, mana 42, cooldown/status, score, m?dia, buffs e quatro objetos ativos (zona, parede, proj?til, aura). `build/r2_smoke.py` / `r2-*.log`: bots voltaram a mover/conjurar ap?s reconectar e outro nome foi recusado. `build/r2_forfeit.py` / `forfeit-*.log`: pausa expirada levou a W.O. e reconex?o tardia foi rejeitada.
- **V?deo em runtime:** grava??o e leitura de `Settings` em processos separados com caminho de teste `build/r2-settings.cfg` (mesma implementa??o de ConfigFile; n?o foi escrito o arquivo pessoal em `user://` por restri??o do sandbox). Assertions de escala/AA passaram. Tela renderizada em Vulkan Forward+ na RX 580 e inspecionada a 1280?720: `build/r2-settings.png`; logs `r2-video-write.log` e `r2-video-read.log`. N?o substitui compara??o visual de sombras/AA em todas as resolu??es/GPU-alvo.
- **Avisos ambientais:** certificados do Windows, cache de shaders/configura??o do editor sem permiss?o e os mesmos 7 objetos/3 recursos retidos no runner ao sair. N?o houve erros de script/RPC nas execu??es finais de integra??o. Harnesses/capturas em `build/` s?o locais e ignorados pelo Git.
- **Arquivos sem commit ? v?deo:** `autoload/settings.gd`, novo `autoload/video_settings.gd`, `scenes/ui/settings_screen.gd`, novo `tests/test_video_settings.gd` e spec 06.
- **Arquivos sem commit ? composi??o/rede:** `autoload/match_state.gd`, `autoload/net.gd`, `scenes/net/net_match.gd`, novos `scenes/net/reconnect_state.gd` e `scenes/match/compose_metrics.gd`, `scenes/match/match_fsm.gd`, `scenes/match/arcane_core.gd`, `scenes/player/spell_composer.gd`, `scenes/player/net_sync.gd`, `scenes/player/stats.gd`, `scenes/spells/self_spell.gd`, novos testes `test_compose_metrics.gd`/`test_reconnect_stats.gd`, testes existentes `test_spell_composer.gd`/`test_match_fsm.gd`, specs 02/04, este handoff e `.uid` dos novos scripts.
- **Pr?ximo agente:** revisar o diff e commitar; continuar as pend?ncias de M6 acima. Nenhum commit, download, instala??o ou altera??o em `addons/godot_ai/`, `.claude/` ou `project.godot` nesta rodada. As altera??es preexistentes deste handoff foram preservadas, com status atualizado.

## 12. Codex round 3 — Blender assets (2026-09-25)

- **Escopo entregue, sem commit:** 10 modelos feitos proceduralmente no Blender 5.2.1 LTS, executado somente headless; um gerador por asset e helpers compartilhados. Nenhum download/serviço pago, rig externo ou alteração em `addons/godot_ai/`, `.claude/` e `project.godot`. `.git` não foi escrito. A autorização procedural foi registrada no SDD e spec 07.
- **Geometria final (LOD 0, Blender e Godot concordam):** `mage` **1.304** tris; `fp_arms` **2.368** (quatro poses, dois braços em cada); `cover_low` **319**; `cover_high` **326**; `cover_bar` **696**; `pillar` **326**; `banner` **288**; `brazier` **280**; `spawn_arch` **646**; `arcane_core` **204**. Total da biblioteca: **6.757**. Mago 1,80 m, origem nos pés, frente −Z. Coberturas X/Y/Z exatas: 1,5/1/1,5; 1,5/2,2/1,5; 4,5/1,4/1,2; 3/3/3. Todos abaixo dos budgets. Descrições em `docs/specs/07-art-pipeline.md`, seção “Assets gerados”.
- **Integração:** wrappers substituem todas as superfícies por `Toon.material(cor)` e compartilham a paleta para evitar erros na liberação dos materiais. Outline existente nas câmeras. `Player._add_nameplate()` instancia o mago remoto; `ArcaneCore.create()` usa cristal/pedestal e anima só o cristal. `ArenaBuilder` troca apenas coberturas de tamanho exato, mantendo CSG visível para física, `use_collision = true` e render `layers = 0`; visual irmão com mesma rotação e origem no chão. Nichos/peças especiais continuam greybox.
- **Arquivos novos:** `tools/blender/common.py` + `mage.py`, `fp_arms.py`, `cover_low.py`, `cover_high.py`, `cover_bar.py`, `pillar.py`, `banner.py`, `brazier.py`, `spawn_arch.py`, `arcane_core.py`; `assets/models/<nome>.glb`, `.glb.import` e `.json` para os 10 modelos; `scenes/assets/<nome>.tscn` para os 10 wrappers e `asset_visual.gd`/`.uid`; `tools/verify_assets.gd`/`.uid`/`.tscn` e `tools/assets_gallery.gd`/`.uid`/`.tscn`.
- **Arquivos existentes modificados:** `.gitignore` (ignora `__pycache__/`; `.blender_tmp/` já estava ignorado), `scenes/player/player.gd`, `scenes/match/arcane_core.gd`, `scenes/arena/arena_builder.gd`, `docs/SDD.md`, `docs/specs/07-art-pipeline.md`, `docs/ROADMAP.md` e este handoff. Deixar sem commit para revisão do Claude.
- **Verificação:** import final sem erros de importação/scripts do projeto (`build/round3-import.log`); **73 testes, 0 falhas** (`build/round3-tests.log`); `tools/verify_assets.tscn`: **0 falhas** (`build/round3-assets.log`). Verifica contagens/dimensões, toon por superfície, origem no solo, ausência de colisão nos GLBs, exclusividade das quatro poses, mago remoto e pedestal parado. Raycasts físicos atingem o topo de todas as coberturas e bloqueiam spawn-spawn nas arenas A/B/C. `git diff --check` passou.
- **Reprodução:** todos os 10 geradores executados novamente, com relatórios geométricos idênticos (`build/round3_rebuild.py`, `build/*-rebuild.log`). Alguns GLBs diferem binariamente entre execuções; não foi exigida identidade byte a byte. Comandos de rebuild/import/verificação/galeria estão na spec 07.
- **Visual e LAN:** galeria renderizada em Vulkan Forward+ na RX 580 e inspecionada com toon/outline: `build/assets/godot-gallery.png`; prévias Blender individuais em `build/assets/`. Smoke ENet de dois bots, 2.400 frames por processo, com rotação de rounds/arenas: sem erros de script, RPC ou materiais (`build/round3-host.log`, `round3-client.log`; harness `round3_smoke.py`). Não substitui revisão humana de arte nem performance na GPU-alvo.
- **Avisos ambientais:** import ainda acusa impossibilidade de gravar editor settings em AppData; certificados do Windows e cache de shaders também têm avisos de permissão. Runner geral mantém os 7 objetos/3 recursos retidos já conhecidos. Erros de material nulo encontrados inicialmente foram corrigidos pelo compartilhamento da paleta; verificação final e smoke LAN sem esses erros. Capturas/harnesses/logs em `build/` são locais e ignorados.
- **O que resta:** rig/animações do mago (opcionais nesta rodada); conectar braços ao controlador, mapear poses e animar cast 0,12 s numa camada sem clipping; posicionar `banner`, `brazier`, `spawn_arch` nas arenas; revisão artística com usuário e performance. Os braços já têm quatro objetos/poses selecionáveis no wrapper, mas não aparecem no jogador local ainda, respeitando a lista restrita de integrações autorizadas. Chama do braseiro estática. M7 permanece aberto para esses itens; pendências de M6 não foram ampliadas/tratadas nesta rodada.
