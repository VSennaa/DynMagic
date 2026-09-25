# Spec 08 — Ferramentas e setup

## 1. Ambiente instalado (2026-09-24)

| Item | Versão | Local |
|---|---|---|
| Godot | 4.7.2 stable | `C:\Users\vinic\Downloads\Godot_v4.7.2-stable_win64.exe\` (pasta; fora do PATH) |
| Node.js | 24.20.0 | PATH |
| Python | 3.14.7 | PATH |
| uv / uvx | 0.12.19 | `pip install --user uv`; `...\Python314\Scripts` no PATH do usuário |
| Git | 2.55 | PATH |

## 2. MCP: Godot AI

- Projeto: https://github.com/hi-godot/godot-ai (MIT), plugin v4.2.3.
- Motivo da escolha: controla o editor ao vivo (cenas, nós, scripts, materiais, partículas, 46 tools). O Coding-Solo/godot-mcp só abre o projeto e lê o log.
- Instalado em `addons/godot_ai/` e habilitado em `project.godot`. O plugin adiciona o autoload `_mcp_game_helper`.
- O zip baixado era o bootstrap de migração v3→v4. O plugin v4 veio de `migration_payload/godot-ai-v4-plugin.zip`, com SHA-256 conferido contra o manifesto.
- Arquitetura: cliente MCP (stdio) → `godot-ai attach` → servidor Python (127.0.0.1:8000) → plugin no editor (WebSocket 127.0.0.1:9500).
- O editor precisa estar aberto para as tools funcionarem. O editor precisa enxergar `uvx` no PATH; se o servidor não subir, reabra o editor a partir de um shell novo.
- Registro do cliente: no dock "Godot AI" do editor, botão **Configure** ao lado do cliente (Claude Code, Codex etc.). Não escrever URL HTTP manualmente: não autentica.

## 3. Pendências do M0

Concluídas em 2026-09-24. Testes usam o runner do Godot AI (`McpTestSuite`, tool `test_run`); GUT não é usado. Toda suíte precisa de `@tool` na primeira linha.

## 4. Comandos

`$g` = `C:\Users\vinic\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`

| Objetivo | Comando |
|---|---|
| Abrir editor | `& $g -e --path D:\DynMagic` |
| Reimportar / checar erros | `& $g --headless --path D:\DynMagic --import` |
| Rodar o jogo | `& $g --path D:\DynMagic` |
| Rodar como host | `& $g --path D:\DynMagic -- --host` |
| Rodar como cliente | `& $g --path D:\DynMagic -- --join 127.0.0.1` |
| Testes | tool MCP `test_run` (editor aberto) |
| Exportar Windows | `& $g --headless --path D:\DynMagic --export-release "Windows Desktop" build/DynMagic.exe` |

## 5. Convenções de código

- GDScript com tipagem estática em tudo (`var hp: float`, `func f() -> void`).
- Declaração sem tipo gera erro (`gdscript/warnings/untyped_declaration=2` em `project.godot`).
- `snake_case` para arquivos e funções, `PascalCase` para `class_name`.
- Um script por nó que tem comportamento. Dados em `Resource`.
- Sinais para eventos locais. RPCs só nos autoloads `Net`/`MatchState` e no `NetSync` do jogador.

## 6. Testes mínimos

| Arquivo | Cobre |
|---|---|
| `tests/test_spell_resolution.gd` | As 36 combinações da spec 01 |
| `tests/test_spell_composer.gd` | Estados, modos rápida/confirmada, timeout, cancelamento, buffer |
| `tests/test_match_fsm.gd` | Todas as transições da spec 02 |
| `tests/test_arena_symmetry.gd` | Espelhamento e linha de visão da spec 03 |
| `tests/test_net_serialization.gd` | Empacotar e desempacotar InputFrame e Snapshot |

## 7. Critérios de aceite do M0

- [x] Godot 4.7.2 responde `--version`.
- [x] Import headless sem erro com o plugin habilitado.
- [x] Servidor Godot AI escuta em 8000 e 9500 com o editor aberto.
- [x] Claude Code lista o servidor MCP do Godot AI como conectado (verificado com `editor_state`).
- [x] Suíte de testes roda pelo `test_run` com 0 falhas.
