# DynMagic — Roadmap

Task-level plan for milestones M0–M7 (SDD §6). Built for autonomous loop sessions: each iteration takes the **first unchecked task** in the current milestone, implements it, verifies it, checks the box and updates `docs/HANDOFF.md`.

Legend: `[ ]` todo · `[x]` done · `[~]` in progress · `[!]` blocked (write the reason inline).

## Loop protocol (read every iteration)

1. Read `docs/HANDOFF.md` §6–7 and this file. Find the first `[ ]` or `[~]` task in the lowest unfinished milestone.
2. Read the spec linked by the task. Do not invent rules that the spec does not have. If the spec is ambiguous, mark `[!]` with the question and move to the next unblocked task.
3. Implement. Keep GDScript statically typed. Code and identifiers in English.
4. Verify:
   - Script errors: `logs_read(source="editor")` must be empty for project files, or run `--headless --import`.
   - Tests: `test_run` (Godot AI runner, suites in `res://tests/test_*.gd` extending `McpTestSuite`).
   - Gameplay tasks: `project_run` + `logs_read(source="game")`; a screenshot when the task is visual.
5. Check the box. Add a short note with the date if something is non-obvious.
6. Update `docs/HANDOFF.md` (status table + next steps).
7. Commit after each finished task (user authorized commits on 2026-09-24). Conventional Commits, one task per commit.
8. Stop the loop and ask the user when: a locked decision (SDD §2) would change, a paid service or new install is needed, or a milestone is done (milestone review).

## M0 — Setup

- [x] Godot 4.7.2 + Node + Python + uv installed (spec 08 §1)
- [x] Godot AI plugin v4.2.3 installed, enabled, server on 8000/9500
- [x] Claude Code connected to Godot AI MCP (verified 2026-09-24 with `editor_state`)
- [x] `project.godot`, `.gitignore`, `git init`, `AGENTS.md`, `CLAUDE.md`, `docs/HANDOFF.md`
- [x] Test harness: `res://tests/test_smoke.gd` extending `McpTestSuite`, passes in `test_run` (decision: use the Godot AI runner instead of GUT; revisit GUT only if headless CI is needed)
- [x] Folder skeleton from SDD §4.2 (`autoload/`, `data/`, `scenes/`, `shaders/`, `vfx/`, `audio/`, `tests/`, `tools/`)
- [x] Empty autoloads registered: `Settings`, `Net`, `Lobby`, `MatchState`, `SpellDB`, `AudioBus`, `SceneRouter`
- [x] Input actions from spec 06 §3 in `InputMap`
- [x] First commit (user authorized commits 2026-09-24)

## M1 — Sandbox (offline, 1 element)

