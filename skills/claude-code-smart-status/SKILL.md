---
name: claude-code-smart-status
description: |
  This skill turns a Claude Code session into an ambient, glanceable workspace — making the otherwise quiet statusline and silent hooks emit rich per-session signals. Use it when the user wants to surface live session info in the statusline (cost USD, 5h/7d rate-limit usage with reset countdown, effort level, current model, cwd basename, list of files edited this session), play a completion bell when Claude finishes a turn (Stop hook), or persist per-session state via /tmp logs keyed by session_id (file-edit tracker via PostToolUse). Covers the official statusline JSON input contract, multi-line output, graceful degradation when fields are missing, session-scoped state files, async non-blocking sound playback, and the hard structural limit that statusline can only show "idle" state (it does not redraw mid-tool-call, so a live "running" indicator is not achievable — design UX around this fact). Trigger phrases: 'make claude code session ambient', 'smart claude code status', 'glanceable session info', 'extend statusline', 'customize Claude Code statusline', 'show cost in statusline', 'show modified files in statusline', 'add completion bell', 'Stop hook notification', 'PostToolUse file tracker', 'session bell', 'ambient session feedback', '会话智能感知', '环境状态反馈', 'Claude Code 状态智能化', '扩展 statusline', '加 statusline 字段', '会话停下响铃', 'Claude Code 完成提示音', '记录本会话修改的文件', '统计 session cost', '让 Claude Code 会话有存在感'.
---

## Overview

Claude Code exposes two quiet surfaces this skill turns into ambient session intelligence: the **statusline** (a shell script fed a rich JSON blob on stdin — model, workspace, cost, effort, rate_limits, tokens, session_id, transcript_path, output_style, etc. — whose stdout becomes the terminal bottom bar) and **hooks** (PostToolUse / Stop / SubagentStop / etc., which receive tool I/O and session metadata and can write side-effect files). Combining them gives the user a workspace that constantly broadcasts its own state: cost ticks up in view, files edited so far list themselves, rate-limit windows tick down, and a bell announces when the assistant is waiting on you — without breaking any existing hook wiring (frago-hook or otherwise).

## Key constraints to communicate up front

1. statusline only redraws when the assistant goes idle (and on /compact, mode change). It does NOT reliably refresh mid-tool-call even with `refreshInterval`. Live 'running' indicators are therefore not achievable — do not promise them.
2. Hooks run with limited TTY access. Cannot directly recolor the terminal tab from a hook in GNOME Terminal (no tab-color API). Bell + desktop notifications are the practical channels.
3. `session_id` is stable for the whole session and unique across sessions — use it as the cache/log key for any per-session state file under `/tmp`.
4. settings.json edits may be blocked by Claude Code's auto-mode classifier as 'self-modification'. Warn the user this may need manual authorization or a permission-mode switch before attempting.

## Steps

1. **Read current state.** Cat `~/.claude/settings.json` and note which `hooks.*` arrays and `statusLine.command` already exist. Identify a script path (usually `~/.claude/statusline.sh`) and any prior hook scripts under `~/.claude/hooks/`. Never overwrite an existing hook entry — append a new one to the matching event array.

2. **Confirm scope with the user.** Surface a menu of candidate additions drawn from the official statusline JSON contract: `cost.total_cost_usd`, `effort.level`, `rate_limits.five_hour.used_percentage` + `resets_at`, `cost.total_lines_added/removed`, `workspace.current_dir` (basename or full), `workspace.git_worktree`, `agent.name`, `output_style.name`, `model.display_name`, `exceeds_200k_tokens`. Recommend a sensible default subset and let the user trim.

3. **Write the statusline script.** Write a bash script at the chosen path that reads stdin with `cat`, extracts fields with `jq -r` using `// empty` defaults, and prints one or more lines. Every segment must be guarded with `[ -n "$VAR" ] && LINE="$LINE | ..."` so missing fields degrade gracefully instead of producing `... |  | ...`. For sid, prefer a separate line because UUIDs are long. For lists joined by multi-char separators, use `awk` or `sed` — `paste -sd ", "` treats the delimiter as a character set and produces wrong output.

