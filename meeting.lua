-- meeting.lua: Smart Universal Meeting Controls (Mic, Push-to-Talk, Camera Toggle across Zoom, Teams, Slack, Meet)
local meeting = {}

local mute = require("mute")

-- Meeting apps in priority order, with the camera-toggle shortcut each one uses.
-- Apps are identified by bundle ID, never by name. hs.application.get() searches
-- by name with exact=false, and on a miss it falls through to hs.window.find(),
-- which calls allWindows() on every running app -- a synchronous Accessibility
-- IPC round-trip each, ~1.5s in total on this machine. The old code did nine
-- name lookups up front, five of which missed (notably "Microsoft Teams": the
-- running app is actually named "MSTeams"), so a camera toggle spent ~7s in AX
-- sweeps before it sent a single keystroke. applicationsForBundleID() never
-- sweeps, and the list below is walked lazily so we stop at the first match.
local MEETING_APPS = {
    { label = "Zoom",   mods = {"cmd", "shift"}, key = "V",
      bundleIDs = {"us.zoom.xos"} },
    { label = "Teams",  mods = {"cmd", "shift"}, key = "O",
      bundleIDs = {"com.microsoft.teams2", "com.microsoft.teams"} },
    { label = "Slack",  mods = {"cmd", "shift"}, key = "V",
      bundleIDs = {"com.tinyspeck.slackmacgap"} },
    { label = "Webex",  mods = {"cmd", "shift"}, key = "V",
      bundleIDs = {"Cisco-Systems.Spark", "com.webex.meetingmanager"} },
    { label = "Meet",   mods = {"cmd"},          key = "E",
      bundleIDs = {"com.google.Chrome"} },
}

local function findRunning(bundleIDs)
    for _, id in ipairs(bundleIDs) do
        local app = hs.application.applicationsForBundleID(id)[1]
        if app and app:isRunning() then return app end
    end
    return nil
end

-- Smart Camera Toggle for active meeting app
function meeting.toggleCamera()
    for _, entry in ipairs(MEETING_APPS) do
        local app = findRunning(entry.bundleIDs)
        if app then
            hs.eventtap.keyStroke(entry.mods, entry.key, 0, app)
            hs.alert.show("📹 " .. entry.label .. " Camera Toggled", 1)
            return
        end
    end
    -- Fallback: Send Cmd + Shift + V to active window
    hs.eventtap.keyStroke({"cmd", "shift"}, "V")
    hs.alert.show("📹 Camera Toggled", 1)
end

return meeting
