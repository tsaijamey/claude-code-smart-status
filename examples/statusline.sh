#!/bin/bash
# Claude Code statusline: 双行
#   行 1: [model] cwd | effort | tokens | cost | 5h-rate | sid
#   行 2: 📁 changed (N): file1, file2, ...  (本 session 编辑过的文件，由 hooks/statusline-files-tracker.sh 落盘)

input=$(cat)

# 提取字段
MODEL=$(echo "$input" | jq -r '.model.display_name // ""')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // ""')
SID=$(echo "$input" | jq -r '.session_id // ""')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

# current_usage 可能为 null（首次 API 调用前、/compact 后）
CU=$(echo "$input" | jq -c '.context_window.current_usage // {}')
USED=$(echo "$CU" | jq -r '((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) + (.output_tokens // 0))')

RATE5=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
RATE5_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# 千位分隔
fmt_num() { printf "%'d" "$1" 2>/dev/null || echo "$1"; }

# ===== Line 1 =====
LINE1="[$MODEL]"
[ -n "$CWD" ] && LINE1="$LINE1 DIR:<${CWD##*/}>"
[ -n "$EFFORT" ] && LINE1="$LINE1 | effort=$EFFORT"
LINE1="$LINE1 | $(fmt_num $USED)/$(fmt_num $SIZE) (${PCT}%)"
LINE1="$LINE1 | \$$(printf '%.2f' $COST)"

if [ -n "$RATE5" ]; then
  RATE_SEG="5h $(printf '%.0f' $RATE5)%"
  if [ -n "$RATE5_RESET" ]; then
    NOW=$(date +%s)
    REMAIN=$((RATE5_RESET - NOW))
    if [ "$REMAIN" -gt 0 ]; then
      RH=$((REMAIN / 3600))
      RM=$(((REMAIN % 3600) / 60))
      RATE_SEG="$RATE_SEG ↻ ${RH}h ${RM}m"
    fi
  fi
  LINE1="$LINE1 | $RATE_SEG"
fi

echo "$LINE1"

# ===== Line 2: session id =====
[ -n "$SID" ] && echo "sid=$SID"

# ===== Line 3: 本 session 改过的文件 =====
FILES_LOG="/tmp/claude-files-$SID.log"
if [ -f "$FILES_LOG" ]; then
  # awk 去重保序；取最近 5 个 basename
  UNIQUE=$(awk '!seen[$0]++' "$FILES_LOG")
  COUNT=$(echo "$UNIQUE" | sed '/^$/d' | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 0 ]; then
    NAMES=$(echo "$UNIQUE" | tail -5 | awk -F/ '{print $NF}' | paste -sd, - | sed 's/,/, /g')
    [ "$COUNT" -gt 5 ] && NAMES="…, $NAMES"
    echo "📁 changed ($COUNT): $NAMES"
  fi
fi
