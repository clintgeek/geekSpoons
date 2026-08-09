#!/bin/bash
# refresh_attention.sh: Launches node scripts in the background to refresh
# Slack and Teams unread count cache files. Fully detaches the processes
# so the calling shell (hs.execute) returns immediately.
NODE_BIN="${NODE_BIN_PATH:-$(which node 2>/dev/null)}"
SCRIPT_DIR="${HAMMERSPOON_SCRIPT_DIR:-$HOME/.hammerspoon/scripts}"

# Close inherited stdout/stderr pipes immediately so hs.execute (popen)
# gets EOF and returns right away, instead of waiting for background
# processes to finish.
exec 1>/dev/null 2>/dev/null

# Now launch node scripts in the background. They inherit /dev/null as
# stdout/stderr (not the popen pipe), so they're fully detached.
"$NODE_BIN" "$SCRIPT_DIR/slack_unread.js" </dev/null >/tmp/slack_attention.json 2>/dev/null &
"$NODE_BIN" "$SCRIPT_DIR/teams_unread.js" </dev/null >/tmp/teams_attention.json 2>/dev/null &
