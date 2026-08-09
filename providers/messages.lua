-- providers/messages.lua: Google Messages attention provider
-- Uses Chrome's JavaScript execution (via JXA) to read the unread count
-- from the Google Messages web page DOM.
--
-- Requires: Chrome > View > Developer > Allow JavaScript from Apple Events (enabled)
-- The Chrome PWA runs as a Google Chrome process with a Google Messages tab.
-- We execute JS to count "a.list-item" elements that contain ".unread" children,
-- which represent unique conversations with unread messages.

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
                    return "ERROR";
                }
            }
        }
    }
    return "NOTFOUND";
}
]]

    local ok, appleOK, result = pcall(hs.osascript.javascript, script)
    if not ok or not appleOK then
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

    return { severity = "unreadable", count = 0, label = "not running" }
end

return messages
