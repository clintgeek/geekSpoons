-- mute.lua: Microphone hardware mute controller with HUD indicator
local mute = {}

local muteCanvas = nil

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

    hs.timer.doAfter(2.0, function()
        if muteCanvas then
            muteCanvas:delete()
            muteCanvas = nil
        end
    end)
end

function mute.isMuted()
    local dev = hs.audiodevice.defaultInputDevice()
    if dev then
        return dev:muted()
    end
    return false
end

function mute.toggleMute()
    local dev = hs.audiodevice.defaultInputDevice()
    if dev then
        local newState = not dev:muted()
        dev:setMuted(newState)
        showMuteHUD(newState)
        return newState
    end
    return false
end

function mute.setMute(state)
    local dev = hs.audiodevice.defaultInputDevice()
    if dev then
        dev:setMuted(state)
        showMuteHUD(state)
        return state
    end
    return false
end

-- Push to Talk support
function mute.startTalk()
    local dev = hs.audiodevice.defaultInputDevice()
    if dev then
        dev:setMuted(false)
        showMuteHUD(false)
    end
end

function mute.stopTalk()
    local dev = hs.audiodevice.defaultInputDevice()
    if dev then
        dev:setMuted(true)
        showMuteHUD(true)
    end
end

return mute
