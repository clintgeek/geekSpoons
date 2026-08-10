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

function messages.getAttention()
    local script = [[
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

    local ok, appleOK, result = pcall(hs.osascript.javascript, script)
    if not ok or not appleOK then
        -- JXA itself failed — Chrome may not be running or doesn't have
        -- "Allow JavaScript from Apple Events" enabled
        local app = hs.application.get("Google Chrome")
        if app and app:isRunning() then
            return { severity = "unreadable", count = 0, label = "enable JS in Chrome" }
        end
        return { severity = "unreadable", count = 0, label = "not running" }
    end

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

return messages
