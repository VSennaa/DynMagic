# DynMagic — Handoff Notes for AI Agents

Last update: 2026-09-24. Written so any AI agent (Claude, Codex, Gemini, etc.) can continue work without the original conversation.

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
| Art | Shader-first (toon + outline + rune circles) with primitive placeholders. Blender + mcp-blender + Tripo only at milestone M7. Aesthetic: Bleach energy + Witch Hat Atelier rune magic, cartoon like Sea of Thieves |

## 4. Environment (user's Windows 11 machine)

| Item | Location / version |
|---|---|
| Project | `D:\DynMagic` (git initialized, no commits yet) |
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
- Input bindings use `keycode` (not `physical_keycode`). Revisit in M6 remapping if non-QWERTY layouts matter.

## 6. Status by milestone (SDD §6)

| Milestone | Status |
|---|---|
| Design (SDD + specs 01–08) | Done, decisions validated by user |
| M0 Setup | Done 2026-09-24: MCP verified, folder skeleton, 7 empty autoloads, 16 input actions, smoke suite 4/4 passing, first commit |
| M1 Sandbox | Not started |
| M2–M7 | Not started |

## 7. Next steps

Follow `docs/ROADMAP.md`: take the first unchecked task. Summary:

1. M1: `PlayerTuning.tres`, first-person `Player` scene (spec 05), `SpellComposer` state machine (spec 01 §1), `SpellDB.resolve()` + data resources, one element with all 9 spells, training dummy, greybox of Arena A.

## 8. Useful commands

```powershell
$g = "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
& $g --headless --path D:\DynMagic --import            # reimport / check script errors
& $g -e --path D:\DynMagic                              # open editor
& $g --path D:\DynMagic -- --host                       # run as host (after M3)
& $g --path D:\DynMagic -- --join 127.0.0.1             # run as client (after M3)
```

## 9. Rules for the next agent

- Update this file at the end of every work session: status table, next steps, any new decision.
- Record every new user decision in SDD §2 and in the relevant spec.
- Keep GDScript statically typed (untyped declarations are errors in `project.godot`).
- Commits are authorized (2026-09-24): commit after each finished roadmap task. Do not push (no remote yet), and do not install paid services without asking the user.
- Quota handoff: the user wants work handed to Codex CLI (skill `handoff-codex`) when the Claude 5-hour limit reaches 90%. Codex CLI 0.156.1 is installed at `C:\Users\vinic\AppData\Local\Programs\OpenAI\Codex\bin\codex.exe` (2026-09-24).
- Loop mode: the user runs `/loop Siga docs/ROADMAP.md (protocolo de loop no topo)`. Stop at milestone reviews.
