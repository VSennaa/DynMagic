---
name: handoff-codex
description: Delegate work to Codex CLI when the Claude plan quota reaches 90%, supervise it from this session, and report back when Codex finishes or runs out of quota. Use for /handoff-codex, "passa pro codex", or when the 5-hour limit is at or above 90%.
---

# Handoff to Codex (Claude supervises)

Claude stays as the supervisor and Codex does the work. Supervising is cheap: launch, wait, report.

## 1. Check quota
Call `mcp__ccd_session_mgmt__get_usage`. Read the "5-hour limit" window: `percentUsed` and `resetsAt`.
- Below 90% and not invoked by the user explicitly: stop and report the number.
- At or above 90%, or explicit user request: continue.

## 2. Write the handoff
Update `docs/HANDOFF.md` (project rule): current task, files touched, what is done, exact next steps, what not to touch, and `Active agent: Codex`. Commit nothing unless the user asked.

## 3. Run Codex in the background
Codex CLI is not on the Claude shell PATH; use the full path. Run with `run_in_background` so this session is re-invoked when it exits:

```powershell
& "C:\Users\vinic\AppData\Local\Programs\OpenAI\Codex\bin\codex.exe" exec -C D:\DynMagic -s workspace-write -o "$env:TEMP\codex-last.txt" "Read AGENTS.md and docs/HANDOFF.md, then continue the next steps listed there. Follow the project rules. Before stopping, update docs/HANDOFF.md with progress and set 'Active agent: none'."
```

Never use `--dangerously-bypass-approvals-and-sandbox`. Do not edit project files while Codex runs. Do not poll; wait for the exit notification.

## 4. When Codex exits, take over and report
Read `$env:TEMP\codex-last.txt`, the command output, `git status` and `git diff`. Classify the exit:
- **Finished**: Codex says the steps are done.
- **Codex quota exhausted**: output mentions usage/rate/quota limit, or it stopped mid-task with an error.
- **Other failure**: crash, auth error, sandbox denial.

Then:
1. Review the diff for problems and fix only clear breakage.
2. Set `Active agent: Claude` in `docs/HANDOFF.md` and record what Codex did and what remains.
3. If work remains and the Claude quota has not reset (call `get_usage` again), do not burn the last of it: report and, if useful, schedule a one-time task at `resetsAt` + 2 minutes via `mcp__scheduled-tasks__create_scheduled_task` to resume.
4. If work remains and Claude has quota, continue it.

## 5. Report (in Portuguese)
Say which case happened (finished, Codex quota out, or failure), what changed (files), what remains, and when Claude can resume if it is waiting for a reset.

## Trigger at 90%
This skill does not run by itself. For automatic triggering, schedule a recurring task (about every 10 minutes) with the prompt "run /handoff-codex; if the 5-hour limit is below 90%, do nothing and say nothing". Each check costs a little quota.