- [x] `PlayerTuning.tres` with every value from spec 05 §2
- [x] `Player` scene: CharacterBody3D, head, camera, FOV from settings (spec 05 §1). Sandbox test scene at `scenes/sandbox/sandbox.tscn` (current main scene)
- [x] First-person movement: walk, sprint, crouch, jump, coyote time, step-up (spec 05 §2). Verified walk + jump in game via MCP input; step-up and crouch tunnel still need a manual playtest
- [x] Mouse look with sensitivity and invert Y (values in `Settings` autoload, in-memory until M6)
- [x] `Stats` node: HP, mana, regen pause, shield, status stacking, cooldowns (spec 05 §3)
- [x] Data classes: `ElementDef`, `SpellBase` with `cast_mode`, `ResolvedSpell`; 9 bases in `data/spells/`, `fire.tres` (spec 01 §4). `FormDef`/`EffectDef` deferred to M2 rune circle (they only carry glyphs; ids live in `SpellDB.FORMS`/`EFFECTS`)
- [x] `SpellDB.resolve()` pure function + test for one element
- [x] `SpellComposer` FSM: IDLE, SLOT_EFFECT, AIMING, CASTING, timeout, cancel, 150 ms buffer (spec 01 §1). Wired to `Player` (validator checks Stats; `Player.spell_cast` fires after paying mana/cooldown)
- [x] `test_spell_composer.gd`: quick vs confirm, timeout, cancel, recast
- [x] Spell: Bolt (projectile/direct). Shared pieces: `SpellNode` base, ray-stepped `Projectile`, `SpellCaster` (aims at crosshair point), `receive_hit()` on group "damageable". Headshot ×1.5 still pending (needs hurtboxes)
- [x] Spell: Orb (projectile/burst) + aim preview (`AimPreview` ring aligned to the hit surface; also serves Mark). Fire burning ground variant pending (M2)
- [x] Spell: Seed (projectile/lingering) + arc preview + zone (`Zone` ticks every 0.5 s; reused later by other lingering effects)
- [x] Spell: Guard (self/direct) — `SelfSpell` shared by the 3 self spells
- [x] Spell: Impulse (self/burst) with i-frames (`Player.start_dash`; verified in game)
- [x] Spell: Aura (self/lingering) — status `aura` + `Player.active_aura`; `damage_mult()`/`speed_mult()` read element bonuses. Guard/Aura not yet checked in game (no HUD); verify with the HUD task
- [x] Spell: Cone (area/direct) — `AreaSpell` shared by the 3 area spells; line-of-sight checked; lag compensation in M3
- [x] Spell: Mark (area/burst) + ground preview (`SpellCaster.ground_target`)
- [x] Spell: Wall (area/lingering) + ghost preview (`Wall` StaticBody with HP; `SpellCaster.wall_transform`). All 3 verified in game: Cone 23, Mark 44 + burn, Wall blocked a Bolt
- [x] Training dummy: infinite HP, damage numbers, DPS counter
- [x] Greybox Arena A (spec 03 §3) for testing — `ArenaBuilder` (@tool) builds shell, balconies with ramps, cover and spawn markers from a half-map table mirrored 180°. Main scene is now `scenes/sandbox/training.tscn` (Arena A + dummy)
- [x] Temporary HUD: HP, mana, composition trail, 3×3 cooldown grid (`Hud`, built in code; also shows shield and statuses). Guard and Aura verified in game through it
- [~] Milestone review with user — M1 done 2026-09-24. User asked (goal) to keep going without pausing; review happens when the user is back. Open items: headshot ×1.5 (needs hurtboxes), manual playtest of step-up and crouch tunnel

## M2 — Grimório (4 elements)

- [x] `fire.tres`, `frost.tres`, `storm.tres`, `wind.tres` with colors and multipliers (spec 01 §3); variant params encoded, behaviors land in the variant tasks
- [x] Status effects: burn, slow, shock, knockback (`Player.receive_status`; verified burn and knockback in game on the offline `Target` player)
- [x] Element variants for Projectile row (spec 01 §3 table): fire/frost Bolt status, storm speed, wind homing; Orb burning/frozen ground, storm chain (verified), wind pull; Seed zones incl. wind deflect. Frozen ground uses slow (low friction not modelled)
- [x] Element variants for Self row: Guard reflect/no-sprint/shock-on-break/deflect-next (`Player.active_guard`), Impulse fire trail/frost slide/storm teleport (verified)/wind lift+glide, Aura damage/slow-immune+shield/cooldown+projectile speed/move speed+double jump
- [x] Element variants for Area row: Cone via params (range/slow/arc/knockback), Mark frost root + wind launch + storm fast delay, Wall fire contact burn / frost 180 HP opaque / storm non-solid contact damage / wind projectile-only (collision layer 2)
- [x] `test_spell_resolution.gd`: all 36 combinations vs expected table
- [x] Rune circle shader + glyph per form + ring per effect (spec 01 §5, spec 07 §2): procedural `shaders/rune_circle.gdshader` (arrow/circle/square glyphs; solid/toothed/dotted rings) on `RuneCircle` in front of the hands, visible to both players
- [x] Placeholder VFX per element (GPUParticles3D): `vfx/element_fx.gd` trails on projectiles and bursts on explosions; shared `SpellNode.floor_below()` keeps zones off bodies
- [x] Training mode: pick element with keys 1-4 (fire, frost, storm, wind). A menu comes with M6 UI
- [~] Milestone review with user — M2 done 2026-09-24, review pending (goal: keep going)

