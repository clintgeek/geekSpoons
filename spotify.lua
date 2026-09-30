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
    -- Find Spotify without triggering a launch.
    local app = hs.application.applicationsForBundleID(SPOTIFY_BUNDLE_ID)[1]
    if app and app:isRunning() then
        return app
    end
    return nil
end

local function isSpotifyReady()
    return getSpotifyApp() ~= nil
end

-- Run a Spotify AppleScript command off the main thread.
--
-- hs.applescript is synchronous, and every request the dashboard makes is
-- dispatched onto Hammerspoon's main queue -- so a blocking AppleScript
-- round-trip here stalls /api/status for every client. Playback commands are
-- fire-and-forget, so they go through osascript as an hs.task instead.
-- Tasks are held in a table until they exit; an unreferenced hs.task can be
-- collected mid-run and its callback never fires.
local liveTasks = {}
local nextTaskId = 0

local function runSpotifyAsync(cmd, onDone)
    if not isSpotifyReady() then
        if onDone then onDone(false) end
        return
    end
    local script = string.format([[
        tell application "Spotify"
            if it is running then
                %s
            end if
        end tell
    ]], cmd)

    nextTaskId = nextTaskId + 1
    local id = nextTaskId
    local task = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut)
        liveTasks[id] = nil
        if onDone then onDone(exitCode == 0, stdOut) end
    end, { "-e", script })
    if not task then
        if onDone then onDone(false) end
        return
    end
    liveTasks[id] = task
    task:start()
end

-- Status cache. /api/status is polled every second by the dashboard;
-- querying Spotify over AppleScript synchronously on every poll blocks
-- Hammerspoon's main thread. Instead a background osascript task
-- refreshes this cache every STATUS_REFRESH_INTERVAL seconds, and
-- getStatus() serves the cache, interpolating the playback position
-- from wall-clock time so the progress bar still advances smoothly.
local STATUS_REFRESH_INTERVAL = 2
local ACTION_REFRESH_DELAY = 0.4 -- re-poll shortly after an action so the UI updates fast
-- A refresh that never calls back would otherwise latch the in-flight guard
-- below forever and freeze the cache for the life of the session.
local STATUS_TASK_TIMEOUT = 10

local NOT_RUNNING_STATUS = {
    isRunning = false,
    isPlaying = false,
    track = "Spotify Not Running",
    artist = "Open Spotify to play",
    album = "",
    artworkUrl = "",
    shuffle = false,
    repeatState = false,
    position = 0,
    duration = 0
}

local cachedStatus = NOT_RUNNING_STATUS
local statusTimer = nil
local statusTaskRef = nil -- keep hs.task alive so GC doesn't collect it mid-run
local statusWatchdog = nil

