#!/bin/bash
# Stop hook: 会话停下等待用户输入时响铃
# 后台异步播放，不阻塞 hook；setsid 切断会话避免被父进程组收割

BELL="/usr/share/sounds/freedesktop/stereo/bell.oga"

[ -f "$BELL" ] && command -v paplay >/dev/null 2>&1 && \
  setsid paplay "$BELL" >/dev/null 2>&1 < /dev/null &

exit 0
