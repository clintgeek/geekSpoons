-- screenshot.lua: Trigger macOS built-in screenshot shortcuts to clipboard.
-- Captures go to clipboard immediately. The floating thumbnail appears;
-- clicking it opens Markup (where you can save or re-copy), and ignoring
-- it leaves the image on the clipboard.
local screenshot = {}

local KEYSTROKE_DELAY = 200000  -- microseconds (200ms) so macOS reliably picks up the shortcut
local WINDOW_MODE_DELAY = 0.3   -- seconds to wait before pressing Space for window mode

local function triggerScreenshot(modifiers, key)
    hs.eventtap.keyStroke(modifiers, key, KEYSTROKE_DELAY)
end

function screenshot.copyToClipboard()
    -- Cmd+Ctrl+Shift+4: capture selected area to clipboard
    triggerScreenshot({"cmd", "ctrl", "shift"}, "4")
end

function screenshot.selection()
    -- Cmd+Shift+4: capture selected area to file with the floating thumbnail.
    -- The thumbnail lets you markup and then save or copy.
    triggerScreenshot({"cmd", "shift"}, "4")
end

function screenshot.window()
    -- Start area capture then immediately switch to window mode with Space
    triggerScreenshot({"cmd", "ctrl", "shift"}, "4")
    hs.timer.doAfter(WINDOW_MODE_DELAY, function()
        hs.eventtap.keyStroke({}, "space")
    end)
end

function screenshot.fullscreen()
    -- Cmd+Ctrl+Shift+3: capture full screen to clipboard
    triggerScreenshot({"cmd", "ctrl", "shift"}, "3")
end

return screenshot
