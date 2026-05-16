#!/bin/bash
# PostToolUse hook: 把本 session 编辑过的文件追加到 /tmp/claude-files-<sid>.log
# statusline 读这个文件展示"本 session 改过的文件"，避免每次解析 transcript
input=$(cat)
TOOL=$(echo "$input" | jq -r '.tool_name // empty')
SID=$(echo "$input" | jq -r '.session_id // empty')
[ -z "$SID" ] && exit 0

case "$TOOL" in
  Edit|Write|MultiEdit)
    FILE=$(echo "$input" | jq -r '.tool_input.file_path // empty')
    ;;
  NotebookEdit)
    FILE=$(echo "$input" | jq -r '.tool_input.notebook_path // empty')
    ;;
  *)
    exit 0
    ;;
esac

[ -n "$FILE" ] && echo "$FILE" >> "/tmp/claude-files-$SID.log"
exit 0