## M3 — Rede

- [x] `Net` autoload: host/join by IP, ENet 7777, channels (spec 04 §1, §8)
- [x] CLI args `--host` / `--join <ip>` (+ `--port`, `--name`, `--discover`)
- [x] Handshake + protocol version check (spec 04 §3); verified host+client headless. Room-full and version reject paths not exercised yet
- [x] LAN discovery broadcast on 7778 + lobby list (spec 04 §2); verified headless (lobby list UI lands in M6). Note: the broadcast source IP may be a VPN adapter (26.x seen on this PC)
- [x] `InputFrame` + `Snapshot` serialization + `test_net_serialization.gd` (`NetCodec`: ~14 B per input frame, ~50 B per player entry)
- [x] Client prediction + reconciliation (spec 04 §5): `NetSync` (history, ack, replay). Headless bot test: corrections 0.06-0.11 m
- [x] Remote player interpolation (100 ms buffer)
- [x] Cast request/validation/spawn flow (spec 04 §6): `NetMatch.request_cast` → host validates → `_spawn_spell` on all peers. `SpellCaster.cast_params` fixes origin/direction/target at the caster
- [x] Deterministic projectile simulation on both sides; host-only hit detection (`SpellNode.has_authority()`). remote rune circle driven by composer bits from inputs/snapshots
- [x] Lag compensation for Cone (host keeps 250 ms of positions per player; rewind = RTT/2 + interpolation delay + simulated latency)
- [x] Network simulator (latency/jitter/loss) + F3 overlay (`--sim-latency/--sim-jitter/--sim-loss` on unreliable streams). Headless bot at 80 ms RTT + 2% loss: corrections 0.06-0.11 m only at direction changes; host repeats the last input when one is late
- [x] Two local instances play 5 min without visible desync (headless bot soak, 80 ms RTT + 2% loss: 0 errors, reconciliation avg 0.08 m / max 0.11 m)
- [~] Milestone review with user — M3 done 2026-09-24. Review pending

## M4 — Loop de partida

- [x] `MatchState` FSM on host (spec 02 §2) + `test_match_fsm.gd`: pure `MatchFsm` (draft order, rune offers, Core timer, overtime choice and timeout rules, decisive round, disconnect pause/forfeit), 13 tests. Wiring into NetMatch is the next tasks
- [x] Side swap every round, spawn barriers during countdown (`Player.frozen` during draft/countdown/round end; respawn in `NetMatch._start_round`)
- [x] Sequential draft: side A then side B, no duplicate element (spec 02 §3): keys 1-4 in the net match (draft screen UI in M6); bots auto-pick
- [x] Runes: 7 runes + loser pick of 3 random (spec 02 §3): ids in `MatchFsm.RUNES`, effects in `Player.apply_rune`/`mana_cost_for`/`damage_mult`/`speed_mult`, keys 5-7 to pick. Not yet seen in a live match
- [x] Arcane Core: spawn at 30 s, capture rules, Overcharge (spec 02 §4): `ArcaneCore` (host counts progress, damage resets it) + `Player.grant_overcharge`. Verified live: a bot captured it and won the overtime tie-break "core"
- [x] Overtime: Collapse (spec 02 §5): `CollapseZone` 24→5 m in 20 s, 12 dps outside
- [x] Overtime: Sudden Death (HP 1, shields off, burn off, Collapse after 30 s)
- [x] Overtime: Mana Surge (free spells, cooldowns -50% for 20 s, then Collapse)
- [x] Overtime timeout + tie-break rules (in `MatchFsm`, tested)
- [x] Decisive round at 3-3 (spec 02 §6) in `MatchFsm` (tested). Random arena for it waits for arenas B/C (M5)
- [x] Disconnect pause 30 s + forfeit (`MatchState._on_peer_left`). Rejoin into the same slot not implemented yet
- [x] Match stats collection (spec 02 §7): damage dealt/taken, casts and hits per form, Core captures (compose time not tracked yet); sent to clients at match end
- [x] Full best-of-7 LAN match end to end: headless bots with `--match-speed 10`, 13 rounds (kill/hp/draw) to MATCH_END 4-0, stats on both peers, 0 errors
- [~] Milestone review with user — M4 done 2026-09-24 (review pending)

