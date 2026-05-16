# Reference implementation

Battle-tested scripts and config — exactly what produced this skill. Drop them in, adjust paths, and you have the same setup running in one session.

## Files

| Path                                         | Purpose                                                                 |
| -------------------------------------------- | ----------------------------------------------------------------------- |
| `statusline.sh`                              | The statusline renderer. Three-line output: ambient session signals, full session id, and the list of files this session has edited. |
| `hooks/statusline-files-tracker.sh`          | PostToolUse hook. On every Edit/Write/MultiEdit/NotebookEdit, appends the touched `file_path` to `/tmp/claude-files-<session_id>.log`. Zero overhead on the statusline path. |
| `hooks/claude-stop-bell.sh`                  | Stop hook. Plays `freedesktop/stereo/bell.oga` asynchronously via `setsid paplay`, so the hook never blocks Claude Code. Fires once per assistant turn end (NOT per tool call). |
| `settings.snippet.json`                      | The minimum fragments to merge into `~/.claude/settings.json` — do NOT overwrite the whole file. |

## Install

```bash
# 1. Copy scripts to ~/.claude/
cp statusline.sh ~/.claude/
mkdir -p ~/.claude/hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/statusline.sh ~/.claude/hooks/statusline-files-tracker.sh ~/.claude/hooks/claude-stop-bell.sh

# 2. Merge settings.snippet.json into your ~/.claude/settings.json by hand.
#    Replace YOUR_USERNAME in all command paths with your actual home dir.
#    Hook 'command' fields require ABSOLUTE paths — Claude Code does not expand ~.

# 3. Validate
jq . ~/.claude/settings.json
```

The bell + statusline take effect on the **next** assistant message. The PostToolUse tracker starts logging on the next Edit/Write.

## Sample output

```
[Opus 4.7 (1M context)] DIR:<frago> | effort=xhigh | 72,244/1,000,000 (7%) | $2.40 | 5h 23% ↻ 0h 31m
sid=5787c4c1-53a7-4217-8d2a-411801901c9d
📁 changed (3): statusline.sh, claude-stop-bell.sh, settings.json
```

## Platform notes

- **Linux (Ubuntu/Debian)**: bell uses `paplay /usr/share/sounds/freedesktop/stereo/bell.oga`. Works out of the box on Ubuntu 24.04.
- **macOS**: replace the bell line in `claude-stop-bell.sh` with `afplay /System/Library/Sounds/Glass.aiff &` (no `setsid` needed; macOS `afplay` returns immediately when backgrounded).
- **WSL / no PulseAudio**: bell silently no-ops (the script checks `command -v paplay` and exits cleanly).

## Conflict with existing hooks

If your `~/.claude/settings.json` already has entries under `PostToolUse` / `Stop`, **append** new entries to the arrays — do not replace. Multiple hook entries on the same event all run; they do not conflict unless they touch the same files.

## What the statusline cannot show

There is no live "running" indicator (▶ during tool use). Claude Code only redraws the statusline when the assistant is idle, so any state file written by PreToolUse will be overwritten by Stop before you ever see it. The completion bell exists precisely to fill this gap — when you hear it, the statusline is current.
