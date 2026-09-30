-- window.lua: Window layout helpers
local winManager = {}

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

return winManager
