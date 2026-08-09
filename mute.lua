-- mute.lua: Microphone mute controller with HUD indicator
-- Uses input volume as a soft mute (0 = muted, restore previous volume on unmute)
-- because the Plugable Audio dock doesn't support hardware input muting via CoreAudio.

local mute = {}

local muteCanvas = nil
local savedInputVolume = nil  -- volume to restore on unmute
local DEFAULT_INPUT_VOLUME = 73  -- restored when no saved volume exists
local HUD_DISPLAY_SECS = 2.0     -- how long the mute HUD stays visible

local function showMuteHUD(isMuted)
    if muteCanvas then
        muteCanvas:delete()
        muteCanvas = nil
    end

    local mainScreen = hs.screen.mainScreen()
    local frame = mainScreen:frame()

    local width = 300
    local height = 65
    local x = frame.x + (frame.w - width) / 2
    local y = frame.y + 40

    muteCanvas = hs.canvas.new({x = x, y = y, w = width, h = height})

    local bgColor = isMuted and {red = 0.88, green = 0.18, blue = 0.18, alpha = 0.92}
                           or {red = 0.18, green = 0.78, blue = 0.38, alpha = 0.92}
    local textStr = isMuted and "🎙️ MIC MUTED" or "🎙️ MIC LIVE"

    muteCanvas[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = bgColor,
        roundedRectRadii = {xRadius = 14, yRadius = 14}
    }
    muteCanvas[2] = {
        type = "text",
        text = textStr,
        textColor = {white = 1.0, alpha = 1.0},
        textSize = 20,
        textFont = ".AppleSystemUIFontBold",
        textAlignment = "center",
        frame = {x = 0, y = 18, w = width, h = height}
    }

    muteCanvas:level(hs.canvas.levels.overlay)
    muteCanvas:show()

    hs.timer.doAfter(HUD_DISPLAY_SECS, function()
        if muteCanvas then
            muteCanvas:delete()
            muteCanvas = nil
        end
    end)
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
    local dev = hs.audiodevice.defaultInputDevice()
    if dev then
        local vol = dev:inputVolume() or 0
        if vol == 0 then
            -- Unmute: restore saved volume (or default)
            local restoreVol = savedInputVolume or DEFAULT_INPUT_VOLUME
            dev:setInputVolume(restoreVol)
            hs.timer.doAfter(0, function() showMuteHUD(false) end)
            return false
        else
            -- Mute: save current volume and set to 0
            savedInputVolume = vol
            dev:setInputVolume(0)
            hs.timer.doAfter(0, function() showMuteHUD(true) end)
            return true
        end
    end
    return false
end

function mute.setMute(state)
    local dev = hs.audiodevice.defaultInputDevice()
    if dev then
        if state then
            local vol = dev:inputVolume() or 0
            if vol > 0 then savedInputVolume = vol end
            dev:setInputVolume(0)
        else
            dev:setInputVolume(savedInputVolume or DEFAULT_INPUT_VOLUME)
        end
        hs.timer.doAfter(0, function() showMuteHUD(state) end)
        return state
    end
    return false
end

-- Push to Talk support
function mute.startTalk()
    local dev = hs.audiodevice.defaultInputDevice()
    if dev then
        dev:setInputVolume(savedInputVolume or DEFAULT_INPUT_VOLUME)
        hs.timer.doAfter(0, function() showMuteHUD(false) end)
        return false
    end
    return mute.isMuted()
end

function mute.stopTalk()
    local dev = hs.audiodevice.defaultInputDevice()
    if dev then
        local vol = dev:inputVolume() or 0
        if vol > 0 then savedInputVolume = vol end
        dev:setInputVolume(0)
        hs.timer.doAfter(0, function() showMuteHUD(true) end)
        return true
    end
    return mute.isMuted()
end

return mute
