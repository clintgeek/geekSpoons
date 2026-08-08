-- audio.lua: Master macOS system audio controls and output device switcher
local audio = {}

function audio.getDefaultOutput()
    return hs.audiodevice.defaultOutputDevice()
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
        local nxt = math.min(100, cur + 5)
        dev:setVolume(nxt)
        return nxt
    end
    return 0
end

function audio.volumeDown()
    local dev = audio.getDefaultOutput()
    if dev then
        local cur = dev:volume() or 0
        local nxt = math.max(0, cur - 5)
        dev:setVolume(nxt)
        return nxt
    end
    return 0
end

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
        hs.alert.show("🔊 Output: " .. nextDev:name())
        return nextDev:name()
    end
    return "Speaker"
end

function audio.getStatus()
    local dev = audio.getDefaultOutput()
    return {
        name = dev and dev:name() or "Speaker",
        volume = audio.getVolume(),
        isMuted = audio.isMuted()
    }
end

return audio
