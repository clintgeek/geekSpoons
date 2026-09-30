# GeekSpoons Manual

A thorough guide to installing, configuring, and operating the GeekSpoons Hammerspoon Workstation Controller.

---

## Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Features & How-Tos](#features--how-tos)
6. [Keyboard Hotkeys](#keyboard-hotkeys)
7. [Web Interface](#web-interface)
8. [HTTP API Reference](#http-api-reference)
9. [Architecture](#architecture)
10. [Attention Providers](#attention-providers)
11. [Background Scripts](#background-scripts)
12. [Troubleshooting](#troubleshooting)
13. [File Reference](#file-reference)

---

## Overview

GeekSpoons is a Hammerspoon configuration that transforms a tablet (or any browser) into a customizable control surface for your Mac. It runs an embedded HTTP server on port 8080 that serves a single-page web app with touch-friendly controls for:

- Microphone mute and push-to-talk
- Camera toggle (auto-detects the active meeting app)
- System audio device switching and volume control
- Screen capture and recording
- Spotify playback control
- App launching with smart focus
- Live unread/attention indicators for Slack, Teams, Outlook, and Google Messages
- Calendar "next up" with meeting join links
- Weather conditions

The system is designed for a single user on a local network. The Mac runs Hammerspoon with this config; the tablet connects over Wi-Fi to the Mac's IP on port 8080.

---

## Requirements

### Essential

- **macOS** (tested on macOS 14 Sonoma and later)
- **[Hammerspoon](https://www.hammerspoon.org/)** — install from the website or via Homebrew: `brew install --cask hammerspoon`
- **[Node.js](https://nodejs.org/)** — required for Slack/Teams unread count scripts and calendar ICS parsing. Any recent LTS version works (18+).

### Applications (optional but recommended)

- **Spotify** — for music control
- **Slack** — for unread counts (requires debug port setup, handled automatically)
- **Microsoft Teams** — for unread counts (requires debug port, set automatically via launchctl)
- **Microsoft Outlook** — for inbox unread counts (reads OSA sync logs)
- **Google Chrome** — for Google Messages unread count (requires "Allow JavaScript from Apple Events" enabled)
- **Google Messages PWA** (or any Chrome tab on messages.google.com)

### Tablet/Browser

- Any modern browser with JavaScript enabled
- For PWA fullscreen mode: Chrome, Safari, or Edge on iPad/Android tablet
- Connected to the same local network as the Mac

---

## Installation

### Step 1: Install Hammerspoon

Download from [hammerspoon.org](https://www.hammerspoon.org/) or:

```bash
brew install --cask hammerspoon
```

Launch Hammerspoon and grant it the Accessibility and Automation permissions it requests in System Settings > Privacy & Security.

### Step 2: Clone the config

```bash
cd ~/.hammerspoon
git init
git remote add origin <your-repo-url>
git pull origin main
```

Or simply copy the files into `~/.hammerspoon/`.

### Step 3: Install Node.js dependencies

```bash
cd ~/.hammerspoon/scripts
npm install
```

This installs `node-ical`, `luxon`, and `ws` (WebSocket client) used by the background scripts.

### Step 4: Configure environment

```bash
cd ~/.hammerspoon
cp .env.example .env
```

Edit `.env` with your values (see [Configuration](#configuration) below).

### Step 5: Reload Hammerspoon

Click the Hammerspoon menu bar icon and select "Reload Config", or press **Cmd+Alt+Ctrl+Shift+R**.

### Step 6: Open the web interface

On your Mac, open `http://localhost:8080`. On your tablet, open `http://<your-mac-ip>:8080` (find your Mac's IP in System Settings > Network).

### Step 7 (Optional): Install as PWA on tablet

In Safari/Chrome on your tablet, open the URL, tap Share, then "Add to Home Screen". Launch from the home screen icon for fullscreen, chromeless access.

---

## Configuration

All configuration is done through a `.env` file in `~/.hammerspoon/`. Copy `.env.example` to `.env` and edit:

### Required

| Variable | Description | Example |
|---|---|---|
| `CALENDAR_ICS_URL` | ICS feed URL for your calendar (Outlook: Settings > Calendar > Publish a calendar) | `https://outlook.office365.com/owa/calendar/.../calendar.ics` |
| `WEATHER_LOCATION` | City, state for weather (used with wttr.in) | `Arkadelphia, AR` |

### Optional

| Variable | Description | Default |
|---|---|---|
| `MESSAGES_APP_PATH` | Path to Google Messages PWA | `~/Applications/Chrome Apps.localized/Messages.app` |
| `CHATGPT_APP_PATH` | Path to ChatGPT app | `~/Applications/Edge Apps.localized/ChatGPT.app` |
| `OUTLOOK_OSA_PATH` | Path to Outlook OSA sync logs | `~/Library/Group Containers/UBF8T346G9.Office/Outlook/.../Osa` |
| `NODE_BIN_PATH` | Path to node binary | `$(which node)` |
| `HAMMERSPOON_SCRIPT_DIR` | Path to scripts directory | `~/.hammerspoon/scripts` |

### Chrome JavaScript from Apple Events

For Google Messages unread counts, Chrome must have this enabled:

1. Open Google Chrome
2. Go to **View > Developer > Allow JavaScript from Apple Events**
3. Ensure it's checked

Without this, the Messages provider will show "enable JS in Chrome" instead of unread counts.

---

## Features & How-Tos

### Microphone Control

- **Mic Mute Toggle**: Tap the mic button. Mutes system input devices and toggles the active meeting app's in-call mute (Google Meet, Teams, Zoom, Slack, Webex). The button turns red and shows "MIC MUTED". A HUD overlay appears on your Mac screen confirming the state.
- **Push to Talk**: Press and hold the "PUSH TO TALK" button. While held, your mic is unmuted both at the system level and in the active meeting app (Google Meet, Teams). Release to re-mute. Works on touch (tap and hold) and mouse.
- **How it works**: Uses CoreAudio hardware muting plus input volume as a soft mute backup. For Google Meet, interacts directly with the Meet call tab via Chrome JXA without needing focus.

### Camera Toggle

- Tap the camera button to toggle your camera in the active meeting app.
- Auto-detects which meeting app is running:
  - **Google Meet (Chrome)**: Directly toggles camera in the active Meet tab via Chrome JXA without stealing window focus
  - **Teams**: Cmd+Shift+O
  - **Zoom**: Cmd+Shift+V
  - **Slack Huddles**: Cmd+Shift+V
  - **Webex**: Cmd+Shift+V
- The button shows "CAM ACTIVE" (green) when your camera is in use, or "CAMERA" (neutral) when idle. Camera status is polled every 2 seconds using the native `hs.camera` API.

### Audio Device Management

- **Cycle Output**: Tap the speaker button to cycle through available output devices. Automatically pairs the matching input device (e.g., switching to AirPods sets both output and input to AirPods).
- **Mute Sound**: Tap the mute button to mute/unmute system audio output.
- **Volume**: Tap Vol+ or Vol- to adjust output volume in 5% increments.

### Screen Capture

- **Screenshot Selection**: Tap to trigger macOS screenshot selection (Cmd+Shift+4). The screenshot goes to your clipboard with a floating thumbnail for markup.
- **Record Screen**: Tap to open the macOS screen recording toolbar (Cmd+Shift+5). Select recording mode from the toolbar.

### Spotify Control

- **Play/Pause**: Tap the large circular button
- **Next/Previous**: Tap the skip buttons
- **Shuffle/Repeat**: Toggle buttons light up green when active
- **Like**: Heart button saves the current track to your library
- **Playlist Chooser**: Tap the track info area to open a playlist modal where you can select and play any playlist
- **Open Spotify**: Tap the Spotify icon button to launch/focus the Spotify app
- **Album Artwork**: Automatically fetched from the iTunes API and displayed as a blurred background behind the track info. Artwork is cached in-memory so repeated tracks don't refetch.
- **Progress Bar**: Shows current position and total duration, updated every second

### App Launcher

The bottom-right grid shows app icons. Tap to launch or focus the app:

- **Chrome, Teams, Slack, Outlook, Firefox**: Standard apps launched from `/Applications/`
- **Messages, ChatGPT**: PWA apps launched from `~/Applications/` (paths configurable via env vars)

Smart launch behavior:
- If the app is already running with a window, it just focuses the existing window
- If the app is running but has no windows (e.g., closed all windows), it reopens and maximizes
- If the app is not running, it launches fresh and maximizes the window when it appears

### Calendar (Next Up)

- Shows the title, time, and duration of your next meeting (or current meeting if one is in progress)
- Time remaining is color-coded:
  - **Red** (< 1 hour): "in 45 min"
  - **Yellow** (1-2 hours): "in 1 hr 23 min"
  - **Yellow** (2-24 hours): "in 5 hours"
  - **Grey** (> 24 hours): "in 3 days"
- All-day events never appear on the tile — they would otherwise show as "NOW" for 24 hours and mask real meetings.
- Tap the tile to open the schedule modal, which lists all of today's events (all-day entries shown as "All day", past entries dimmed) plus the next 5 upcoming events.
- Calendar data is fetched from your ICS feed every 60 seconds using `node-ical` for full recurrence support (RRULE, EXDATE, RDATE, BYDAY, etc.)

### Weather

- Shows current temperature, condition, feels-like, humidity, and rain chance
- Background image changes based on weather condition (sunny, cloudy, rainy, snow, fog, partly cloudy) using Unsplash photos
- Refreshes every 10 minutes from [wttr.in](https://wttr.in)

### Attention Indicators

Each app launcher tile shows an attention badge when there are unread items:

- **Slack**: Channel unread count (amber) and DM count (red). DMs are marked urgent.
- **Teams**: People/DMs (red, urgent), meetings (amber), channels (amber)
- **Outlook**: Inbox unread count (amber)
- **Google Messages**: Unread conversation count (amber)

The app tiles glow with colored borders:
- **Amber border**: has unread items (attention level)
- **Red border**: has urgent items (DMs/mentions)
- **Dashed grey border**: app not running or unreadable
- **Green border**: app is loading

---

## Keyboard Hotkeys

For when you don't have the tablet handy, these global hotkeys work from anywhere on your Mac:

| Hotkey | Action |
|---|---|
| **Cmd+Alt+Ctrl+Shift+R** | Reload Hammerspoon config |
| **Cmd+Alt+Ctrl+Shift+M** | Toggle mic mute |
| **Cmd+Alt+Ctrl+Shift+Space** | Spotify play/pause |
| **Cmd+Alt+Ctrl+Shift+S** | 50/50 window split (focused window left, next window right) |

The "Hyper Key" is Cmd+Alt+Ctrl+Shift. If you use a keyboard with a Hyper key remap (e.g., via Karabiner-Elements), these become single-key shortcuts.

---

## Web Interface

The web app is served at `http://<mac-ip>:8080` and is designed for landscape tablet use.

### Polling

The interface uses two polling cycles:

- **Fast poll (1s)**: Mic, camera, audio, Spotify — values that change in real time
- **Slow poll (10s)**: Attention indicators, calendar, weather — values that change slowly

This reduces unnecessary processing while keeping real-time controls responsive.

### Connection Status

If the server becomes unreachable, a red "CONNECTION LOST — RETRYING" banner appears at the top of the screen after 3 consecutive failed polls. It disappears automatically when the connection is restored.

### PWA Installation

For fullscreen tablet use:

1. Open `http://<mac-ip>:8080` in Safari or Chrome on your tablet
2. Tap the Share button
3. Select "Add to Home Screen"
4. Launch from the home screen icon — it runs fullscreen with no browser chrome

A `manifest.json` and service worker are served automatically for PWA compatibility.

---

## HTTP API Reference

### `GET /api/status`

Returns the full system state as JSON. Polled by the web interface.

```json
{
  "micMuted": false,
  "audio": {
    "name": "MacBook Pro Speakers",
    "inputName": "MacBook Pro Microphone",
    "volume": 43,
    "inputVolume": 73,
    "isMuted": false
  },
  "spotify": {
    "isRunning": true,
    "isPlaying": true,
    "track": "Track Name",
    "artist": "Artist",
    "album": "Album",
    "shuffle": false,
    "repeatState": false,
    "position": 45,
    "duration": 180
  },
  "attention": {
    "slack": { "severity": "attention", "count": 3, "label": "3 ch", "segments": [...] },
    "teams": { "severity": "none", "count": 0, "label": "" },
    "outlook": { "severity": "unreadable", "count": 0, "label": "not running" },
    "messages": { "severity": "none", "count": 0, "label": "" }
  },
  "camera": {
    "inUse": false,
    "blocked": false,
    "frontCamera": false,
    "externalCamera": false,
    "teamsRunning": false
  },
  "nextUp": {
    "available": true,
    "title": "Team Standup",
    "start": "2026-08-10T14:30:00.000Z",
    "end": "2026-08-10T14:35:00.000Z",
    "duration": 5,
    "meeting": true,
    "meetingType": "Teams",
    "joinURL": "https://teams.microsoft.com/..."
  },
  "weather": {
    "available": true,
    "location": "Arkadelphia, AR",
    "temp": "72",
    "feelsLike": "74",
    "humidity": "65",
    "rainChance": 20,
    "condition": "Partly cloudy",
    "backgroundUrl": "https://images.unsplash.com/..."
  }
}
```

### `POST /api/action/{action}`

Triggers an action. Send with `body: '{}'`. Returns `{"status": "ok"}` (or error JSON).

#### Actions that return data

| Action | Response field |
|---|---|
| `mute_toggle` | `micMuted` (bool) |
| `talk_start` | `micMuted` (bool, always false) |
| `talk_stop` | `micMuted` (bool, always true) |
| `audio_mute` | `audioMuted` (bool) |

#### Fire-and-forget actions

| Action | Description |
|---|---|
| `cam_toggle` | Toggle camera in active meeting app |
| `audio_cycle` | Cycle to next audio output device |
| `audio_volup` | Volume up 5% |
| `audio_voldown` | Volume down 5% |
| `snap_selection` | Screenshot selection to clipboard |
| `record_screen` | Open screen recording toolbar |
| `app_chrome` | Launch/focus Chrome |
| `app_messages` | Launch/focus Messages PWA |
| `app_chatgpt` | Launch/focus ChatGPT |
| `app_teams` | Launch/focus Teams |
| `app_slack` | Launch/focus Slack |
| `app_outlook` | Launch/focus Outlook |
| `app_firefox` | Launch/focus Firefox |
| `spotify_playpause` | Toggle play/pause |
| `spotify_next` | Next track |
| `spotify_prev` | Previous track |
| `spotify_shuffle` | Toggle shuffle |
| `spotify_repeat` | Toggle repeat |
| `spotify_like` | Like current track |
| `spotify_open` | Open/focus Spotify app |
| `window_next_screen` | Move focused window to next display |
| `window_split` | 50/50 window split |

### `POST /api/action/play_uri?track={uri}&context={uri}`

Plays a specific Spotify track URI within a context (playlist/album). Used by the playlist chooser modal.

### `GET /api/debug/attention`

Debug endpoint showing cached attention state and window titles for Outlook, Teams, Slack, and Messages. Useful for troubleshooting.

### Other endpoints

| Path | Description |
|---|---|
| `GET /` | The web interface (index.html) |
| `GET /manifest.json` | PWA manifest |
| `GET /sw.js` | Service worker |
| `GET /icon.svg` | App icon |

---

## Architecture

### Module Structure

```
~/.hammerspoon/
├── init.lua              # Entry point: loads modules, starts services, hotkeys
├── env.lua               # .env file parser
├── server.lua            # HTTP server + API endpoints
├── index.html            # Web interface (single-page app, inline CSS/JS)
├── attention.lua         # Attention provider registry + background cache
├── camera.lua            # Camera status via hs.camera (polls every 5s)
├── calendar.lua          # Calendar ICS fetcher (runs node script every 60s)
├── weather.lua           # Weather fetcher (curl wttr.in every 10min)
├── spotify.lua           # Spotify control via AppleScript
├── mute.lua              # Mic mute with HUD overlay
├── meeting.lua           # Camera toggle (auto-detects meeting app)
├── audio.lua             # Audio device switching and volume
├── screenshot.lua        # Screenshot shortcuts
├── record.lua            # Screen recording shortcut
├── apps.lua              # Smart app launcher
├── window.lua            # Window management (move to screen, split)
├── providers/
│   ├── slack.lua         # Slack unread (reads cache file, falls back to root-state.json)
│   ├── teams.lua         # Teams unread (reads cache file, falls back to dock badge)
│   ├── outlook.lua       # Outlook unread (reads OSA sync logs)
│   └── messages.lua      # Messages unread (JXA via Chrome)
├── scripts/
│   ├── refresh_attention.sh  # Launches node scripts in background
│   ├── slack_unread.js       # Slack unread via Chrome DevTools Protocol (port 9222)
│   ├── teams_unread.js       # Teams unread via Chrome DevTools Protocol (port 9223)
│   ├── calendar_ics.js       # ICS parser using node-ical + luxon
│   └── package.json          # Node dependencies
└── .env                  # Your configuration (gitignored)
```

### Data Flow

```
Tablet (browser)
    │
    │  HTTP GET /api/status (1s fast / 10s slow)
    ▼
server.lua (hs.httpserver on port 8080)
    │
    ├── mute.isMuted()           → direct CoreAudio check
    ├── audio.getStatus()        → direct CoreAudio check
    ├── camera.getStatus()       → cached (hs.camera polls every 5s)
    ├── spotify.getStatus()      → single AppleScript call (batched)
    ├── attention.getStatus()    → cached (providers refresh every 60s)
    ├── calendar.getStatus()     → cached (node script runs every 60s)
    └── weather.getStatus()      → cached (curl runs every 10min)

Attention providers (background refresh):
    refresh_attention.sh → slack_unread.js → /tmp/slack_attention.json
                         → teams_unread.js → /tmp/teams_attention.json
    outlook.lua → reads OSA sync logs directly
    messages.lua → JXA via Chrome (synchronous, in provider)
```

### Slack Debug Port

Slack doesn't respect environment variables for debug ports when launched via Finder/Dock. GeekSpoons handles this automatically:

1. When Slack launches, an app watcher fires
2. After 3 seconds, `ensureSlackDebugPort()` checks if port 9222 is listening
3. If not, it hides Slack, kills it, and relaunches with `--remote-debugging-port=9222`
4. The user sees a brief "Slack Loading..." alert; the kill/relaunch flicker is hidden

### Teams Debug Port

Teams (WebView2) does respect environment variables. GeekSpoons sets this globally at startup:

```bash
launchctl setenv WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS "--remote-debugging-port=9223"
```

Teams must be launched after Hammerspoon starts (or relaunched) for this to take effect.

---

## Attention Providers

### Slack (`providers/slack.lua`)

- **Primary**: Reads `/tmp/slack_attention.json` written by `slack_unread.js` (Chrome DevTools Protocol on port 9222). Counts unread channels and DMs by scraping Slack's sidebar DOM.
- **Fallback**: Reads `~/Library/Application Support/Slack/storage/root-state.json` for raw unread/highlight counts.
- **Severity**: DMs = urgent (red), channels only = attention (amber)

### Teams (`providers/teams.lua`)

- **Primary**: Reads `/tmp/teams_attention.json` written by `teams_unread.js` (Chrome DevTools Protocol on port 9223). Counts unread people, meetings, and channels by scraping Teams' sidebar tree.
- **Fallback**: Reads the Dock badge via AXUIElement traversal.
- **Severity**: People/DMs = urgent (red), meetings + channels = attention (amber)

### Outlook (`providers/outlook.lua`)

- **Primary**: Reads Outlook's OSA (Outlook Service API) sync logs in `~/Library/Group Containers/UBF8T346G9.Office/Outlook/.../Osa/`. Searches the 5 most recent sessions for GetFolder response files, decompresses the XML, and extracts the Inbox unread count.
- **Freshness**: Only GetFolder files modified within the last 2 hours are considered valid. Older files return "unreadable" to avoid stale counts.
- **Severity**: Inbox unread > 0 = attention (amber)

### Google Messages (`providers/messages.lua`)

- **Primary**: Executes JavaScript via Chrome's AppleScript interface (JXA) to count `a.list-item` elements with `.unread` children on the messages.google.com tab.
- **Requirements**: Chrome must be running with a tab on messages.google.com, and "Allow JavaScript from Apple Events" must be enabled.
- **Severity**: Unread conversations > 0 = attention (amber)

---

## Background Scripts

### `scripts/refresh_attention.sh`

A bash script launched by `init.lua` every 60 seconds. It:

1. Validates Node.js is available
2. Launches `slack_unread.js` and `teams_unread.js` in parallel as background processes
3. Redirects stdout to cache files (`/tmp/slack_attention.json`, `/tmp/teams_attention.json`)
4. Detaches immediately so `hs.execute` returns without blocking
5. Reaps background processes with `wait`

Uses `set -euo pipefail` for robust error handling. Logs stderr to `/tmp/refresh_attention.log`.

### `scripts/slack_unread.js`

Connects to Slack's Chrome DevTools Protocol on port 9222, finds the Slack client tab, and executes JavaScript to count unread channels and DMs. Has a 3-second timeout. Outputs JSON to stdout.

### `scripts/teams_unread.js`

Connects to Teams' Chrome DevTools Protocol on port 9223, finds the Teams page tab with the most tree items, and executes JavaScript to count unread people, meetings, and channels. Has a 5-second overall timeout and a 3-second per-tab probe timeout. Outputs JSON to stdout.

### `scripts/calendar_ics.js`

Fetches the ICS feed URL, parses it with `node-ical` (full RRULE/EXDATE/RDATE support), filters to upcoming events, and finds the current or next meeting. Uses Luxon for timezone-aware time handling (auto-detects system timezone). Outputs JSON to stdout.

---

## Troubleshooting

### Server not starting

1. Check Hammerspoon console for Lua errors (menu bar > Console)
2. Verify port 8080 isn't in use: `lsof -i :8080`
3. Try reloading: Cmd+Alt+Ctrl+Shift+R
4. Check that all `require()`d modules exist and have no syntax errors

### Slack unread counts not working

1. Verify Slack was relaunched with the debug port: `lsof -i :9222` should show LISTEN
2. If not, quit Slack and relaunch Hammerspoon — it will relaunch Slack with the port
3. Check `/tmp/refresh_attention.log` for errors
4. Check `/tmp/slack_attention.json` for output

### Teams unread counts not working

1. Verify the debug port env var is set: `launchctl getenv WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS`
2. If empty, restart Hammerspoon, then restart Teams
3. Check `lsof -i :9223` should show LISTEN
4. Check `/tmp/teams_attention.json` for output

### Outlook unread counts not working

1. Verify Outlook is running
2. Check the OSA path exists: `ls ~/Library/Group\ Containers/UBF8T346G9.Office/Outlook/Outlook\ 15\ Profiles/Main\ Identity/Osa/`
3. If the path is different, set `OUTLOOK_OSA_PATH` in `.env`
4. Outlook must have synced recently — counts expire after 2 hours

### Google Messages unread counts not working

1. Open Chrome and navigate to messages.google.com
2. Enable **View > Developer > Allow JavaScript from Apple Events**
3. The provider will show "enable JS in Chrome" if this isn't enabled
4. It will show "no Messages tab" if no tab is open on messages.google.com

### Calendar not loading

1. Verify your ICS URL is correct in `.env`
2. Test the URL in a browser — it should download a .ics file
3. Check that Node.js is installed: `which node`
4. Run the script manually: `node ~/.hammerspoon/scripts/calendar_ics.js "YOUR_ICS_URL"`

### Weather not loading

1. Verify your weather location in `.env`
2. Test the API: `curl -s "https://wttr.in/Your+City?format=j1" | head -20`
3. Check Hammerspoon console for errors

### Spotify not responding

1. Ensure Spotify is running and has a main window open
2. The status shows "Spotify Not Running" if the app isn't detected
3. Grant Hammerspoon automation permission for Spotify in System Settings > Privacy & Security > Automation

### Camera status not updating

1. Camera status polls every 2 seconds using `hs.camera`
2. Check that no other app is blocking camera access
3. The button shows "CAM ACTIVE" (green) when in use, "CAM OFF" (red) when Teams is running but camera is off, "CAMERA" (grey) when idle

### Tablet can't connect

1. Ensure both devices are on the same network
2. Find your Mac's IP: System Settings > Network, or `ifconfig | grep inet`
3. Try `http://<mac-ip>:8080` in the tablet browser
4. Check macOS firewall settings (System Settings > Network > Firewall)
5. If using a VPN, it may block local network access

---

## File Reference

| File | Lines | Description |
|---|---|---|
| `init.lua` | ~166 | Entry point, module loading, hotkeys, app watchers |
| `env.lua` | ~42 | `.env` file parser |
| `server.lua` | ~218 | HTTP server, API routing, action dispatch |
| `index.html` | ~2020 | Web interface (single-page app) |
| `attention.lua` | ~95 | Provider registry, background cache, loading state |
| `camera.lua` | ~55 | Camera status via `hs.camera` |
| `calendar.lua` | ~53 | ICS calendar fetcher (async via `hs.task`) |
| `weather.lua` | ~107 | Weather from wttr.in (async via `hs.task`) |
| `spotify.lua` | ~135 | Spotify control via batched AppleScript |
| `mute.lua` | ~128 | Mic mute with HUD canvas overlay |
| `meeting.lua` | ~42 | Camera toggle with meeting app auto-detection |
| `audio.lua` | ~146 | Audio device switching, volume, mute |
| `screenshot.lua` | ~38 | Screenshot keyboard shortcuts |
| `record.lua` | ~9 | Screen recording shortcut |
| `apps.lua` | ~128 | Smart app launcher with window polling |
| `window.lua` | ~49 | Window move-to-screen and 50/50 split |
| `providers/slack.lua` | ~80 | Slack unread (cache + root-state fallback) |
| `providers/teams.lua` | ~113 | Teams unread (cache + dock badge fallback) |
| `providers/outlook.lua` | ~104 | Outlook unread (OSA sync log parser) |
| `providers/messages.lua` | ~68 | Messages unread (Chrome JXA) |
| `scripts/refresh_attention.sh` | ~30 | Background launcher for node scripts |
| `scripts/slack_unread.js` | ~80 | Slack unread via CDP |
| `scripts/teams_unread.js` | ~133 | Teams unread via CDP |
| `scripts/calendar_ics.js` | ~100 | ICS parser using node-ical |
