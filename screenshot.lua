-- screenshot.lua: Trigger macOS built-in screenshot shortcuts to clipboard.
-- Captures go to clipboard immediately. The floating thumbnail appears;
-- clicking it opens Markup (where you can save or re-copy), and ignoring
-- it leaves the image on the clipboard.
local screenshot = {}

local function triggerScreenshot(modifiers, key)
    -- Increase delay so macOS reliably picks up the shortcut
    hs.eventtap.keyStroke(modifiers, key, 200000)
end

function screenshot.copyToClipboard()
    -- Cmd+Ctrl+Shift+4: capture selected area to clipboard
    triggerScreenshot({"cmd", "ctrl", "shift"}, "4")
end

function screenshot.saveToFile()
    -- Same as copyToClipboard — clipboard is the default; user can save
    -- via the floating thumbnail's Markup if they want.
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
    hs.timer.doAfter(0.3, function()
        hs.eventtap.keyStroke({}, "space")
    end)
end

function screenshot.fullscreen()
    -- Cmd+Ctrl+Shift+3: capture full screen to clipboard
    triggerScreenshot({"cmd", "ctrl", "shift"}, "3")
end

return screenshot
