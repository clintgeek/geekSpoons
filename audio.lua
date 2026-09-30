-- audio.lua: Master macOS system audio & microphone device switcher
local audio = {}

local VOLUME_STEP = 5  -- percent change per volume up/down press

function audio.getDefaultOutput()
    return hs.audiodevice.defaultOutputDevice()
end

function audio.getDefaultInput()
    return hs.audiodevice.defaultInputDevice()
end

function audio.getVolume()
    local dev = audio.getDefaultOutput()
    if dev then
        return math.floor(dev:volume() or 0)
    end
    return 0
end

function audio.isMuted()
    local dev = audio.getDefaultOutput()
    if dev then
        return dev:muted() or false
    end
    return false
end

function audio.toggleMute()
    local dev = audio.getDefaultOutput()
    if dev then
        local newState = not dev:muted()
        dev:setMuted(newState)
        return newState
    end
    return false
end

function audio.volumeUp()
    local dev = audio.getDefaultOutput()
    if dev then
        local cur = dev:volume() or 0
        local nxt = math.min(100, cur + VOLUME_STEP)
        dev:setVolume(nxt)
        return nxt
    end
    return 0
end

function audio.volumeDown()
    local dev = audio.getDefaultOutput()
    if dev then
        local cur = dev:volume() or 0
        local nxt = math.max(0, cur - VOLUME_STEP)
        dev:setVolume(nxt)
        return nxt
    end
    return 0
end

-- Synchronized Output & Input Device Switcher
function audio.cycleOutput()
    local outputs = hs.audiodevice.allOutputDevices()
    if #outputs <= 1 then
        if #outputs == 1 then
            return outputs[1]:name()
        end
        return "Default Speaker"
    end

    local current = audio.getDefaultOutput()
    local nextIndex = 1

    for i, dev in ipairs(outputs) do
        if current and dev:uid() == current:uid() then
            nextIndex = (i % #outputs) + 1
            break
        end
    end

    local nextDev = outputs[nextIndex]
    if nextDev then
        nextDev:setDefaultOutputDevice()
        
        -- Also match and set corresponding input device (e.g. AirPods, USB mic, headset)
        local devName = nextDev:name()
        local inputs = hs.audiodevice.allInputDevices()
        local matchedInput = false
        for _, inDev in ipairs(inputs) do
            if inDev:name() == devName or string.find(inDev:name(), devName, 1, true) or string.find(devName, inDev:name(), 1, true) then
                inDev:setDefaultInputDevice()
                matchedInput = true
                break
            end
        end

        if matchedInput then
            hs.alert.show("🎧 Audio & Mic: " .. devName)
        else
            hs.alert.show("🔊 Output: " .. devName)
        end
        return devName
    end
    return "Speaker"
end

-- Only the fields the dashboard actually renders. This runs on every
-- /api/status poll (once a second), so the input-device lookup that fed the
-- unused inputName/inputVolume fields was a per-second CoreAudio query for
-- data nothing displayed.
function audio.getStatus()
    local outDev = audio.getDefaultOutput()
    return {
        name = outDev and outDev:name() or "Speaker",
        volume = audio.getVolume(),
        isMuted = audio.isMuted()
    }
end

return audio