4. **Optional: PostToolUse file tracker.** Write a tracker hook script that reads the tool-event JSON on stdin, filters on `tool_name` being one of Edit/Write/MultiEdit/NotebookEdit, extracts `tool_input.file_path`, and appends to `/tmp/claude-files-<session_id>.log`. The statusline then reads this log, dedupes (`awk '!seen[$0]++'`), takes the last N entries, prints basenames joined by `, `. Zero-parse cost beats scanning `transcript_path` on every redraw.

5. **Optional: Stop hook bell.** Write a Stop hook script that plays a sound asynchronously and non-blockingly: `setsid -f paplay /usr/share/sounds/freedesktop/stereo/bell.oga >/dev/null 2>&1 < /dev/null &`. Check available players (paplay, pw-play, aplay) and sound files first. Use Stop (not PostToolUse) — Stop fires once per assistant turn ending, PostToolUse fires per tool call and would be deafening. SubagentStop fires for subagent terminations — usually skip unless user explicitly wants per-subagent feedback.

6. **Register hooks in settings.json.** Append new entries to existing `hooks.PostToolUse[]` / `hooks.Stop[]` arrays. Each entry needs `matcher` (regex on tool names or empty), and `hooks: [{type: 'command', command: <absolute path>, timeout: 5}]`. Validate with `jq . settings.json` after editing. If the classifier blocks the edit, ask user to switch permission mode or apply the change manually with a clear before/after diff.

7. **chmod +x** every new script. Forgetting this produces silent failures in statusline (empty output) and hooks (no effect).

8. **Regression test with mock JSON.** Build a fixture JSON covering: (a) all fields present, (b) several fields missing, (c) edge values (>5 files, very long UUIDs, rate_limits.resets_at in the past). Pipe each into the statusline script and inspect output. For hooks, pipe a fake tool-event JSON and verify the side-effect file (`cat /tmp/claude-files-<sid>.log`).

9. **Clean up obsolete state.** If iterating (rewriting a script that previously wrote `/tmp/claude-state-*`), `rm -f` the stale state files so leftover content doesn't confuse the new logic.

10. **Report what user will see.** Describe the final layout line-by-line, note the bell will fire on the next assistant turn end, and explicitly call out the 'no running indicator' limitation if they asked for one.

## Reference files

Working drop-in versions of all three scripts and the settings snippet ship with this skill under `../../examples/`. Treat them as the canonical starting point — copy, then tailor field selection / sound / file count to the user's request.

- `../../examples/statusline.sh` — three-line statusline (model / DIR / effort / tokens / cost / 5h rate · sid · changed files)
- `../../examples/hooks/statusline-files-tracker.sh` — PostToolUse → `/tmp/claude-files-<sid>.log`
- `../../examples/hooks/claude-stop-bell.sh` — Stop → async `paplay` bell
- `../../examples/settings.snippet.json` — merge-into-existing fragment for `~/.claude/settings.json`
- `../../examples/README.md` — install steps, sample output, platform notes (Linux / macOS / WSL), conflict handling

## Common pitfalls

- Using `paste -sd ", " -` for comma-space joins (wrong: treats delimiter as charset). Use `awk 'NR>1{printf ", "} {printf $0}'` or `sed ':a;N;$!ba;s/\n/, /g'`.
- Forgetting `jq -r ... // empty` and ending up with literal `null` in statusline output.
- Writing to `~/.claude/hooks/frago/` or other reserved subdirs — keep custom hooks under `~/.claude/hooks/` directly.
- Running `paplay` in the foreground from a hook — blocks until sound finishes, freezes Claude Code. Always `setsid -f ... &` with stdin/stdout/stderr redirected.
- Adding `refreshInterval` thinking it will animate a running spinner. It won't — only useful for clock-like fields when idle and terminal has focus.
- Truncating session_id to last 6 chars to 'save space' — collides across sessions, breaks log lookup. Put full sid on its own line instead.


---

## About

Generated by **frago** — An Agent OS that turns ad-hoc agent runs into reusable recipes.

Install: `uv tool install frago-cli`
Homepage: https://frago.ai · Docs: https://docs.frago.ai
