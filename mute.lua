-- mute.lua: Microphone mute controller with HUD indicator
-- Mutes ALL system input devices (not just default) by setting input
-- volume to 0. Shows a persistent "MIC MUTED" pill in the bottom-left
-- corner of the Mac screen while muted, plus a brief flash HUD on
-- mute/unmute transitions.

local mute = {}

local flashCanvas = nil      -- brief transition HUD (top center, 2s)
local mutedPillCanvas = nil  -- persistent pill (bottom-left, stays while muted)
local savedInputVolumes = {}  -- map of device UID → volume to restore on unmute
local DEFAULT_INPUT_VOLUME = 73  -- restored when no saved volume exists
local FLASH_DISPLAY_SECS = 2.0   -- how long the transition flash stays visible

-- Brief flash HUD at top center (shown on mute/unmute transitions)
local function showFlashHUD(isMuted)
    if flashCanvas then
        flashCanvas:delete()
        flashCanvas = nil
    end

    local mainScreen = hs.screen.mainScreen()
    local frame = mainScreen:frame()

    local width = 300
    local height = 65
    local x = frame.x + (frame.w - width) / 2
    local y = frame.y + 40

    flashCanvas = hs.canvas.new({x = x, y = y, w = width, h = height})

    local bgColor = isMuted and {red = 0.88, green = 0.18, blue = 0.18, alpha = 0.92}
                           or {red = 0.18, green = 0.78, blue = 0.38, alpha = 0.92}
    local textStr = isMuted and "🎙️ MIC MUTED" or "🎙️ MIC LIVE"

    flashCanvas[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = bgColor,
        roundedRectRadii = {xRadius = 14, yRadius = 14}
    }
    flashCanvas[2] = {
        type = "text",
        text = textStr,
        textColor = {white = 1.0, alpha = 1.0},
        textSize = 20,
        textFont = ".AppleSystemUIFontBold",
        textAlignment = "center",
        frame = {x = 0, y = 18, w = width, h = height}
    }

    flashCanvas:level(hs.canvas.windowLevels.overlay)
    flashCanvas:show()

    hs.timer.doAfter(FLASH_DISPLAY_SECS, function()
        if flashCanvas then
            flashCanvas:delete()
            flashCanvas = nil
        end
    end)
end

-- Persistent pill in bottom-left corner (stays while mic is muted)
local function showMutedPill()
    if mutedPillCanvas then return end  -- already showing

    local mainScreen = hs.screen.mainScreen()
    local frame = mainScreen:frame()

    local width = 160
    local height = 36
    local x = frame.x + 16
    local y = frame.y + frame.h - height - 16

    mutedPillCanvas = hs.canvas.new({x = x, y = y, w = width, h = height})

    mutedPillCanvas[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = {red = 0.6, green = 0.1, blue = 0.1, alpha = 0.35},
        strokeColor = {red = 0.85, green = 0.2, blue = 0.2, alpha = 0.7},
        lineWidth = 1,
        roundedRectRadii = {xRadius = 18, yRadius = 18}
    }
    mutedPillCanvas[2] = {
        type = "text",
        text = "🎙️ MIC MUTED",
        textColor = {red = 0.95, green = 0.4, blue = 0.4, alpha = 1.0},
        textSize = 13,
        textFont = ".AppleSystemUIFontBold",
        textAlignment = "center",
        frame = {x = 0, y = 9, w = width, h = height}
    }

    mutedPillCanvas:level(hs.canvas.windowLevels.overlay)
    mutedPillCanvas:show()
end

local function hideMutedPill()
    if mutedPillCanvas then
        mutedPillCanvas:delete()
        mutedPillCanvas = nil
    end
end

-- Mute ALL input devices by setting their volume to 0.
-- Saves each device's current volume for later restoration.
local function muteAllInputs()
    savedInputVolumes = {}
    for _, dev in ipairs(hs.audiodevice.allInputDevices()) do
        local vol = dev:inputVolume() or 0
        if vol > 0 then
            savedInputVolumes[dev:uid() or dev:name()] = vol
            dev:setInputVolume(0)
        end
    end
end

-- Unmute ALL input devices by restoring their saved volumes.
local function unmuteAllInputs()
    for _, dev in ipairs(hs.audiodevice.allInputDevices()) do
        local key = dev:uid() or dev:name()
        local restoreVol = savedInputVolumes[key] or DEFAULT_INPUT_VOLUME
        dev:setInputVolume(restoreVol)
    end
end

function mute.isMuted()
    local dev = hs.audiodevice.defaultInputDevice()
    if dev then
        local vol = dev:inputVolume()
        return vol ~= nil and vol == 0
    end
    return false
end

function mute.toggleMute()
    if mute.isMuted() then
        unmuteAllInputs()
        hideMutedPill()
        hs.timer.doAfter(0, function() showFlashHUD(false) end)
        return false
    else
        muteAllInputs()
        showMutedPill()
        hs.timer.doAfter(0, function() showFlashHUD(true) end)
        return true
    end
end

function mute.setMute(state)
    if state then
        muteAllInputs()
        showMutedPill()
    else
        unmuteAllInputs()
        hideMutedPill()
    end
    hs.timer.doAfter(0, function() showFlashHUD(state) end)
    return state
end

-- Push to Talk support
function mute.startTalk()
    unmuteAllInputs()
    hideMutedPill()
    hs.timer.doAfter(0, function() showFlashHUD(false) end)
    return false
end

function mute.stopTalk()
    muteAllInputs()
    showMutedPill()
    hs.timer.doAfter(0, function() showFlashHUD(true) end)
    return true
end

return mute
