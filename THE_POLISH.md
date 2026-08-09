# THE POLISH

A living document of rough code, fragile patterns, technical debt, and things that need attention. Updated as issues are found and resolved.

---

## Critical

*(All resolved - see Resolved section)*

---

## Fragile Code

### ICS parser (`scripts/calendar_ics.js`)
*(Resolved - see Resolved section. Now uses node-ical library.)*

### Shell command output parsing
- `init.lua` line 88 - `lsof` output checked with `:match("LISTEN")`. Stable on macOS, not a real concern.
- ~~`camera.lua` lines 19, 24 - `ioreg` output parsed with string patterns.~~ **RESOLVED**: Replaced with `hs.camera` module API. No more shell parsing.

### DOM scraping for unread counts
- `scripts/slack_unread.js` lines 25-51 - Relies on specific CSS class names in Slack's DOM. Breaks when Slack updates their UI.
- `scripts/teams_unread.js` lines 64-104 - Same issue with Teams DOM structure.
- `providers/messages.lua` line 23 - Injects JavaScript into Chrome to scrape Messages DOM.

### Missing error handling
*(All resolved - see Resolved section)*

---

## Dead Code

*(All resolved - see Resolved section)*

---

## Inconsistencies

### Naming
*(Resolved - see Resolved section)*

### Error handling patterns
- `server.lua` - `/api/status` now wraps providers in `pcall` (good), but other endpoints don't.
- `providers/slack.lua` vs `providers/teams.lua` - Slack falls back to `root-state.json`, Teams falls back to dock badge. Different by design (different apps expose different data sources).

### Duplicated logic
*(Resolved - see Resolved section)*

---

## Performance

*(All resolved or by design - see Resolved section)*

---

## Code Smells

### Long functions
*(All resolved - see Resolved section)*

### Magic numbers
*(All resolved - see Resolved section)*

### Inline styles in HTML
*(All resolved - see Resolved section)*

---

## Lua-Specific

### Global variable leaks
*(All resolved - see Resolved section)*

### Missing `local` declarations
*(All resolved - see Resolved section)*

---

## Shell Scripts

### `scripts/refresh_attention.sh`
*(All resolved - see Resolved section)*

---

## Missing Features / Incomplete

- ~~`init.lua` lines 57-58 - `messagesProvider.start()` commented out.~~ **RESOLVED**: Removed.
- `providers/messages.lua` lines 1-8 - Comment mentions Chrome PWA requirement but no validation.
- ~~`scripts/calendar_ics.js` - Recurrence expansion doesn't handle EXDATE, RDATE, BYDAY, BYMONTH, BYSETPOS.~~ **RESOLVED**: node-ical handles all of these.
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
- [x] Dead code: removed commented-out `messagesProvider.start()` from init.lua
- [x] Dead code: removed unreachable `config.url` code path from apps.lua
- [x] Dead code: removed duplicate `saveToFile()` from screenshot.lua
- [x] Inconsistency: all init.lua globals (`configFileWatcher`, `_slackRelaunching`, `_t0`, etc.) converted to `local` with consistent naming
- [x] Inconsistency: removed `_teamsRelaunching` bug (was never set, would cause runtime error)
- [x] Inconsistency: extracted duplicated mic/audio state logic in index.html to `applyMicState()` and `applyAudioMuteState()` functions
- [x] Inconsistency: `config.url` vs `config.appUrl` resolved by removing dead `config.url` path
- [x] Lua: all `init.lua` globals converted to `local` with consistent naming
- [x] Lua: `attention.lua` `_attentionInitialTimer` global converted to `local`
- [x] Lua: `apps.lua` loop variable `app` renamed to `runningApp` to avoid shadowing outer `app`
- [x] Lua: audit confirmed `mute.lua`, `browser.lua`, `attention.lua` vars were already `local` (false positives)
- [x] Shell: `refresh_attention.sh` now uses `set -euo pipefail`
- [x] Shell: `refresh_attention.sh` stderr redirected to `/tmp/refresh_attention.log` instead of `/dev/null`
- [x] Shell: `refresh_attention.sh` validates node binary exists before running
- [x] Shell: `refresh_attention.sh` tracks PIDs and reaps background processes with `wait`
- [x] Critical: `providers/outlook.lua` OSA path now uses `OUTLOOK_OSA_PATH` env var with standard fallback (UBF8T346G9 is Microsoft's shared Office container, same for all installs)
- [x] Critical: `apps.lua` `hs.execute('open ...')` now uses `shellEscape()` to prevent command injection
- [x] Critical: `providers/outlook.lua` all shell commands now use `shellEscape()` for path interpolation
- [x] ICS parser: replaced 235-line manual parser with `node-ical` library (100 lines total). Handles RRULE, EXDATE, RECURRENCE-ID, DST, timezone-aware DTSTART natively.
- [x] Camera: replaced `ioreg` shell parsing with `hs.camera` module API. No more fragile string pattern matching on IOKit registry output.
- [x] Camera: no longer dumps entire IOKit registry (`ioreg -l`); uses native API that queries only camera devices.
- [x] Error handling: `attention.lua` `hs.json.decode` wrapped in pcall (malformed JSON no longer crashes)
- [x] Error handling: `calendar.lua` `hs.json.decode` wrapped in pcall
- [x] Error handling: `refresh_attention.sh` already has `set -euo pipefail` and node validation from earlier fix
- [x] Magic numbers: `init.lua` timer intervals extracted to named constants with explanatory comments
- [x] Magic numbers: `audio.lua` volume step extracted to `VOLUME_STEP` constant
- [x] Magic numbers: `mute.lua` default volume (73) and HUD duration (2.0s) extracted to named constants
- [x] Magic numbers: `screenshot.lua` delays extracted to `KEYSTROKE_DELAY` and `WINDOW_MODE_DELAY` constants
- [x] Magic numbers: `slack_unread.js` timeout extracted to `TIMEOUT_MS` constant
- [x] Magic numbers: `teams_unread.js` timeout extracted to `TIMEOUT_MS` constant
- [x] Inline styles: `index.html` icon font-size moved to `.app-icon-lg i` CSS class
- [x] Inline styles: `index.html` status dot idle state moved to `.status-dot.idle` CSS class
- [x] Long function: `apps.lua` `smartLaunch()` broken into `findMainWindow()`, `waitForWindow()`, `reopenApp()`, `launchApp()`
- [x] Long function: `providers/outlook.lua` `getAttention()` broken into `parseInboxUnread()`, `findGetFolderFile()`, `isFileFresh()`, `readGzipFile()`
- [x] Long function: `providers/teams.lua` `getAttention()` broken into `buildResult()`, `readCache()`, `readDockBadge()`
- [x] Long function: `index.html` `updateStatus()` broken into `updateCamera()`, `updateAudio()`, `updateSpotify()`
- [x] Long function: `server.lua` removed 2162 lines of dead commented-out inline HTML (already loaded from `index.html` on disk)
- [x] Performance: `providers/outlook.lua` replaced `stat` shell command with `lfs.attributes` (Lua filesystem) — one fewer blocking call per session
- [x] Performance: `index.html` added in-memory `artworkCache` for iTunes artwork — repeated tracks no longer refetch from iTunes API
- [x] Performance: `init.lua` app-launch timers are sequential by design (3s→10s→18s→22s settling sequence), not redundant. No consolidation needed.
- [x] Performance: `init.lua` `lsof` port check is ~10ms and only runs on Slack launch — not a hot path
