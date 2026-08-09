-- camera.lua: Camera status detection via IOKit
-- Detects if the built-in FaceTime camera or external UVC webcam is in use.
-- Uses ioreg to read FrontCameraActive and checks UVC assistant busy state.
-- Cached with background refresh to keep /api/status fast.

local camera = {}

local cachedStatus = {
    inUse = false,
    blocked = false,
    frontCamera = false,
    externalCamera = false,
}

local refreshTimer = nil

local function refresh()
    -- Check built-in camera via IOKit registry
    local output = hs.execute('ioreg -l 2>/dev/null | grep "FrontCameraActive"')
    local frontActive = output and output:match("=%s*(%w+)") or "No"
    local frontInUse = frontActive == "Yes"

    -- Check external UVC webcam by looking at the VDCAssistant busy state
    local uvcOutput = hs.execute('ioreg -r -n "UVCAssistant" 2>/dev/null | grep "busy"')
    local uvcBusy = false
    if uvcOutput then
        local busyVal = uvcOutput:match("busy%s+(%d+)")
        if busyVal and tonumber(busyVal) > 0 then
            uvcBusy = true
        end
    end

    local inUse = frontInUse or uvcBusy

    cachedStatus = {
        inUse = inUse,
        blocked = false,
        frontCamera = frontInUse,
        externalCamera = uvcBusy,
    }
end

function camera.getStatus()
    return cachedStatus
end

function camera.start()
    if refreshTimer then refreshTimer:stop() end
    hs.timer.doAfter(3, refresh)
    refreshTimer = hs.timer.doEvery(5, refresh)
end

return camera
