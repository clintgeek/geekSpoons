-- screenshot.lua: Interactive region screenshot capture tools
local screenshot = {}

function screenshot.copyToClipboard()
    -- Interactive rectangle drag to clipboard
    hs.task.new("/usr/bin/screencapture", nil, {"-c", "-i"}):start()
end

function screenshot.saveToFile()
    local desktopPath = os.getenv("HOME") .. "/Desktop"
    local filename = desktopPath .. "/Screenshot_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".png"
    hs.task.new("/usr/bin/screencapture", function(exitCode)
        if exitCode == 0 then
            hs.alert.show("💾 Saved to Desktop!")
        end
    end, {"-i", filename}):start()
end

return screenshot
