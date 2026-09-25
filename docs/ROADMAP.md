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
- [ ] Status effects: burn, slow, shock, knockback
- [ ] Element variants for Projectile row (spec 01 §3 table)
- [ ] Element variants for Self row
- [ ] Element variants for Area row
- [x] `test_spell_resolution.gd`: all 36 combinations vs expected table
- [ ] Rune circle shader + glyph per form + ring per effect (spec 01 §5, spec 07 §2)
- [ ] Placeholder VFX per element (GPUParticles3D)
- [ ] Training mode: pick element from a menu
- [ ] Milestone review with user

## M3 — Rede

- [ ] `Net` autoload: host/join by IP, ENet 7777, channels (spec 04 §1, §8)
- [ ] CLI args `--host` / `--join <ip>`
- [ ] Handshake + protocol version check (spec 04 §3)
- [ ] LAN discovery broadcast on 7778 + lobby list (spec 04 §2)
- [ ] `InputFrame` + `Snapshot` serialization + `test_net_serialization.gd`
- [ ] Client prediction + reconciliation (spec 04 §5)
- [ ] Remote player interpolation (100 ms buffer)
- [ ] Cast request/validation/spawn flow (spec 04 §6)
- [ ] Deterministic projectile simulation on both sides; host-only hit detection
- [ ] Lag compensation for Cone
- [ ] Network simulator (latency/jitter/loss) + F3 overlay
- [ ] Two local instances play 5 min without visible desync
- [ ] Milestone review with user

## M4 — Loop de partida

- [ ] `MatchState` FSM on host (spec 02 §2) + `test_match_fsm.gd`
- [ ] Side swap every round, spawn barriers during countdown
- [ ] Sequential draft: side A then side B, no duplicate element (spec 02 §3)
- [ ] Runes: 7 resources + loser pick of 3 random (spec 02 §3)
- [ ] Arcane Core: spawn at 30 s, capture rules, Overcharge (spec 02 §4)
- [ ] Overtime: Collapse (spec 02 §5)
- [ ] Overtime: Sudden Death
- [ ] Overtime: Mana Surge
- [ ] Overtime timeout + tie-break rules
- [ ] Decisive round at 3-3 (spec 02 §6)
- [ ] Disconnect pause 30 s + forfeit
- [ ] Match stats collection (spec 02 §7)
- [ ] Full best-of-7 LAN match end to end
- [ ] Milestone review with user

## M5 — Arenas

- [ ] `arena_base.tscn` with walls, side balconies, spawns, lighting (spec 03 §1, §5)
- [ ] `tools/build_arena.gd`: half-map table + 180° mirroring
- [ ] Arena A "Claustro"
- [ ] Arena B "Pátio Partido"
- [ ] Arena C "Espinha"
- [ ] `test_arena_symmetry.gd`: mirroring ≤ 1 mm + no spawn-to-spawn line of sight
- [ ] Arena selection (Fixed/Rotation/Random) in lobby
- [ ] Milestone review with user

## M6 — Polimento

- [ ] Main menu with animated 3D background (spec 06 §1)
- [ ] Host/Join screens + lobby screen
- [ ] Draft screen
- [ ] Final HUD (spec 06 §2)
- [ ] Pause menu + forfeit
- [ ] Results screen + rematch
- [ ] Grimório screen (36-spell reference)
- [ ] Settings screens + `user://settings.cfg` persistence (spec 06 §3)
- [ ] Input remapping with conflict detection
- [ ] Accessibility: colorblind palettes, reduce shake, sound captions
- [ ] Toon + outline shaders on everything (spec 07 §2)
- [ ] Audio: 3-layer spell sounds, menu and combat music
- [ ] Screen transitions (ink brush)
- [ ] Performance pass: 144 FPS target on GTX 1660 at 1080p
- [ ] Windows export preset + build
- [ ] Milestone review with user

## M7 — Arte final

- [!] Needs user approval: install Blender + mcp-blender, Tripo API key (paid)
- [ ] Mage character model + rig + animations
- [ ] First-person arms model + 4 poses + cast animation
- [ ] Arena props and cover dressing
- [ ] Import checklist applied to all assets (spec 07 §3)
- [ ] Milestone review with user
