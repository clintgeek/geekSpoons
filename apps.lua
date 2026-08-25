-- apps.lua: Smart Workspace Application Launcher for Hammerspoon
local apps = {}

local env = require("env")
local HOME = env.get("HOME") or ""

-- Escape a string for safe use inside double quotes in a shell command.
local function shellEscape(s)
    return (s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('`', '\\`'):gsub('%$', '\\$'))
end

-- Polling constants
local REOPEN_POLL_INTERVAL = 0.2  -- seconds between window checks when reopening
local REOPEN_MAX_ATTEMPTS   = 15  -- max polls when app is running but windowless
local LAUNCH_POLL_INTERVAL  = 0.3  -- seconds between window checks after fresh launch
local LAUNCH_MAX_ATTEMPTS   = 20  -- max polls after fresh launch

apps.config = {
    chrome = {
        name = "Google Chrome",
        path = "/Applications/Google Chrome.app"
    },
    messages = {
        name = "Messages",
        path = env.get("MESSAGES_APP_PATH") or (HOME .. "/Applications/Chrome Apps.localized/Messages.app"),
        matchPath = "Chrome Apps.localized/Messages.app"
    },
    chatgpt = {
        name = "ChatGPT",
        path = env.get("CHATGPT_APP_PATH") or (HOME .. "/Applications/Edge Apps.localized/ChatGPT.app")
    },
    teams = {
        name = "Microsoft Teams",
        path = "/Applications/Microsoft Teams.app"
    },
    slack = {
        name = "Slack",
        path = "/Applications/Slack.app"
    },
    outlook = {
        name = "Microsoft Outlook",
        path = "/Applications/Microsoft Outlook.app"
    },
    firefox = {
        name = "Firefox",
        path = "/Applications/Firefox.app"
    }
}

-- Find a running instance of a configured app without triggering an
-- Accessibility window sweep. hs.application.get()/find() search by name with
-- exact=false, and on a miss they fall through to hs.window.find(), which calls
-- allWindows() on every running app -- ~1.5s of synchronous AX IPC here. That
-- miss is the common case: waitForWindow() polls every 0.2-0.3s for an app that
-- hasn't appeared yet, and config.name doesn't always match the running process
-- (Microsoft Teams runs as "MSTeams"). The sweeps took longer than the poll
-- interval, so they queued and starved the HTTP server for the whole launch.
-- Resolving the bundle ID from the app's own Info.plist is a cheap file read,
-- cached, and applicationsForBundleID() never sweeps.
local bundleIDCache = {}

local function bundleIDFor(config)
    local cached = bundleIDCache[config.path]
    if cached ~= nil then return cached or nil end
    local info = hs.application.infoForBundlePath(config.path)
    local id = (info and info.CFBundleIdentifier) or false
    bundleIDCache[config.path] = id
    return id or nil
end

-- Exact-name match over the running app list. Used only when the bundle path
-- can't be read (app moved or not installed). Still no AX calls.
local function runningAppNamed(name)
    if not name then return nil end
    for _, a in ipairs(hs.application.runningApplications()) do
        if a:name() == name then return a end
    end
    return nil
end

local function getRunningApp(config)
    local id = bundleIDFor(config)
    if id then
        local a = hs.application.applicationsForBundleID(id)[1]
        if a then return a end
    end
    return runningAppNamed(config.name)
end

-- Find the first standard window of an app, or fall back to the first window.
local function findMainWindow(app)
    local windows = app:allWindows()
    if not windows then return nil end
    for _, w in ipairs(windows) do
        if w:isStandard() and w:title() ~= "" then
            return w
        end
    end
    if #windows > 0 then return windows[1] end
    return nil
end

-- Poll for a window to appear, then focus/raise/maximize it.
local function waitForWindow(config, interval, maxAttempts)
    local attempts = 0
    local timer
    timer = hs.timer.doEvery(interval, function()
        attempts = attempts + 1
        local a = getRunningApp(config)
        if a then
            local w = a:mainWindow() or (a:allWindows() and a:allWindows()[1])
            if w then
                w:focus()
                w:raise()
                w:maximize()
                timer:stop()
            end
        end
        if attempts >= maxAttempts then timer:stop() end
    end)
end

-- App is running but has no windows — reopen and wait for a window.
local function reopenApp(config)
    hs.application.launchOrFocus(config.path)
    hs.applescript(string.format([[
        tell application "%s"
            reopen
            activate
        end tell
    ]], config.name))
    waitForWindow(config, REOPEN_POLL_INTERVAL, REOPEN_MAX_ATTEMPTS)
end

-- App is closed — launch fresh and wait for a window to maximize.
local function launchApp(config)
    hs.application.launchOrFocus(config.path)
    waitForWindow(config, LAUNCH_POLL_INTERVAL, LAUNCH_MAX_ATTEMPTS)
end

function apps.smartLaunch(appKey)
    local config = apps.config[appKey]
    if not config then return end

    -- For PWA apps (matchPath), just use `open` — the OS handles focus/launch like Finder
    if config.matchPath then
        hs.execute('open "' .. shellEscape(config.path) .. '"')
        return
    end

    local app = getRunningApp(config)

    if app and app:isRunning() then
        local win = findMainWindow(app)
        if win then
            -- App is already open with a window — just switch focus
            win:focus()
            win:raise()
        else
            reopenApp(config)
        end
    else
        launchApp(config)
    end
end

return apps
