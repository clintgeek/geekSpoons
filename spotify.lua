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

-- Escape a string for safe use inside AppleScript double-quoted strings.
local function applescriptEscape(s)
    return (s:gsub('\\', '\\\\'):gsub('"', '\\"'))
end

function spotify.playURI(uri, contextUri)
    if not isSpotifyReady() then return end
    local script
    if contextUri and contextUri ~= "" then
        script = string.format('tell application "Spotify" to play track "%s" in context "%s"',
            applescriptEscape(uri), applescriptEscape(contextUri))
    else
        script = string.format('tell application "Spotify" to play track "%s"',
            applescriptEscape(uri))
    end
    hs.task.new("/usr/bin/osascript", nil, {"-e", script}):start()
end

-- Batch all status fields into a single AppleScript call to avoid
-- 7 separate synchronous round-trips per poll.
-- Returns values as a tab-delimited string, parsed in Lua.
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

    local script = [[
        tell application "Spotify"
            if it is running then
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set isPlaying to (player state is playing) as string
                set isShuffling to shuffling as string
                set isRepeating to repeating as string
                set pos to player position
                set dur to (duration of current track) / 1000
                return trackName & "\t" & artistName & "\t" & albumName & "\t" & isPlaying & "\t" & isShuffling & "\t" & isRepeating & "\t" & pos & "\t" & dur
            end if
        end tell
        return ""
    ]]
    local ok, result = hs.applescript(script)
    if not ok or not result or result == "" then
        return {
            isRunning = true,
            isPlaying = false,
            track = "Unknown Track",
            artist = "Unknown Artist",
            album = "",
            shuffle = false,
            repeatState = false,
            position = 0,
            duration = 0
        }
    end

    -- Parse tab-delimited result
    local fields = {}
    for field in result:gmatch("[^\t]+") do
        table.insert(fields, field)
    end

    local function boolField(s)
        return s == "true"
    end

    return {
        isRunning = true,
        isPlaying = boolField(fields[4] or ""),
        track = fields[1] or "Unknown Track",
        artist = fields[2] or "Unknown Artist",
        album = fields[3] or "",
        shuffle = boolField(fields[5] or ""),
        repeatState = boolField(fields[6] or ""),
        position = math.floor(tonumber(fields[7]) or 0),
        duration = math.floor(tonumber(fields[8]) or 0)
    }
end

return spotify
