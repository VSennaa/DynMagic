---
name: handoff-codex
description: Delegate work when the Claude plan quota reaches 90%. Executor order is Codex (primary) then opencode/DeepSeek (fallback). Claude supervises and reports back when the executor finishes or runs out of quota. Use for /handoff-codex, "passa pro codex", or when the 5-hour limit is at or above 90%.
---

# Handoff (Claude supervises)

**Executor order: 1) Codex CLI (primary assistant) → 2) opencode + DeepSeek (fallback) → 3) Claude resumes after its quota resets.**
Claude stays as supervisor. Supervising is cheap: launch, wait, report.

## 1. Check quota
Call `mcp__ccd_session_mgmt__get_usage`. Read the "5-hour limit" window: `percentUsed` and `resetsAt`.
- Below 90% and not invoked by the user explicitly: stop and report the number.
- At or above 90%, or explicit user request: continue.

## 2. Write the handoff
Update `docs/HANDOFF.md` (project rule): current task, files touched, what is done, exact next steps, what not to touch, and `Active agent: <executor>`. Commit the current state first so the executor's changes can be reverted with `git`.

## 3. Run the executors in order (background, `run_in_background`)
The prompt for both:
> Read AGENTS.md and docs/HANDOFF.md, then continue the next steps listed there. Follow the project rules. Do not run git commit/push. Before stopping, update docs/HANDOFF.md with progress and set 'Active agent: none'.

**3a. Codex (primary).** Not on the Claude shell PATH; use the full path:
```powershell
& "C:\Users\vinic\AppData\Local\Programs\OpenAI\Codex\bin\codex.exe" exec -C D:\DynMagic -s workspace-write -o "$env:TEMP\codex-last.txt" "<prompt>"
```
Never use `--dangerously-bypass-approvals-and-sandbox`.

**3b. opencode + DeepSeek (fallback).** Use it when Codex fails, reports a usage/rate limit, or its reset time (in `docs/HANDOFF.md`) has not passed. No sandbox, so a clean commit beforehand is mandatory:
```powershell
Set-Location D:\DynMagic; opencode run -m deepseek/deepseek-flash "<prompt>"
```
(`deepseek/deepseek-v4-pro` is available for harder tasks.)

Do not edit project files while an executor runs. Do not poll; wait for the exit notification.

## 4. When the executor exits, take over and report
Read its output, `git status` and `git diff`. Classify the exit: **finished**, **quota exhausted** (usage/rate/quota message or stopped mid-task), or **other failure**.
1. Quota exhausted on Codex → start 3b. Quota exhausted on DeepSeek too → stop the chain.
2. Review the diff; run `--import` and the tests; fix only clear breakage.
3. Set `Active agent: Claude` in `docs/HANDOFF.md`, record what was done and what remains.
4. If work remains and Claude has not reset (call `get_usage`), do not burn the last of it: report and schedule a one-time task at `resetsAt` + 2 minutes via `mcp__scheduled-tasks__create_scheduled_task`.
5. If work remains and Claude has quota, continue it.

## 5. Report (in Portuguese)
Say which executor ran, how it ended (finished, quota out, failure), files changed, test result, what remains, and when Claude resumes if waiting for a reset.

## Trigger at 90%
This skill does not run by itself. For automatic triggering, schedule a recurring task (about every 10 minutes): "run /handoff-codex; if the 5-hour limit is below 90%, do nothing and say nothing". Each check costs a little quota.
