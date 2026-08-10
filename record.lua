-- record.lua: Trigger macOS built-in screen recording toolbar
local record = {}

function record.screen()
    -- Cmd+Shift+5 opens the screenshot/recording toolbar; user selects mode
    hs.eventtap.keyStroke({"cmd", "shift"}, "5")
end

return record
-- touch
