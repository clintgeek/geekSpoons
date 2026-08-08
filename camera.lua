-- camera.lua: Camera status detection via IOKit
-- Detects if the built-in FaceTime camera or external UVC webcam is in use.
-- Uses ioreg to read FrontCameraActive and checks UVC assistant busy state.

local camera = {}

function camera.getStatus()
    -- Check built-in camera via IOKit registry
    -- "FrontCameraActive" = Yes/No in the AppleH*CameraInterface node
    local output = hs.execute('ioreg -l 2>/dev/null | grep "FrontCameraActive"')
    local frontActive = output and output:match("=%s*(%w+)") or "No"
    local frontInUse = frontActive == "Yes"

    -- Check external UVC webcam by looking at the VDCAssistant busy state
    -- When a UVC camera is streaming, the UVCAssistant device shows busy > 0
    local uvcOutput = hs.execute('ioreg -r -n "UVCAssistant" 2>/dev/null | grep "busy"')
    local uvcBusy = false
    if uvcOutput then
        -- Look for busy > 0 (e.g. "busy 5 (54 ms)")
        local busyVal = uvcOutput:match("busy%s+(%d+)")
        if busyVal and tonumber(busyVal) > 0 then
            uvcBusy = true
        end
    end

    -- Also check if any known meeting app is actively using the camera
    -- by looking at process open files on the VDC plugin
    local inUse = frontInUse or uvcBusy

    -- Check if camera access is blocked (system-level privacy)
    -- hs.cameraState checks Hammerspoon's own permission, but we can
    -- also check if the system has camera disabled via TCC
    local blocked = false

    -- If camera is in use but the system reports it as disabled,
    -- mark as blocked. For now, we just report in-use status.
    -- A more sophisticated check would inspect TCC privacy settings.

    return {
        inUse = inUse,
        blocked = blocked,
        frontCamera = frontInUse,
        externalCamera = uvcBusy,
    }
end

return camera
