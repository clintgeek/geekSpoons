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
        matchPath = "Chrome Apps.localized/Messages.app",
        appUrl = "https://messages.google.com/web/u/1/conversations"
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
        local a = hs.application.get(config.name)
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

    local app = hs.application.get(config.name) or hs.application.get(config.path)

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
