-- spotify.lua: Robust Spotify integration module with GEEKAMP v6.78 metadata
local spotify = {}

local function getSpotifyApp()
    -- Use hs.application to find Spotify without triggering a launch.
    -- We also require a main window so we don't talk to an app mid-quit.
    local app = hs.application.get("Spotify")
    if app and app:isRunning() and app:mainWindow() then
        return app
    end
    return nil
end

local function isSpotifyReady()
    return getSpotifyApp() ~= nil
end

local function runSpotifyScript(cmd)
    if not isSpotifyReady() then return nil end
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
    return isSpotifyReady()
end

function spotify.isPlaying()
    return runSpotifyScript("return (player state is playing)") or false
end

function spotify.playPause()
    if not isSpotifyReady() then return end
    runSpotifyScript("playpause")
end

function spotify.nextTrack()
    if not isSpotifyReady() then return end
    runSpotifyScript("next track")
end

function spotify.previousTrack()
    if not isSpotifyReady() then return end
    runSpotifyScript("previous track")
end

function spotify.toggleShuffle()
    if not isSpotifyReady() then return end
    local state = runSpotifyScript("return shuffling")
    local newState = not state
    runSpotifyScript(string.format("set shuffling to %s", tostring(newState)))
    return newState
end

function spotify.toggleRepeat()
    if not isSpotifyReady() then return end
    local state = runSpotifyScript("return repeating")
    local newState = not state
    runSpotifyScript(string.format("set repeating to %s", tostring(newState)))
    return newState
end

function spotify.likeCurrentTrack()
    if not isSpotifyReady() then return end
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
    if not isSpotifyReady() then return end
    local script
    if contextUri and contextUri ~= "" then
        script = string.format('tell application "Spotify" to play track "%s" in context "%s"', uri, contextUri)
    else
        script = string.format('tell application "Spotify" to play track "%s"', uri)
    end
    hs.task.new("/usr/bin/osascript", nil, {"-e", script}):start()
end

function spotify.getStatus()
    if not isSpotifyReady() then
        return {
            isRunning = false,
            isPlaying = false,
            track = "Spotify Not Running",
            artist = "Open Spotify to play",
            album = "",
            shuffle = false,
            repeatState = false,
            position = 0,
            duration = 0
        }
    end

    local track = runSpotifyScript("return name of current track") or "Unknown Track"
    local artist = runSpotifyScript("return artist of current track") or "Unknown Artist"
    local album = runSpotifyScript("return album of current track") or ""
    local playing = runSpotifyScript("return (player state is playing)") or false
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
