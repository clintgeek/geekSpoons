-- providers/messages.lua: Google Messages attention provider
-- Uses Chrome's JavaScript execution (via JXA) to read the unread count
-- from the Google Messages web page DOM.
--
-- Requirements:
--   1. Chrome must be running with a tab open on messages.google.com
--   2. Chrome > View > Developer > Allow JavaScript from Apple Events (enabled)
--      If not enabled, the JXA call fails and we return "enable JS in Chrome".
--   3. The Messages PWA (Chrome Apps.localized) is optional — any Chrome tab
--      with the Messages URL works.

local messages = {}

-- Look this app up by bundle ID, never by name. hs.application.get()/find()
-- search by name with exact=false, and when nothing matches they fall through
-- to hs.window.find(), which calls allWindows() on *every* running
-- application -- a synchronous Accessibility IPC round-trip each. So the
-- "app isn't running" case, which this provider hits routinely, blocked
-- Hammerspoon's main thread for over a second every refresh and starved the
-- HTTP server. applicationsForBundleID() never does the window sweep.
local function findApp(bundleID)
    return hs.application.applicationsForBundleID(bundleID)[1]
end

local CHROME_BUNDLE_ID = "com.google.Chrome"

-- The JXA Chrome probe is slow (~500ms), so it runs asynchronously in an
-- osascript subprocess and updates this cache; getAttention() kicks off
-- a refresh (if one isn't in flight) and returns the cached result.
local cachedResult = { severity = "unreadable", count = 0, label = "no data" }
local taskRef = nil -- keep hs.task alive so GC doesn't collect it mid-run

local JXA_SCRIPT = [[
function run() {
    var chrome = Application("Google Chrome");
    var windows = chrome.windows();
    for (var i = 0; i < windows.length; i++) {
        var tabs = windows[i].tabs();
        for (var j = 0; j < tabs.length; j++) {
            var t = tabs[j];
            if (t.url() && t.url().indexOf("messages.google.com") !== -1) {
                try {
                    var count = chrome.execute(t, {javascript: "var items=document.querySelectorAll('a.list-item');var n=0;for(var i=0;i<items.length;i++){if(items[i].querySelector('.unread'))n++}String(n)"});
                    return "FOUND:" + count;
                } catch(e) {
                    return "ERROR:" + e.message;
                }
            }
        }
    }
    return "NOTFOUND";
}
]]

local function buildResult(result)
    if result and result:match("^FOUND:(.+)$") then
        local count = tonumber(result:match("^FOUND:(.+)$")) or 0
        if count > 0 then
            return {
                severity = "attention",
                count = count,
                label = count .. " unread"
            }
        end
        return { severity = "none", count = 0, label = "" }
    end

    -- result is "NOTFOUND" or "ERROR:..." — no Messages tab open
    if result and result:match("^ERROR:") then
        return { severity = "unreadable", count = 0, label = "JS execution failed" }
    end

    return { severity = "unreadable", count = 0, label = "no Messages tab" }
end

function messages.getAttention()
    if not taskRef then
        taskRef = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
            taskRef = nil
            if exitCode ~= 0 then
                -- JXA itself failed — Chrome may not be running or doesn't
                -- have "Allow JavaScript from Apple Events" enabled
                local app = findApp(CHROME_BUNDLE_ID)
                if app and app:isRunning() then
                    cachedResult = { severity = "unreadable", count = 0, label = "enable JS in Chrome" }
                else
                    cachedResult = { severity = "unreadable", count = 0, label = "not running" }
                end
                return
            end
            cachedResult = buildResult(stdOut and stdOut:gsub("%s+$", "") or "")
        end, { "-l", "JavaScript", "-e", JXA_SCRIPT })
        taskRef:start()
    end

    return cachedResult
end

return messages
