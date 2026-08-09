# THE POLISH

A living document of rough code, fragile patterns, technical debt, and things that need attention. Updated as issues are found and resolved.

---

## Critical

### Hardcoded paths with username (PARTIALLY FIXED)
- `apps.lua` - Messages and ChatGPT app paths now use `os.getenv()` with `HOME` fallback
- `scripts/refresh_attention.sh` - Node path and script dir now use env vars with `which node` fallback
- `providers/outlook.lua` lines 20-21 - Container ID path is still hardcoded to user's sandbox. Needs env var or dynamic lookup.

### Command injection risk
- `apps.lua` line 78 - `hs.execute('open "' .. config.path .. '"')` - no escaping of path. If path contains quotes, breaks.
- `providers/outlook.lua` lines 24, 37-40 - Shell commands with path concatenation, no escaping.

---

## Fragile Code

### ICS parser (`scripts/calendar_ics.js`)
- Manual ICS parsing with string patterns (lines 40-76). Doesn't handle all ICS edge cases (line folding with CRLF, escaped characters, nested components).
- Manual datetime parsing (lines 79-98). Reinventing what `ical.js` or `luxon` already do.
- Custom recurrence expansion (lines 116-154). Only handles FREQ=DAILY/WEEKLY/MONTHLY/YEARLY with INTERVAL. Missing: EXDATE, RDATE, BYDAY, BYMONTH, BYHOUR, BYSETPOS, COUNT interaction with UNTIL.
- Hardcoded timezone `America/Chicago` (line 7). Should be configurable or auto-detect.

### Shell command output parsing
- `init.lua` line 86 - `lsof | grep | wc | tr` pipeline for checking Slack debug port. Fragile if output format changes.
- `camera.lua` lines 19, 24 - `ioreg` output parsed with string patterns. macOS version dependent.
- `providers/outlook.lua` lines 46, 53, 61, 67 - `stat` and `gunzip` output parsed with patterns. Platform specific.

### DOM scraping for unread counts
- `scripts/slack_unread.js` lines 25-51 - Relies on specific CSS class names in Slack's DOM. Breaks when Slack updates their UI.
- `scripts/teams_unread.js` lines 64-104 - Same issue with Teams DOM structure.
- `providers/messages.lua` line 23 - Injects JavaScript into Chrome to scrape Messages DOM.

### Missing error handling
- `attention.lua` lines 26-30, 54-55 - File I/O to `/tmp/attention_debug.log` with no error handling.
- `attention.lua` line 72 - `hs.json.decode` with no pcall. Malformed JSON crashes silently.
- `calendar.lua` line 30 - Same: `hs.json.decode` without pcall.
- `scripts/refresh_attention.sh` lines 15-16 - No error checking if node scripts exist or execute successfully.

---

## Dead Code

- `init.lua` lines 57-58 - Commented-out `messagesProvider.start()`. Remove or document why disabled.
- `apps.lua` line 42 - Checks `config.url` but no app in config has this property. Unreachable code path.
- `screenshot.lua` lines 17-21 - `saveToFile()` function appears to duplicate `copyToClipboard()`.

---

## Inconsistencies

### Naming
- `init.lua` - `configFileWatcher` (global) vs `_slackRelaunchTimer` (underscore prefix) vs `_t0` (terse). Pick one convention.
- `apps.lua` line 42 - Checks `config.url` but config uses `appUrl` (line 13).

### Error handling patterns
- `server.lua` - `/api/status` now wraps providers in `pcall` (good), but other endpoints don't.
- `providers/slack.lua` vs `providers/teams.lua` - Slack falls back to `root-state.json`, Teams falls back to dock badge. No shared strategy.

### Duplicated logic
- `index.html` - Mic state update logic appears 3 times: `triggerAction()`, `updateStatus()`, and `applyMicState()`. Extract to single function.
- `apps.lua` lines 117-130, 138-162 - Two polling loops with nearly identical structure. Extract to shared function.

---

## Performance