## M5 — Arenas

- [x] `arena_base.tscn` with walls, side balconies, spawns, lighting (spec 03 §1, §5): shared shell generated by `ArenaBuilder`; `arena_a/b/c.tscn` only set `variant`
- [x] `tools/build_arena.gd`: half-map table + 180° mirroring — lives in `ArenaBuilder.LAYOUTS` + `mirrored_layout()` (@tool, rebuilds live in the editor)
- [x] Arena A "Claustro"
- [x] Arena B "Pátio Partido"
- [x] Arena C "Espinha"
- [x] `test_arena_symmetry.gd`: mirroring ≤ 1 mm + no spawn-to-spawn line of sight (in `test_arena_layout.gd`, all 3 variants)
- [~] Arena selection (Fixed/Rotation/Random): `MatchFsm.arena_setting` + per-round rebuild in `NetMatch` done; lobby UI option comes with M6
- [ ] Milestone review with user

## M6 — Polimento

- [x] Main menu with animated 3D background (spec 06 §1); now the project main scene
- [x] Host/Join screens + lobby screen (`play_lan`, `lobby_screen`, `Lobby` autoload with ready flags and rules). UI flow verified 2026-09-24: menu → Jogar LAN → Criar sala → headless client `--join <ip> --lobby --bot` → both ready → Iniciar → draft panel. Fixed a host-side aliasing bug that wiped ready flags. Formas brancas reproduzidas e corrigidas: especular toon amplo/saturado, não cápsula/outline. Limiar/intensidade ajustados; capturas A/B no handoff §10.
- [ ] Corrigir envio de inputs após desconexão do host: `NetSync._on_input_sampled` emite RPC para si mesmo durante o fade para menu (reproduzido 2026-09-24; `build/draft-client.log`).
- [x] Draft screen: element cards (disabled when taken or not your turn) + rune offer + timer, in `NetMatch._update_draft_panel`; headless run clean. Keys 1-7 still work
- [~] Final HUD (spec 06 §2): temporary HUD + match line + rune/Overcharge/status line. directional damage arrow (points at the opponent), Core capture bar (1 Hz from host), Tab scoreboard added. Pending: final art
- [x] Pause menu + forfeit (Esc in the match; online match keeps running)
- [x] Results screen + rematch (panel with score, damage, accuracy, Cores; "Voltar ao lobby" = rematch path)
- [x] Grimório screen (36-spell reference; text only, no preview video)
- [x] Settings screens + `user://settings.cfg` persistence (spec 06 §3): video (fullscreen, vsync, FOV, FPS cap), audio buses, sensitivity, invert Y, name, damage numbers. Resolution/render scale/shadows/AA not exposed yet
- [x] Input remapping with conflict detection (conflicting action loses the key and the player is told)
- [~] Accessibility: colour-blind palettes done (Okabe-Ito based, recolours elements live; glyph shapes already encode form/effect). No camera shake exists yet; sound captions implemented 2026-09-24 (persisted toggle, camera-relative direction, 30 m range, 3 messages/2.5 s). CLI integration tests and rendered 1280×720 capture passed; persistência em disco entre sessões ainda não exercitada no sandbox.
- [x] Toon + outline shaders on everything (spec 07 §2): `shaders/toon.gdshader` (3 bands, rim, block specular, painted noise) on arena geometry and remote bodies; screen-space ink outline (`shaders/outline.gdshader`) on the local camera and menu camera via `Toon`. Spell VFX stay unshaded by design
- [~] Audio: 3-layer spell sounds synthesised in `AudioBus` (element timbre, form attack, effect tail; impact boom), buses Music/SFX/UI created at runtime. Not listened to by a human yet. Music missing (needs CC0 assets)
- [!] Música: nenhum asset CC0 no repositório. Autorização para busca/download perguntada ao usuário em 2026-09-24; aguardando resposta.
- [ ] Screen transitions (ink brush)
- [~] Performance pass: `F8` no treino alterna carga sustentada de 20 zonas + 20 projéteis reais dos quatro elementos. Medido 2026-09-24, shader corrigido: 351–352 FPS sob carga (10 s), baseline 413–414 FPS (6 s), 1920×1080, Vulkan Forward+, AMD Radeon RX 580 2048SP, VSync off/sem limite. Contador/captura verificados; toggle limpa a carga. Logs/captura em `build/stress-final.log` e `build/stress.png`. Pendente teste prolongado e na GTX 1660-alvo a 144 FPS.
- [x] Windows export preset + build (user asked 2026-09-25): templates 4.7.2 installed (SHA-512 verified), `export_presets.cfg` "Windows Desktop" → `build/windows/DynMagic.exe` (106 MB, embedded pck). LAN verified with two exe instances. Release: `.github/workflows/release.yml` builds and publishes on tags `v*`
- [ ] Milestone review with user