-- Batch all status fields into a single AppleScript call to avoid
-- 7 separate synchronous round-trips per poll.
-- Returns values as a tab-delimited string, parsed in Lua.
--
-- Spotify hands us the real cover art for the current track, so there is no
-- need to guess it from an artist/album name search. `artwork url` is absent
-- for some items (local files, some podcasts), hence the try block.
local STATUS_SCRIPT = [[
    tell application "Spotify"
        if it is running then
            set trackName to ""
            set artistName to ""
            set albumName to ""
            set isPlaying to "false"
            set isShuffling to "false"
            set isRepeating to "false"
            set pos to 0
            set dur to 0
            set artURL to ""
            try
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set isPlaying to (player state is playing) as string
                set isShuffling to shuffling as string
                set isRepeating to repeating as string
                set pos to player position
                set dur to (duration of current track) / 1000
                set artURL to artwork url of current track
            end try
            if trackName is not "" then
                return trackName & "\t" & artistName & "\t" & albumName & "\t" & isPlaying & "\t" & isShuffling & "\t" & isRepeating & "\t" & pos & "\t" & dur & "\t" & artURL
            end if
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
        artworkUrl = fields[9] or "",
        fetchedAt = hs.timer.secondsSinceEpoch()
    }
end

local function clearStatusTask()
    statusTaskRef = nil
    if statusWatchdog then
        statusWatchdog:stop()
        statusWatchdog = nil
    end
end

local function refreshStatus()
    if statusTaskRef then return end -- refresh already in flight
    if not isSpotifyReady() then
        cachedStatus = NOT_RUNNING_STATUS
        return
    end

    statusTaskRef = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
        clearStatusTask()
        local result = stdOut and stdOut:gsub("%s+$", "") or ""
        if exitCode == 0 and result ~= "" then
            cachedStatus = parseStatus(result)
        else
            -- If a poll failed or returned empty (e.g. track transition, transient IPC delay),
            -- retain our valid cached metadata so the UI doesn't flash.
            -- Only mark not running if the Spotify process actually quit.
            if not isSpotifyReady() then
                cachedStatus = NOT_RUNNING_STATUS
            end
        end
    end, { "-e", STATUS_SCRIPT })
    if not statusTaskRef then return end
    statusTaskRef:start()

    -- Watchdog: osascript occasionally wedges when Spotify is mid-quit or the
    -- Apple Event never lands. Terminating clears the in-flight guard so the
    -- next tick can try again instead of the cache freezing permanently.
    statusWatchdog = hs.timer.doAfter(STATUS_TASK_TIMEOUT, function()
        local task = statusTaskRef
        statusWatchdog = nil
        if task then
            pcall(function() task:terminate() end)
            statusTaskRef = nil
        end
    end)
end

-- Schedule a near-term cache refresh after a user action (play/pause,
-- next, etc.) so the dashboard reflects the change on its next poll.
local function refreshSoon()
    hs.timer.doAfter(ACTION_REFRESH_DELAY, refreshStatus)
end

function spotify.isRunning()
    return isSpotifyReady()
end

function spotify.playPause()
    runSpotifyAsync("playpause", refreshSoon)
end

function spotify.nextTrack()
    runSpotifyAsync("next track", refreshSoon)
end

function spotify.previousTrack()
    runSpotifyAsync("previous track", refreshSoon)
end

-- Toggle from the cached state rather than reading it back from Spotify.
-- The old code did a synchronous read and inverted its result, so a failed
-- read (nil) inverted to true and silently switched the setting *on*.
function spotify.toggleShuffle()
    local newState = not cachedStatus.shuffle
    runSpotifyAsync(string.format("set shuffling to %s", tostring(newState)), refreshSoon)
    return newState
end

function spotify.toggleRepeat()
    local newState = not cachedStatus.repeatState
    runSpotifyAsync(string.format("set repeating to %s", tostring(newState)), refreshSoon)
    return newState
end

function spotify.likeCurrentTrack()
    runSpotifyAsync([[
                tell application "System Events"
                    tell process "Spotify"
                        click menu item "Save to Your Library" of menu "Song" of menu bar 1
                    end tell
                end tell
    ]])
end

-- Escape a string for safe use inside AppleScript double-quoted strings.
local function applescriptEscape(s)
    return (s:gsub('\\', '\\\\'):gsub('"', '\\"'))
end

function spotify.playURI(uri, contextUri)
    if not isSpotifyReady() then return end
    local cmd
    if contextUri and contextUri ~= "" then
        cmd = string.format('play track "%s" in context "%s"',
            applescriptEscape(uri), applescriptEscape(contextUri))
    else
        cmd = string.format('play track "%s"', applescriptEscape(uri))
    end
    runSpotifyAsync(cmd, refreshSoon)
end

-- Serve the cached status, interpolating position from elapsed wall-clock
-- time while playing so the progress bar advances between refreshes.
local endOfTrackPending = false

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
        if s.duration > 0 and pos >= s.duration then
            pos = s.duration
            -- The interpolated position has run out the clock, so Spotify has
            -- almost certainly moved on. Refresh now rather than showing the
            -- finished track until the next scheduled tick.
            if not endOfTrackPending then
                endOfTrackPending = true
                hs.timer.doAfter(0, refreshStatus)
            end
        else
            endOfTrackPending = false
        end
        s.position = math.floor(pos)
    else
        endOfTrackPending = false
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
