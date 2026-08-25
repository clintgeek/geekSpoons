-- spotify.lua: Robust Spotify integration module with GEEKAMP v6.78 metadata
local spotify = {}

-- Look Spotify up by bundle ID, never by name. hs.application.get() searches
-- by name with exact=false, and when nothing matches it falls through to
-- hs.window.find(), which calls allWindows() on *every* running application.
-- Each of those is a synchronous Accessibility IPC round-trip, so a name
-- lookup for an app that isn't running blocks Hammerspoon's main thread for
-- over a second. This runs every STATUS_REFRESH_INTERVAL seconds, so with
-- Spotify closed it starved the HTTP server and the dashboard lost its
-- connection. applicationsForBundleID() never does the window sweep.
local SPOTIFY_BUNDLE_ID = "com.spotify.client"

local function getSpotifyApp()
    -- Find Spotify without triggering a launch. We also require a main
    -- window so we don't talk to an app mid-quit.
    local app = hs.application.applicationsForBundleID(SPOTIFY_BUNDLE_ID)[1]
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

-- Status cache. /api/status is polled every second by the dashboard;
-- querying Spotify over AppleScript synchronously on every poll blocks
-- Hammerspoon's main thread. Instead a background osascript task
-- refreshes this cache every STATUS_REFRESH_INTERVAL seconds, and
-- getStatus() serves the cache, interpolating the playback position
-- from wall-clock time so the progress bar still advances smoothly.
local STATUS_REFRESH_INTERVAL = 2
local ACTION_REFRESH_DELAY = 0.4 -- re-poll shortly after an action so the UI updates fast

local NOT_RUNNING_STATUS = {
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

local cachedStatus = NOT_RUNNING_STATUS
local statusTimer = nil
local statusTaskRef = nil -- keep hs.task alive so GC doesn't collect it mid-run

-- Batch all status fields into a single AppleScript call to avoid
-- 7 separate synchronous round-trips per poll.
-- Returns values as a tab-delimited string, parsed in Lua.
local STATUS_SCRIPT = [[
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

-- Parse the tab-delimited status string, preserving empty fields
-- (e.g. an empty album name must not shift later fields).
local function parseStatus(result)
    local fields = {}
    for field in (result .. "\t"):gmatch("([^\t]*)\t") do
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
        position = tonumber(fields[7]) or 0,
        duration = math.floor(tonumber(fields[8]) or 0),
        fetchedAt = hs.timer.secondsSinceEpoch()
    }
end

local function refreshStatus()
    if statusTaskRef then return end -- refresh already in flight
    if not isSpotifyReady() then
        cachedStatus = NOT_RUNNING_STATUS
        return
    end

    statusTaskRef = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
        statusTaskRef = nil
        local result = stdOut and stdOut:gsub("%s+$", "") or ""
        if exitCode == 0 and result ~= "" then
            cachedStatus = parseStatus(result)
        else
            cachedStatus = {
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
    end, { "-e", STATUS_SCRIPT })
    statusTaskRef:start()
end

-- Schedule a near-term cache refresh after a user action (play/pause,
-- next, etc.) so the dashboard reflects the change on its next poll.
local function refreshSoon()
    hs.timer.doAfter(ACTION_REFRESH_DELAY, refreshStatus)
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
    refreshSoon()
end

function spotify.nextTrack()
    if not isSpotifyReady() then return end
    runSpotifyScript("next track")
    refreshSoon()
end

function spotify.previousTrack()
    if not isSpotifyReady() then return end
    runSpotifyScript("previous track")
    refreshSoon()
end

function spotify.toggleShuffle()
    if not isSpotifyReady() then return end
    local state = runSpotifyScript("return shuffling")
    local newState = not state
    runSpotifyScript(string.format("set shuffling to %s", tostring(newState)))
    refreshSoon()
    return newState
end

function spotify.toggleRepeat()
    if not isSpotifyReady() then return end
    local state = runSpotifyScript("return repeating")
    local newState = not state
    runSpotifyScript(string.format("set repeating to %s", tostring(newState)))
    refreshSoon()
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
    refreshSoon()
end

-- Serve the cached status, interpolating position from elapsed wall-clock
-- time while playing so the progress bar advances between refreshes.
function spotify.getStatus()
    if not isSpotifyReady() then
        cachedStatus = NOT_RUNNING_STATUS
        return cachedStatus
    end

    local s = {}
    for k, v in pairs(cachedStatus) do s[k] = v end
    s.fetchedAt = nil

    if cachedStatus.isPlaying and cachedStatus.fetchedAt then
        local pos = cachedStatus.position + (hs.timer.secondsSinceEpoch() - cachedStatus.fetchedAt)
        if s.duration > 0 and pos > s.duration then pos = s.duration end
        s.position = math.floor(pos)
    else
        s.position = math.floor(s.position or 0)
    end

    return s
end

function spotify.start()
    if statusTimer then statusTimer:stop() end
    refreshStatus()
    statusTimer = hs.timer.doEvery(STATUS_REFRESH_INTERVAL, refreshStatus)
end

return spotify
