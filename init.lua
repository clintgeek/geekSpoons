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

-- Retain references to long-lived objects (watchers, timers) so they
-- aren't garbage collected when init.lua's main chunk finishes executing.
-- Hammerspoon cancels timers/watchers when their Lua objects are GC'd.
-- This must be a global (not local) so it persists after init.lua returns.
_G._retained = {}

_G._retained.configFileWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig)
_G._retained.configFileWatcher:start()

-- Load core modules
local spotify = require("spotify")
local mute = require("mute")
local meeting = require("meeting")
local winManager = require("window")
local audio = require("audio")
local screenshot = require("screenshot")
local record = require("record")
local apps = require("apps")
local attention = require("attention")
local camera = require("camera")
local calendar = require("calendar")
local weather = require("weather")
local keepalive = require("keepalive")
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

-- Start per-provider attention refresh timers.
-- Each provider refreshes on its own interval (10-15s) with staggered
-- initial delays so they don't all fire at the same instant.
attention.start()

-- Start background camera status refresh (caches hs.camera data every 5s)
camera.start()

-- Start calendar and weather refresh
calendar.start()
weather.start()

-- Start Bluetooth speaker keep-alive (prevents Klipsch from auto-powering off)
keepalive.start(300)

-- Start Stream Deck HTTP Server on port 8080
server.start()

-- Set debug port env var globally for Teams (WebView2). Slack doesn't
-- respect env vars when launched via Finder/Dock, so we handle it
-- separately by relaunching with --args when it launches without the port.
hs.execute('launchctl setenv WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS "--remote-debugging-port=9223"')

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
-- After an app launches, we mark it "loading", wait for it to settle,
-- then trigger an immediate refresh to get real data ASAP.
local SLACK_DEBUG_PORT_DELAY = 3    -- wait for Slack process to stabilize before port check
local SLACK_FIRST_REFRESH    = 10   -- first provider refresh after Slack settles
local SLACK_SECOND_REFRESH   = 18   -- second refresh (Slack UI can be slow to populate)
local TEAMS_FIRST_REFRESH    = 5    -- first provider refresh after Teams settles
local TEAMS_SECOND_REFRESH   = 10   -- second refresh for Teams
local OUTLOOK_SETTLE_DELAY   = 8    -- wait for Outlook AX tree to be ready
local MESSAGES_SETTLE_DELAY  = 5    -- wait for Chrome tab to load before JXA probe

-- When a watched app launches, mark it loading, then refresh after it settles.
-- When it terminates, mark it not running immediately.
-- The per-provider timers (started by attention.start()) will keep refreshing
-- data on their own intervals after the initial settle sequence.
_G._retained.appWatcher = hs.application.watcher.new(function(appName, event)
    if event == hs.application.watcher.launched then
        if appName == "Slack" then
            attention.markLoading("slack")
            hs.timer.doAfter(SLACK_DEBUG_PORT_DELAY, ensureSlackDebugPort)
            hs.timer.doAfter(SLACK_FIRST_REFRESH, function() attention.refreshProvider("slack") end)
            hs.timer.doAfter(SLACK_SECOND_REFRESH, function() attention.refreshProvider("slack") end)
        elseif appName == "Microsoft Teams" or appName == "MSTeams" then
            attention.markLoading("teams")
            hs.timer.doAfter(TEAMS_FIRST_REFRESH, function() attention.refreshProvider("teams") end)
            hs.timer.doAfter(TEAMS_SECOND_REFRESH, function() attention.refreshProvider("teams") end)
        elseif appName == "Microsoft Outlook" then
            attention.markLoading("outlook")
            hs.timer.doAfter(OUTLOOK_SETTLE_DELAY, function() attention.refreshProvider("outlook") end)
        elseif appName == "Google Chrome" then
            attention.markLoading("messages")
            hs.timer.doAfter(MESSAGES_SETTLE_DELAY, function() attention.refreshProvider("messages") end)
        end
    elseif event == hs.application.watcher.terminated then
        if appName == "Slack" and not slackRelaunching then
            attention.markNotRunning("slack")
        elseif (appName == "Microsoft Teams" or appName == "MSTeams") then
            attention.markNotRunning("teams")
        elseif appName == "Microsoft Outlook" then
            attention.markNotRunning("outlook")
        elseif appName == "Google Chrome" then
            attention.markNotRunning("messages")
        end
    end
end)
_G._retained.appWatcher:start()

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
