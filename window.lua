-- window.lua: Window layout, multi-monitor movement, and workspace management helpers
local winManager = {}

function winManager.moveToNextScreen()
    local win = hs.window.focusedWindow()
    if not win then
        hs.alert.show("No Focused Window")
        return
    end

    local currentScreen = win:screen()
    local nextScreen = currentScreen:next()

    if nextScreen and nextScreen ~= currentScreen then
        win:moveToScreen(nextScreen, true, true, 0)
        hs.alert.show("🖥️ Moved to " .. (nextScreen:name() or "Next Display"))
    else
        hs.alert.show("🖥️ Single Display Detected")
    end
end

function winManager.split5050()
    local win = hs.window.focusedWindow()
    if not win then return end
    local screen = win:screen()
    local max = screen:frame()

    -- Snap focused window to left half
    win:setFrame({
        x = max.x,
        y = max.y,
        w = max.w / 2,
        h = max.h
    })

    -- Snap next window on same screen to right half
    local otherWins = win:otherWindowsSameScreen()
    if #otherWins > 0 then
        otherWins[1]:setFrame({
            x = max.x + max.w / 2,
            y = max.y,
            w = max.w / 2,
            h = max.h
        })
        otherWins[1]:focus()
    end
end

function winManager.toggleCaffeinate()
    local state = hs.caffeinate.get("displayIdle")
    if state then
        hs.caffeinate.set("displayIdle", false, true)
        hs.alert.show("Caffeinate OFF (Sleep Allowed)")
        return false
    else
        hs.caffeinate.set("displayIdle", true, true)
        hs.alert.show("Caffeinate ON (Preventing Sleep)")
        return true
    end
end

function winManager.isCaffeinated()
    return hs.caffeinate.get("displayIdle") or false
end

function winManager.lockScreen()
    hs.caffeinate.lockScreen()
end

return winManager
