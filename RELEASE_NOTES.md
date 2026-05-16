## What's in this release

First public release of `claude-code-smart-status` — a reference workflow and battle-tested scripts for turning Claude Code's quiet statusline and lifecycle hooks into an ambient session dashboard.

## Features

- **Three-line statusline renderer** showing model, working directory, effort level, token usage, cost, 5-hour rate-limit countdown, session id, and the list of files modified in the current session
- **PostToolUse file-tracking hook** that records every Edit/Write/MultiEdit/NotebookEdit target into `/tmp/claude-files-<session_id>.log` with zero parsing overhead at render time
- **Stop-event bell hook** that plays a non-blocking system sound when Claude finishes a turn, so the developer can context-switch without watching the terminal
- **Reference `examples/`** directory with ready-to-copy `statusline.sh`, two hook scripts, a `settings.snippet.json` showing exactly how to merge into `~/.claude/settings.json`, and a README covering Linux + macOS audio backends
- **10-step workflow** with field discovery, defensive `jq // empty` guards, shell-pitfall warnings (notably the `paste -sd` multi-char trap), and end-to-end fixture verification

## Known limitations

- Running-vs-idle indicators do not work reliably — statusline only repaints between assistant turns, so any "in-progress" icon stays frozen on "idle". The skill documents this and recommends the Stop-event bell as the practical alternative.
- Editing `~/.claude/settings.json` from inside a Claude Code session may be blocked by the auto-mode classifier; the user must adjust permission mode or apply the snippet manually.
- macOS users should swap `paplay` for `afplay` and the bell path for a `.aiff` under `/System/Library/Sounds/`.