## M7 — Arte final

- [x] User approved (2026-09-25): Blender 5.2.1 installed via winget; assets generated procedurally with Blender Python by Codex (no Tripo/paid services, no mcp-blender)
- [x] Mage character model (2026-09-25): 1.304 tris, 1,80 m, integrado no oponente
- [ ] Mage rig + animations (opcionais/fora da rodada 3)
- [x] First-person arms model + 4 poses (2026-09-25): 2.368 tris no total; wrapper seleciona uma pose
- [ ] First-person arms controller integration + cast animation 0,12 s + camada sem clipping
- [x] Arena props generated + exact-size cover dressing (2026-09-25): 7 props, colisões preservadas A/B/C
- [ ] Posicionar banner/brazier/spawn_arch nas arenas e revisar arte com o usuário
- [x] Arcane Core crystal + pedestal: 204 tris, integrado; só o cristal flutua/gira
- [x] Import checklist applied to all 10 assets (2026-09-25): escala/eixos/origem, budgets, toon por superfície, outline na galeria; raycasts físicos A/B/C e 73 testes passaram
- [ ] Milestone review with user

## M8 — Arte final 2: texturas, animação e som (user decisions 2026-09-25)

- [x] (Codex) Hand-painted textures baked from procedural Blender nodes for every asset (stone, cloth, wood, straw, metal, crystal); PNG ≤ 1024², UV unwrap in the generators; Godot toon shader samples the albedo texture
- [x] (Codex) Mage rig + animations: idle, walk, cast, dash, death; `AnimationPlayer` on the remote mage driven by velocity/composer/Stats
- [x] (Codex) First-person arms on the local camera (own render layer, no wall clipping), poses/animations driven by `SpellComposer` state
- [x] (Claude) Audio mix: CC0 packs for UI clicks, footsteps and impacts; improved synthesis for element spells (layers, reverb, random variation); music loop placeholder
- [ ] Milestone review with user

## M9 — Servidor dedicado (user decision 2026-09-25: LAN + VPS Linux)

- [x] (Claude) `--server` headless mode: hosts without a local player, accepts two clients, auto-starts the match when both are ready, returns everyone to the lobby after results, loops forever
- [x] (Claude) Linux x86_64 server export preset + CI artifact (`DynMagic-server-linux-x64.tar.gz`) with a systemd unit and README (ports UDP 7777/7778, firewall, `--port`, `--name`)
- [x] (Claude) Headless test: dedicated server + two bot clients play a full match, return to the lobby and auto-start the next one; LAN discovery finds the dedicated server
- [ ] Milestone review with user

## M10 — Alfa 1.0 (reviews 2026-09-25, see docs/reviews/SYNTHESIS.md)

