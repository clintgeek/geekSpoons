-- record.lua: Interactive screen recording tools
local record = {}

local function desktopFilename(prefix)
    local desktopPath = os.getenv("HOME") .. "/Desktop"
    return desktopPath .. "/" .. prefix .. "_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".mov"
end

local function notifySave(filename)
    return function(exitCode)
        if exitCode == 0 then
            hs.alert.show("🎥 Recording saved to Desktop!")
        end
    end
end

function record.area()
    -- Interactive area selection, saves to Desktop as .mov
    hs.task.new("/usr/bin/screencapture", notifySave(), {"-v", "-i", desktopFilename("Recording")}):start()
end

function record.window()
    -- Record selected window, saves to Desktop as .mov
    hs.task.new("/usr/bin/screencapture", notifySave(), {"-v", "-w", desktopFilename("Recording")}):start()
end

function record.fullscreen()
    -- Record full screen, saves to Desktop as .mov
    hs.task.new("/usr/bin/screencapture", notifySave(), {"-v", desktopFilename("Recording")}):start()
end

return record
