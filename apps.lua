-- apps.lua: Smart Workspace Application Launcher for Hammerspoon
local apps = {}

apps.config = {
    chrome = {
        name = "Google Chrome",
        path = "/Applications/Google Chrome.app"
    },
    messages = {
        name = "Messages",
        path = "/Users/clintcrocker/Applications/Edge Apps.localized/Messages.app"
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
            -- App is running BUT has 0 active windows -> Force reopen new window & maximize
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
            if attempts >= 20 then timer:stop() end
        end)
    end
end

return apps
