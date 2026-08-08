-- spotify.lua: Robust Spotify integration module with GEEKAMP v6.78 metadata
local spotify = {}

local function runSpotifyScript(cmd)
    local script = string.format([[
        tell application "Spotify"
            if it is running then
                %s
            end if
        end tell
    ]], cmd)
    local ok, res = hs.applescript(script)
    if ok then return res end
    return nil
end

function spotify.isRunning()
    return hs.spotify.isRunning() or false
end

local function ensureSpotifyRunning()
    if not spotify.isRunning() then
        hs.application.launchOrFocus("Spotify")
        return false
    end
    return true
end

function spotify.isPlaying()
    if not spotify.isRunning() then return false end
    local res = runSpotifyScript("return (player state is playing)")
    if res ~= nil then return res end
    return hs.spotify.isPlaying() or false
end

function spotify.playPause()
    if not ensureSpotifyRunning() then return end
    runSpotifyScript("playpause")
end

function spotify.nextTrack()
    if not ensureSpotifyRunning() then return end
    runSpotifyScript("next track")
end

function spotify.previousTrack()
    if not ensureSpotifyRunning() then return end
    runSpotifyScript("previous track")
end

function spotify.toggleShuffle()
    if not ensureSpotifyRunning() then return end
    local state = runSpotifyScript("return shuffling")
    local newState = not state
    runSpotifyScript(string.format("set shuffling to %s", tostring(newState)))
    return newState
end

function spotify.toggleRepeat()
    if not ensureSpotifyRunning() then return end
    local state = runSpotifyScript("return repeating")
    local newState = not state
    runSpotifyScript(string.format("set repeating to %s", tostring(newState)))
    return newState
end

function spotify.likeCurrentTrack()
    if not ensureSpotifyRunning() then return end
    local script = [[
        tell application "Spotify"
            if it is running then
                tell application "System Events"
                    tell process "Spotify"
                        click menu item "Save to Your Library" of menu "Song" of menu bar 1
                    end tell
                end tell
            end if
        end tell
    ]]
    hs.applescript(script)
end

function spotify.playURI(uri, contextUri)
    local script
    if contextUri and contextUri ~= "" then
        script = string.format('tell application "Spotify" to play track "%s" in context "%s"', uri, contextUri)
    else
        script = string.format('tell application "Spotify" to play track "%s"', uri)
    end
    hs.task.new("/usr/bin/osascript", nil, {"-e", script}):start()
end

function spotify.getStatus()
    if not spotify.isRunning() then
        return {
            isRunning = false,
            isPlaying = false,
            track = "GEEKAMP [PAUSED] - LAUNCH SPOTIFY",
            artist = "Launch Spotify App",
            album = "",
            shuffle = false,
            repeatState = false,
            position = 0,
            duration = 0
        }
    end

    local track = runSpotifyScript("return name of current track") or hs.spotify.getCurrentTrack() or "Unknown Track"
    local artist = runSpotifyScript("return artist of current track") or hs.spotify.getCurrentArtist() or "Unknown Artist"
    local album = runSpotifyScript("return album of current track") or hs.spotify.getCurrentAlbum() or ""
    local playing = spotify.isPlaying()
    local shuffle = runSpotifyScript("return shuffling") or false
    local repeatState = runSpotifyScript("return repeating") or false
    local pos = runSpotifyScript("return player position") or 0
    local dur = runSpotifyScript("return (duration of current track) / 1000") or 0

    return {
        isRunning = true,
        isPlaying = playing,
        track = track,
        artist = artist,
        album = album,
        shuffle = shuffle,
        repeatState = repeatState,
        position = math.floor(pos or 0),
        duration = math.floor(dur or 0)
    }
end

return spotify
