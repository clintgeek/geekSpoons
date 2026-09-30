-- meeting.lua: Smart Universal Meeting Controls (Mic, Push-to-Talk, Camera Toggle across Zoom, Teams, Slack, Meet)
local meeting = {}

local CHROME_BUNDLE_ID = "com.google.Chrome"

-- Meeting apps in priority order, with camera-toggle and mute shortcuts.
-- Apps are identified by bundle ID, never by name. hs.application.get() searches
-- by name with exact=false, and on a miss it falls through to hs.window.find(),
-- which calls allWindows() on every running app -- a synchronous Accessibility
-- IPC round-trip each, ~1.5s in total on this machine. applicationsForBundleID()
-- never sweeps, and the list below is walked lazily so we stop at the first match.
--
-- requiresFocus marks an app that being *open* says nothing about. Chrome is
-- always running here (the messages and outlookweb attention providers need a
-- Chrome tab). Google Meet calls running in Chrome are directly detected and
-- controlled via Chrome JXA in the Meet tab without needing focus.
local MEETING_APPS = {
    { label = "Zoom",   camMods = {"cmd", "shift"}, camKey = "V",
      muteMods = {"alt"},  muteKey = "A",
      bundleIDs = {"us.zoom.xos"} },
    { label = "Teams",  camMods = {"cmd", "shift"}, camKey = "O",
      muteMods = {"cmd", "shift"}, muteKey = "M",
      bundleIDs = {"com.microsoft.teams2", "com.microsoft.teams"} },
    { label = "Slack",  camMods = {"cmd", "shift"}, camKey = "V",
      muteMods = {"cmd", "shift"}, muteKey = "M",
      bundleIDs = {"com.tinyspeck.slackmacgap"} },
    { label = "Webex",  camMods = {"cmd", "shift"}, camKey = "V",
      muteMods = {"cmd", "shift"}, muteKey = "M",
      bundleIDs = {"Cisco-Systems.Spark", "com.webex.meetingmanager"} },
    { label = "Meet",   camMods = {"cmd"},          camKey = "E",
      muteMods = {"cmd"},  muteKey = "D",
      bundleIDs = {CHROME_BUNDLE_ID}, requiresFocus = true },
}

local function isChromeRunning()
    local app = hs.application.applicationsForBundleID(CHROME_BUNDLE_ID)[1]
    return app ~= nil and app:isRunning()
end

-- Execute a meeting control action in an active Google Meet Chrome tab.
-- Supports:
--   "toggle_mic": toggle microphone mute state
--   "mute":       ensure microphone is muted (for PTT release)
--   "unmute":     ensure microphone is unmuted (for PTT press)
--   "toggle_cam": toggle camera state
--   "check":      check if an active Meet room tab exists
local function runMeetAction(action)
    if not isChromeRunning() then return false end

    local jxa = string.format([[
(function() {
    var chrome = Application("Google Chrome");
    if (!chrome.running()) return "not_running";

    var wins = chrome.windows();
    var targetTab = null;
    for (var i = 0; i < wins.length; i++) {
        var tabs = wins[i].tabs();
        for (var j = 0; j < tabs.length; j++) {
            var u = tabs[j].url();
            if (u && /^https?:\/\/meet\.google\.com\/[a-z0-9_-]{3,}/i.test(u) &&
                !u.match(/^https?:\/\/meet\.google\.com\/(landing|about)/i)) {
                targetTab = tabs[j];
                break;
            }
        }
        if (targetTab) break;
    }
    if (!targetTab) return "not_found";

    var fn = function(act) {
        var closeBtn = document.querySelector("[role=dialog] button[aria-label=Close]");
        if (closeBtn) closeBtn.click();

        function getMic() {
            return document.querySelector("button[jsname=hw0c9]") ||
                   document.querySelector("button[data-is-muted][aria-label*='microphone' i]") ||
                   document.querySelector("button[data-is-muted][aria-label*='mic' i]") ||
                   document.querySelector("button[aria-label*='microphone' i]") ||
                   document.querySelector("button[data-tooltip*='⌘ + d' i], button[data-tooltip*='ctrl + d' i]");
        }
        function getCam() {
            return document.querySelector("button[jsname=psRWwc]") ||
                   document.querySelector("button[data-is-muted][aria-label*='camera' i]") ||
                   document.querySelector("button[aria-label*='camera' i]") ||
                   document.querySelector("button[data-tooltip*='⌘ + e' i], button[data-tooltip*='ctrl + e' i]");
        }

        if (act === "toggle_mic") {
            var b = getMic();
            if (b) { b.click(); return "toggled"; }
            return "no_btn";
        }
        if (act === "unmute") {
            var b = getMic();
            if (!b) return "no_btn";
            var muted = b.getAttribute("data-is-muted") === "true" ||
                        (b.getAttribute("aria-label") || "").toLowerCase().indexOf("turn on microphone") !== -1;
            if (muted) { b.click(); return "unmuted"; }
            return "already_unmuted";
        }
        if (act === "mute") {
            var b = getMic();
            if (!b) return "no_btn";
            var muted = b.getAttribute("data-is-muted") === "true" ||
                        (b.getAttribute("aria-label") || "").toLowerCase().indexOf("turn on microphone") !== -1;
            if (!muted) { b.click(); return "muted"; }
            return "already_muted";
        }
        if (act === "toggle_cam") {
            var b = getCam();
            if (b) { b.click(); return "toggled"; }
            return "no_btn";
        }
        if (act === "check") {
            return (getMic() || getCam()) ? "active" : "tab_found";
        }
        return "unknown";
    };

    var code = "(" + fn.toString() + ")('" + %q + "')";
    return chrome.execute(targetTab, {javascript: code});
})()
]], action)

    local ok, res = hs.osascript.javascript(jxa)
    if ok and (res == "toggled" or res == "muted" or res == "unmuted" or res == "already_muted" or res == "already_unmuted") then
        return true
    end
    return false
