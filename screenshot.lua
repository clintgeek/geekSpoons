-- screenshot.lua: Trigger macOS built-in screenshot shortcuts.
local screenshot = {}

local KEYSTROKE_DELAY = 200000  -- microseconds (200ms) so macOS reliably picks up the shortcut

function screenshot.selection()
    -- Cmd+Shift+4: capture selected area to file with the floating thumbnail.
    -- The thumbnail lets you markup and then save or copy.
    hs.eventtap.keyStroke({"cmd", "shift"}, "4", KEYSTROKE_DELAY)
end

return screenshot