- `init.lua` line 86 - Synchronous `hs.execute("lsof ...")` blocks main thread during Slack debug port check. Use `hs.task` for async.
- `camera.lua` line 19 - Synchronous `hs.execute` for `ioreg`. Blocks main thread.
- `providers/outlook.lua` lines 24, 37-40, 46, 53 - Multiple sequential synchronous shell commands. Each blocks.
- `index.html` line 1647 - Fetches album artwork from iTunes API on every track change. No caching, could hit rate limits.
- `init.lua` lines 103-104, 112-121 - Multiple overlapping timers (60s attention refresh + 3s/10s/18s/22s app-specific). Could consolidate.

---

## Code Smells

### Long functions
- `apps.lua` lines 37-164 - `smartLaunch()` is 128 lines. Break into `launchApp()`, `waitForFocus()`, `relaunchIfNeeded()`.
- `providers/outlook.lua` lines 13-93 - `getAttention()` is 81 lines. Separate shell execution from XML parsing.
- `providers/teams.lua` lines 10-90 - `getAttention()` is 81 lines. Extract AXUIElement traversal.
- `index.html` lines 1754-1867 - `updateStatus()` is 114 lines. Break into per-component update functions.
- `server.lua` lines 81-2232 - 2151-line inline HTML string. Should be in a separate `.html` file loaded at runtime.

### Magic numbers
- `init.lua` lines 112-121 - Timer intervals (3, 10, 18, 22 seconds) with no explanation.
- `audio.lua` lines 42, 53 - Volume increment of 5. Should be constant.
- `mute.lua` lines 72, 95 - Default volume 73. Why 73?
- `screenshot.lua` line 9 - 200000 (200ms in microseconds). Should be named.
- `scripts/slack_unread.js` line 76 - 3-second timeout.
- `scripts/teams_unread.js` line 129 - 5-second timeout.

### Inline styles in HTML
- `index.html` line 1551 - `style="font-size:20px"` should be a CSS class.
- `index.html` lines 1825, 1826 - Inline styles for status dot.

---

## Lua-Specific

### Global variable leaks
- `init.lua` line 15 - `configFileWatcher` should be `local`.
- `init.lua` lines 94-121 - `_slackRelaunching`, `_slackRelaunchTimer`, `_t0`, `_t1`, `_t1b`, `_t2`, `_attentionRefreshTimer`, `_appWatcher` - all globals. Encapsulate in a table or declare `local`.
- `mute.lua` lines 7-8 - `muteCanvas`, `savedInputVolume` should be `local` to module.

### Missing `local` declarations
- `apps.lua` line 82 - `app` not declared local.
- `browser.lua` line 7 - `domain` not declared local.
- `attention.lua` line 14 - `newState` not declared local.
- Various loop variables in providers not declared local.

---

## Shell Scripts

### `scripts/refresh_attention.sh`
- Missing `set -e` and `set -u` - doesn't exit on error or catch undefined vars.
- `exec 1>/dev/null 2>/dev/null` (line 11) - Silences all output, makes debugging impossible. Consider logging to a file.
- Backgrounded processes (lines 15-16) - No PID tracking, could orphan.

---

## Missing Features / Incomplete

- `init.lua` lines 57-58 - `messagesProvider.start()` commented out. Why? Document or remove.
- `providers/messages.lua` lines 1-8 - Comment mentions Chrome PWA requirement but no validation.
- `scripts/calendar_ics.js` - Recurrence expansion doesn't handle EXDATE, RDATE, BYDAY, BYMONTH, BYSETPOS.
- `index.html` - No error states shown to user when API calls fail. Just console.log.

---

## Resolved

- [x] Calendar ICS URL extracted to `CALENDAR_ICS_URL` env var
- [x] Weather location extracted to `WEATHER_LOCATION` env var
- [x] App paths in `apps.lua` use `HOME` env var fallback
- [x] `refresh_attention.sh` uses `which node` fallback and `$HOME`
- [x] `.env` / `.env.example` / `.gitignore` created
- [x] `env.lua` loader module created
- [x] Calendar timezone parsing fixed (Pacific/Eastern → Central)
- [x] Weather tile uses Unsplash background images
- [x] Calendar and Weather tiles side-by-side below capture buttons
