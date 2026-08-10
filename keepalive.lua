-- keepalive.lua: Bluetooth speaker keep-alive
-- Plays a near-silent audio file periodically to prevent Bluetooth
-- speakers (e.g., Klipsch) from auto-powering off due to inactivity.
-- Only runs when the target speaker is the active output device, so
-- it won't interfere with headset audio during meetings.

local keepalive = {}

local KEEPALIVE_AUDIO = hs.configdir .. "/assets/keepalive.wav"
local SPEAKER_NAME = "Klipsch"  -- substring match against output device name
local KEEPALIVE_INTERVAL = 300  -- seconds between keep-alive plays (5 min)
local keepaliveTimer = nil

local function isSpeakerActive()
    local dev = hs.audiodevice.defaultOutputDevice()
    if not dev then return false end
    local name = dev:name() or ""
    return name:lower():match(SPEAKER_NAME:lower()) ~= nil
end

local function playKeepalive()
    if not isSpeakerActive() then return end
    -- Play at very low volume via afplay (detached, non-blocking)
    hs.execute('afplay "' .. KEEPALIVE_AUDIO .. '" &')
end

function keepalive.start(interval)
    if keepaliveTimer then keepaliveTimer:stop() end
    local secs = interval or KEEPALIVE_INTERVAL
    keepaliveTimer = hs.timer.doEvery(secs, playKeepalive)
    -- Play once immediately on start
    playKeepalive()
end

function keepalive.stop()
    if keepaliveTimer then
        keepaliveTimer:stop()
        keepaliveTimer = nil
    end
end

return keepalive
