-- meeting.lua: Smart Universal Meeting Controls (Mic, Push-to-Talk, Camera Toggle across Zoom, Teams, Slack, Meet)
local meeting = {}

local mute = require("mute")

-- Smart Camera Toggle for active meeting app
function meeting.toggleCamera()
    -- Check running meeting applications
    local zoom = hs.application.get("zoom.us") or hs.application.get("Zoom")
    local teams = hs.application.get("Microsoft Teams") or hs.application.get("Teams")
    local slack = hs.application.get("Slack")
    local chrome = hs.application.get("Google Chrome")
    local webex = hs.application.get("Cisco Webex Meetings") or hs.application.get("Webex")

    if zoom and zoom:isRunning() then
        -- Zoom shortcut: Cmd + Shift + V
        hs.eventtap.keyStroke({"cmd", "shift"}, "V", 0, zoom)
        hs.alert.show("📹 Zoom Camera Toggled", 1)
    elseif teams and teams:isRunning() then
        -- Teams shortcut: Cmd + Shift + O
        hs.eventtap.keyStroke({"cmd", "shift"}, "O", 0, teams)
        hs.alert.show("📹 Teams Camera Toggled", 1)
    elseif slack and slack:isRunning() then
        -- Slack Huddles shortcut: Cmd + Shift + V
        hs.eventtap.keyStroke({"cmd", "shift"}, "V", 0, slack)
        hs.alert.show("📹 Slack Camera Toggled", 1)
    elseif webex and webex:isRunning() then
        -- Webex shortcut: Cmd + Shift + V
        hs.eventtap.keyStroke({"cmd", "shift"}, "V", 0, webex)
        hs.alert.show("📹 Webex Camera Toggled", 1)
    elseif chrome and chrome:isRunning() then
        -- Google Meet (Chrome) shortcut: Cmd + E
        hs.eventtap.keyStroke({"cmd"}, "E", 0, chrome)
        hs.alert.show("📹 Meet Camera Toggled", 1)
    else
        -- Fallback: Send Cmd + Shift + V to active window
        hs.eventtap.keyStroke({"cmd", "shift"}, "V")
        hs.alert.show("📹 Camera Toggled", 1)
    end
end

return meeting
