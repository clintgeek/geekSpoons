-- Load environment variables from .env before anything else
require("env").load()

-- Auto-reload Hammerspoon config on file save
local function reloadConfig(files)
    local doReload = false
    for _, file in ipairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
            break
        end
    end
    if doReload then
        hs.reload()
    end
end

local configFileWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig)
configFileWatcher:start()

-- Load core modules
local spotify = require("spotify")
local mute = require("mute")
local meeting = require("meeting")
local winManager = require("window")
local browser = require("browser")
local audio = require("audio")
local screenshot = require("screenshot")
local record = require("record")
local apps = require("apps")
local attention = require("attention")
local camera = require("camera")
local calendar = require("calendar")
local weather = require("weather")
local outlookProvider = require("providers.outlook")
local slackProvider = require("providers.slack")
local teamsProvider = require("providers.teams")
local messagesProvider = require("providers.messages")
local server = require("server")

-- Register attention providers
attention.register("outlook", outlookProvider.getAttention)
attention.register("slack", slackProvider.getAttention)
attention.register("teams", teamsProvider.getAttention)
attention.register("messages", messagesProvider.getAttention)

-- Start background attention refresh (caches provider data every 10s)
attention.start()

-- Start background camera status refresh (caches ioreg data every 5s)
camera.start()

-- Start calendar and weather refresh
calendar.start()
weather.start()

-- Start Stream Deck HTTP Server on port 8080
server.start()

-- Set debug port env var globally for Teams (WebView2). Slack doesn't
-- respect env vars when launched via Finder/Dock, so we handle it
-- separately by relaunching with --args when it launches without the port.
hs.execute('launchctl setenv WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS "--remote-debugging-port=9223"')

-- Background refresh of Slack/Teams unread counts.
-- Uses a wrapper shell script that properly backgrounds and detaches the node
-- processes, so hs.execute returns immediately without blocking the main thread.
-- Each script writes JSON to a temp file that the providers read instantly.
local REFRESH_SCRIPT = hs.configdir .. "/scripts/refresh_attention.sh"

local function refreshAttentionBackground()
    hs.execute('"' .. REFRESH_SCRIPT .. '"')
end

-- Ensure Slack has its debug port. If it's running without port 9222,
-- kill and relaunch with --remote-debugging-port=9222 via open --args.
-- Hides the initial window immediately so the user doesn't see the
-- kill/relaunch flicker.
local slackRelaunching = false

local function ensureSlackDebugPort()
    local app = hs.application.get("Slack")
    if not app then return end

    -- Check if Slack's debug port is already listening.
    -- Synchronous but fast (lsof on a single port is ~10ms).
    local portCheck = hs.execute("lsof -i :9222 2>/dev/null")
    if portCheck and portCheck:match("LISTEN") then
        return
    end

    -- Port not open — hide, kill, and relaunch Slack with debug port
    app:hide()
    hs.alert.show("Slack Loading...", 2)
    slackRelaunching = true
    app:kill()
    hs.timer.doAfter(2, function()
        hs.execute('open -a Slack --args --remote-debugging-port=9222')
        hs.timer.doAfter(5, function() slackRelaunching = false end)
    end)
end

-- Timer intervals (seconds) for app-launch settling sequence.
-- Slack needs debug port setup first; Teams just needs cache refresh.
local SLACK_DEBUG_PORT_DELAY = 3    -- wait for Slack process to stabilize before port check
local SLACK_FIRST_REFRESH    = 10   -- first cache refresh after Slack settles
local SLACK_SECOND_REFRESH   = 18   -- second refresh (Slack UI can be slow to populate)
local SLACK_UI_UPDATE        = 22   -- trigger attention UI update after cache is warm
local TEAMS_FIRST_REFRESH    = 5    -- first cache refresh after Teams settles
local TEAMS_SECOND_REFRESH   = 10   -- second refresh for Teams
local TEAMS_UI_UPDATE        = 13   -- trigger attention UI update for Teams
local INITIAL_REFRESH_DELAY  = 8    -- initial background refresh after Hammerspoon starts
local REFRESH_INTERVAL       = 60   -- ongoing background refresh interval

-- Start background refresh cycle
local attentionRefreshTimer = hs.timer.doAfter(INITIAL_REFRESH_DELAY, refreshAttentionBackground)
local attentionRefreshInterval = hs.timer.doEvery(REFRESH_INTERVAL, refreshAttentionBackground)

-- When Slack or Teams launches, refresh cache files after the app settles,
-- then trigger an immediate attention refresh to update the UI.
local appWatcher = hs.application.watcher.new(function(appName, event)
    if event == hs.application.watcher.launched then
        if appName == "Slack" then
            attention.markLoading("slack")
            hs.timer.doAfter(SLACK_DEBUG_PORT_DELAY, ensureSlackDebugPort)
            hs.timer.doAfter(SLACK_FIRST_REFRESH, refreshAttentionBackground)
            hs.timer.doAfter(SLACK_SECOND_REFRESH, refreshAttentionBackground)
            hs.timer.doAfter(SLACK_UI_UPDATE, attention.refreshNow)
        elseif appName == "Microsoft Teams" or appName == "MSTeams" then
            attention.markLoading("teams")
            hs.timer.doAfter(TEAMS_FIRST_REFRESH, refreshAttentionBackground)
            hs.timer.doAfter(TEAMS_SECOND_REFRESH, refreshAttentionBackground)
            hs.timer.doAfter(TEAMS_UI_UPDATE, attention.refreshNow)
        end
    elseif event == hs.application.watcher.terminated then
        if appName == "Slack" and not slackRelaunching then
            attention.markNotRunning("slack")
        elseif (appName == "Microsoft Teams" or appName == "MSTeams") then
            attention.markNotRunning("teams")
        end
    end
end)
appWatcher:start()

-- Global Hotkey Bindings (Mac keyboard backups)
-- Hyper Key = Cmd + Alt + Ctrl + Shift
local hyper = {"cmd", "alt", "ctrl", "shift"}

-- Hyper + R: Reload Hammerspoon config manually
hs.hotkey.bind(hyper, "R", function()
    hs.reload()
end)

-- Hyper + M: Mic Mute Toggle
hs.hotkey.bind(hyper, "M", function()
    mute.toggleMute()
end)

-- Hyper + Space: Spotify Play/Pause Toggle
hs.hotkey.bind(hyper, "space", function()
    spotify.playPause()
end)

-- Hyper + S: 50/50 Window Split
hs.hotkey.bind(hyper, "S", function()
    winManager.split5050()
end)
