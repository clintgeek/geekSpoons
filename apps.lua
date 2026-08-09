-- apps.lua: Smart Workspace Application Launcher for Hammerspoon
local apps = {}

apps.config = {
    chrome = {
        name = "Google Chrome",
        path = "/Applications/Google Chrome.app"
    },
    messages = {
        name = "Messages",
        path = "/Users/clintcrocker/Applications/Chrome Apps.localized/Messages.app",
        matchPath = "Chrome Apps.localized/Messages.app",
        appUrl = "https://messages.google.com/web/u/1/conversations"
    },
    chatgpt = {
        name = "ChatGPT",
        path = "/Users/clintcrocker/Applications/Edge Apps.localized/ChatGPT.app"
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

function apps.smartLaunch(appKey)
    local config = apps.config[appKey]
    if not config then return end

    -- If the app has a URL, open/focus it in the configured browser
    if config.url then
        local browserName = config.browser or config.name
        local browser = hs.application.get(browserName)
        if browser and browser:isRunning() then
            -- Browser is running — check if the tab is already open
            local script = string.format([[
                tell application "%s"
                    set foundTab to false
                    repeat with w in every window
                        repeat with t in every tab of w
                            if (URL of t) contains "%s" then
                                tell w to set active tab index to (index of t)
                                set index of w to 1
                                activate
                                set foundTab to true
                                exit repeat
                            end if
                        end repeat
                        if foundTab then exit repeat
                    end repeat
                    if not foundTab then
                        tell window 1 to make new tab with properties {URL:"%s"}
                        activate
                    end if
                end tell
            ]], browserName, config.url, config.url)
            hs.osascript.applescript(script)
        else
            -- Browser not running — launch the PWA app
            hs.application.launchOrFocus(config.path)
        end
        return
    end

    -- For PWA apps (matchPath), just use `open` — the OS handles focus/launch like Finder
    if config.matchPath then
        hs.execute('open "' .. config.path .. '"')
        return
    end

    local app = hs.application.get(config.name) or hs.application.get(config.path)
    
    if app and app:isRunning() then
        local windows = app:allWindows()
        local win = nil

        -- Find the first valid standard window
        if windows then
            for _, w in ipairs(windows) do
                if w:isStandard() and w:title() ~= "" then
                    win = w
                    break
                end
            end
            if not win and #windows > 0 then
                win = windows[1]
            end
        end

        if win then
            -- App is already open and HAS a window -> Just switch focus without maximizing
            win:focus()
            win:raise()
        else
            -- App is running BUT has 0 active windows -> Reopen
            hs.application.launchOrFocus(config.path)
            hs.applescript(string.format([[
                tell application "%s"
                    reopen
                    activate
                end tell
            ]], config.name))

            local attempts = 0
            local timer
            timer = hs.timer.doEvery(0.2, function()
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
                if attempts >= 15 then timer:stop() end
            end)
        end
    else
        -- App is closed -> Launch fresh and maximize when window appears
        hs.application.launchOrFocus(config.path)

        local attempts = 0
        local timer
        timer = hs.timer.doEvery(0.3, function()
            attempts = attempts + 1
            -- For PWAs with matchPath, find by path; otherwise by name
            local a = nil
            if config.matchPath then
                for _, app in ipairs(hs.application.runningApplications()) do
                    if (app:path() or ""):match(config.matchPath) then
                        a = app
                        break
                    end
                end
            else
                a = hs.application.get(config.name)
            end
            if a then
                local w = a:mainWindow() or (a:allWindows() and a:allWindows()[1])
                if w then
                    w:focus()
                    w:raise()
                    w:maximize()
                    timer:stop()
                end
            end
            if attempts >= 20 then timer:stop() end
        end)
    end
end

return apps
