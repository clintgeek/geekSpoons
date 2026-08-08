-- screenshot.lua: Interactive region screenshot capture tools
local screenshot = {}

local function desktopFilename(prefix, ext)
    local desktopPath = os.getenv("HOME") .. "/Desktop"
    return desktopPath .. "/" .. prefix .. "_" .. os.date("%Y-%m-%d_%H-%M-%S") .. "." .. ext
end

function screenshot.copyToClipboard()
    hs.task.new("/usr/bin/screencapture", nil, {"-c", "-i"}):start()
end

function screenshot.saveToFile()
    hs.task.new("/usr/bin/screencapture", function(exitCode)
        if exitCode == 0 then
            hs.alert.show("💾 Screenshot saved to Desktop!")
        end
    end, {"-i", desktopFilename("Screenshot", "png")}):start()
end

function screenshot.selection()
    hs.task.new("/usr/bin/screencapture", function(exitCode)
        if exitCode == 0 then
            hs.alert.show("💾 Screenshot saved to Desktop!")
        end
    end, {"-i", desktopFilename("Screenshot", "png")}):start()
end

function screenshot.window()
    hs.task.new("/usr/bin/screencapture", function(exitCode)
        if exitCode == 0 then
            hs.alert.show("💾 Screenshot saved to Desktop!")
        end
    end, {"-w", desktopFilename("Screenshot", "png")}):start()
end

function screenshot.fullscreen()
    hs.task.new("/usr/bin/screencapture", function(exitCode)
        if exitCode == 0 then
            hs.alert.show("💾 Screenshot saved to Desktop!")
        end
    end, {desktopFilename("Screenshot", "png")}):start()
end

return screenshot
