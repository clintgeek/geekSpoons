-- camera.lua: Camera status detection via hs.camera
-- Uses Hammerspoon's built-in hs.camera module for reliable camera status.
-- Polls every 5 seconds (hs.camera's per-camera property watchers can be
-- unreliable across macOS versions, so polling is the safe approach).

local camera = {}

local hsCamera = require("hs.camera")

local cachedStatus = {
    inUse = false,
    blocked = false,
    frontCamera = false,
    externalCamera = false,
}
local refreshTimer = nil

local function classifyName(name)
    name = (name or ""):lower()
    if name:match("facetime") or name:match("macbook") then
        return "front"
    end
    return "external"
end

local function refresh()
    local all = hsCamera.allCameras()
    local frontInUse = false
    local externalInUse = false

    for _, cam in ipairs(all) do
        if cam:isInUse() then
            local kind = classifyName(cam:name())
            if kind == "front" then frontInUse = true
            else externalInUse = true end
        end
    end

    cachedStatus = {
        inUse = frontInUse or externalInUse,
        blocked = false,
        frontCamera = frontInUse,
        externalCamera = externalInUse,
    }
end

function camera.getStatus()
    return cachedStatus
end

function camera.start()
    hs.timer.doAfter(3, refresh)
    refreshTimer = hs.timer.doEvery(5, refresh)
end

return camera
