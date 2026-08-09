#!/bin/bash
# refresh_attention.sh: Launches node scripts in the background to refresh
# Slack and Teams unread count cache files. Fully detaches the processes
# so the calling shell (hs.execute) returns immediately.
set -euo pipefail

NODE_BIN="${NODE_BIN_PATH:-$(which node 2>/dev/null)}"
SCRIPT_DIR="${HAMMERSPOON_SCRIPT_DIR:-$HOME/.hammerspoon/scripts}"
LOG_FILE="/tmp/refresh_attention.log"

# Validate node is available
if [[ -z "$NODE_BIN" || ! -x "$NODE_BIN" ]]; then
    echo "$(date +%H:%M:%S) ERROR: node not found" >> "$LOG_FILE"
    exit 1
fi

# Close inherited stdout/stderr pipes immediately so hs.execute (popen)
# gets EOF and returns right away. Redirect stderr to a log file for debugging.
exec 1>/dev/null 2>>"$LOG_FILE"

# Launch node scripts in the background. They inherit /dev/null as stdin
# and write JSON to cache files. PIDs are tracked for cleanup.
"$NODE_BIN" "$SCRIPT_DIR/slack_unread.js" </dev/null >/tmp/slack_attention.json 2>>"$LOG_FILE" &
SLACK_PID=$!

"$NODE_BIN" "$SCRIPT_DIR/teams_unread.js" </dev/null >/tmp/teams_attention.json 2>>"$LOG_FILE" &
TEAMS_PID=$!

# Reap background processes to prevent zombies
wait "$SLACK_PID" "$TEAMS_PID" 2>/dev/null || true