end

local function findRunning(bundleIDs)
    for _, id in ipairs(bundleIDs) do
        local app = hs.application.applicationsForBundleID(id)[1]
        if app and app:isRunning() then return app end
    end
    return nil
end

local function entryForBundleID(id)
    if not id then return nil end
    for _, entry in ipairs(MEETING_APPS) do
        for _, candidate in ipairs(entry.bundleIDs) do
            if candidate == id then return entry end
        end
    end
    return nil
end

-- If a dedicated native meeting app (Zoom, Teams, Slack, Webex) is currently frontmost,
-- send controls directly to it.
local function isFrontMeetingApp()
    local front = hs.application.frontmostApplication()
    if not front then return nil end
    local bundleID = front:bundleID()
    if bundleID == CHROME_BUNDLE_ID then return nil end
    local entry = entryForBundleID(bundleID)
    if entry then
        return entry, front
    end
    return nil
end

-- Choose which app a meeting keystroke should go to.
--
-- macOS does not tell us which process owns the camera -- hs.camera only
-- reports a boolean isInUse() -- so there is no way to ask "who is in the
-- meeting". The best available signals, in order:
--
--   1. The frontmost app, if it is a meeting app. If you are looking at it,
--      that is the meeting you mean.
--   2. Otherwise the first *running* meeting app in MEETING_APPS order,
--      skipping requiresFocus entries.
local function pickMeetingApp()
    local front = hs.application.frontmostApplication()
    if front then
        local entry = entryForBundleID(front:bundleID())
        if entry then return entry, front end
    end

    for _, entry in ipairs(MEETING_APPS) do
        if not entry.requiresFocus then
            local app = findRunning(entry.bundleIDs)
            if app then return entry, app end
        end
    end

    return nil
end

-- Smart Camera Toggle for active meeting app (Google Meet, Teams, Zoom, Slack, Webex)
function meeting.toggleCamera()
    -- 1. Non-Chrome meeting app focused
    local frontEntry, frontApp = isFrontMeetingApp()
    if frontEntry then
        hs.eventtap.keyStroke(frontEntry.camMods, frontEntry.camKey, 0, frontApp)
        hs.alert.show("📹 " .. frontEntry.label .. " Camera Toggled", 1)
        return
    end

    -- 2. Google Meet active call in Chrome
    if runMeetAction("toggle_cam") then
        hs.alert.show("📹 Google Meet Camera Toggled", 1)
        return
    end

    -- 3. Running meeting app fallback (e.g. Teams)
    local entry, app = pickMeetingApp()
    if not entry then
        hs.alert.show("📹 No meeting app detected", 1)
        return
    end
    hs.eventtap.keyStroke(entry.camMods, entry.camKey, 0, app)
    hs.alert.show("📹 " .. entry.label .. " Camera Toggled", 1)
end

-- Smart Mute Toggle for active meeting app
function meeting.toggleMute()
    local frontEntry, frontApp = isFrontMeetingApp()
    if frontEntry then
        hs.eventtap.keyStroke(frontEntry.muteMods, frontEntry.muteKey, 0, frontApp)
        return
    end

    if runMeetAction("toggle_mic") then
        return
    end

    local entry, app = pickMeetingApp()
    if not entry then return end
    hs.eventtap.keyStroke(entry.muteMods, entry.muteKey, 0, app)
end

-- Push to Talk: Start talking (unmute)
function meeting.startTalk()
    local frontEntry, frontApp = isFrontMeetingApp()
    if frontEntry then
        hs.eventtap.keyStroke(frontEntry.muteMods, frontEntry.muteKey, 0, frontApp)
        return
    end

    if runMeetAction("unmute") then
        return
    end

    local entry, app = pickMeetingApp()
    if not entry then return end
    hs.eventtap.keyStroke(entry.muteMods, entry.muteKey, 0, app)
end

-- Push to Talk: Stop talking (mute)
function meeting.stopTalk()
    local frontEntry, frontApp = isFrontMeetingApp()
    if frontEntry then
        hs.eventtap.keyStroke(frontEntry.muteMods, frontEntry.muteKey, 0, frontApp)
        return
    end

    if runMeetAction("mute") then
        return
    end

    local entry, app = pickMeetingApp()
    if not entry then return end
    hs.eventtap.keyStroke(entry.muteMods, entry.muteKey, 0, app)
end

return meeting