Phase 1 — integrity
- [x] C1 enemy nameplate hidden behind walls; HP bars of both players on top of the HUD (D5)
- [x] C6 Overcharge decremented for remote players
- [x] C7 simultaneous death uses the tie rule (resolve at end of tick)
- [x] C8 loser rune window is not closed by side B's pick; fixed windows, early close only when both confirm (D4, 15 s in round 1)
- [x] C9 full round reset; no damage between phases; ready flags cleared when a match starts
- [x] C10 server validates cast targets, finite numbers, recast and lockout
- [x] C11 snapshots carry statuses/cooldowns/death; wall destruction is authoritative
- [x] C12 reconnect remaps the player on the remaining client; session token instead of name
- [x] C16 first pick drawn at match start
- [x] C17 cast_rejected feedback and local cooldown rollback

Phase 2 — readability
- [x] C2 damage_applied event (aggregated 100 ms): hitmarker, sound, numbers
- [x] C3 death / round / match banners with winner and reason; death card (D8, no replay; death cam = frozen last view for now)
- [x] C4 + D10 glossary: Raio, Leque, Prorrogação, Escolha, Round; no raw ids on screen; rune and element descriptions
- [x] C5 draft panel updated in place
- [x] C14 "Como jogar" screen, guided training, Tab 3×3 card
- [x] D6 wheel as Q-E-R arc with quick/confirm mark; D7 local cast flash (sound plays on spawn)

Phase 3 — server
- [x] C13 join by IP:port, show host IP, disconnect reason
- [x] C15 lean headless server (no HUD/anim/audio, fixed 60 Hz physics)
- [~] D13 `dynmagic@.service` template + 3 instances with MemoryMax/CPUQuota written; the 1 h load test still needs VPS access
- [!] Queue on the VPS (user 2026-09-25): 3 rooms per session with a waiting queue until the 4 GB upgrade; writes `/var/www/dynmagic/status.json` for the site — no VPS/network access this round
- [!] Website `web/` (brief `docs/briefs/website.md`), served by nginx at a second DuckDNS name — not started; no VPS access
- [x] D3 overtime default Colapso; Aleatório in lobby and `--overtime`/`--arena` server flags

Phase 4 — balance (user decisions D1, D2)
- [x] D1 Seta 3 charges (1 per 1.2 s); RMB recast only for confirmed spells
- [x] D2 element multipliers Fogo 1.05 / Gelo 0.95 / Raio 1.0 / Vento 0.95
- [x] D12 local telemetry JSON with lobby notice; remove headshot from spec (D9)
- [x] C18 docs aligned; release v1.0.0-alpha

## M11 — Antes da tag v1.0.0-alpha (1ª sessão de teste LAN, 2026-09-25)

Tag `v1.0.0-alpha` segurada até fechar este bloco. Revisão do trabalho DeepSeek (commit `def9b2a`) incluída.

Revisão DeepSeek (corrigir)
- [ ] Seta sem recarga entre cargas: 3 tiros saem em ~0,45 s (só o lockout de 0,15 s). Definir intervalo mínimo entre cargas
- [ ] HUD não mostra as cargas da Seta (grade de recarga fica sempre "pronta")
- [ ] Snapshot ~1,8 KB > MTU 1392 (blob `gameplay` via `put_var`): compactar antes de jogar na VPS
- [ ] Partida completa no servidor dedicado + escrita real da telemetria não verificadas (só teste unitário)

Feedback da sessão LAN
- [ ] Feedback de acerto (disparo que acerta) e de dano recebido mais forte: confirmar se o teste usou build com C2; reforçar som/flash/tremor
- [ ] Corpo a corpo (melee) — escopo a definir com o usuário
- [ ] "Preparar magias" — escopo a definir com o usuário
- [ ] Magias de Área parecem efeito de duração: diferenciar leitura visual de Área × Contínuo
- [ ] Diferenças entre magias mais claras (silhueta, cor, som por forma/efeito)
- [ ] Animações e projéteis melhores
- [ ] Música e efeitos sonoros melhores
