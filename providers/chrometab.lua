-- providers/chrometab.lua: shared Chrome-tab attention probe.
--
-- The Messages and Outlook Web providers were the same provider twice: find a
-- Chrome tab by URL, run a snippet of JS in it to read an unread count, and map
-- the result to an attention state. Only the URLs, the snippet, and the wording
-- of the "no tab" label differed.
--
-- Requirements (same for every provider built on this):
--   1. Chrome must be running with a tab open on one of `urls`.
--   2. Chrome > View > Developer > Allow JavaScript from Apple Events (enabled).
--      If not, the JXA call fails and we report "enable JS in Chrome".

local chrometab = {}

local taskguard = require("taskguard")

-- Look Chrome up by bundle ID, never by name. hs.application.get()/find()
-- search by name with exact=false, and when nothing matches they fall through
-- to hs.window.find(), which calls allWindows() on *every* running
-- application -- a synchronous Accessibility IPC round-trip each. So the
-- "app isn't running" case, which these providers hit routinely, blocked
-- Hammerspoon's main thread for over a second every refresh and starved the
-- HTTP server. applicationsForBundleID() never does the window sweep.
local CHROME_BUNDLE_ID = "com.google.Chrome"

local function chromeRunning()
    local app = hs.application.applicationsForBundleID(CHROME_BUNDLE_ID)[1]
    return app ~= nil and app:isRunning()
end

-- Build the JXA program: walk every Chrome tab, and in the first one whose URL
-- matches, evaluate `js` and return its value.
local function buildScript(urls, js)
    local tests = {}
    for _, u in ipairs(urls) do
        table.insert(tests, string.format('url.indexOf(%q) !== -1', u))
    end

    return string.format([[
function run() {
    var chrome = Application("Google Chrome");
    var windows = chrome.windows();
    for (var i = 0; i < windows.length; i++) {
        var tabs = windows[i].tabs();
        for (var j = 0; j < tabs.length; j++) {
            var t = tabs[j];
            var url = t.url();
            if (url && (%s)) {
                try {
                    var count = chrome.execute(t, {javascript: %q});
                    return "FOUND:" + count;
                } catch(e) {
                    return "ERROR:" + e.message;
                }
            }
        }
    }
    return "NOTFOUND";
}
]], table.concat(tests, " || "), js)
end

-- chrometab.new{ urls = {...}, js = "...", missingLabel = "...", timeout = 15 }
--   -> getAttention()
--
-- The JXA Chrome probe is slow (~500ms), so it runs asynchronously in an
-- osascript subprocess and updates a cache; getAttention() kicks off a refresh
-- (if one isn't already in flight) and returns the cached result.
function chrometab.new(opts)
    local script = buildScript(opts.urls, opts.js)
    local missingLabel = opts.missingLabel or "no tab"
    -- Single-flight runner: holds the task reference and terminates a probe
    -- that hangs, so a wedged osascript can't stop this provider refreshing.
    local runProbe = taskguard.new(opts.timeout or 15)

    local cachedResult = { severity = "unreadable", count = 0, label = "no data" }

    local function buildResult(result)
        local found = result and result:match("^FOUND:(.+)$")
        if found then
            local count = tonumber(found) or 0
            if count > 0 then
                return { severity = "attention", count = count, label = count .. " unread" }
            end
            return { severity = "none", count = 0, label = "" }
        end

        -- result is "NOTFOUND" or "ERROR:..." — no matching tab open
        if result and result:match("^ERROR:") then
            return { severity = "unreadable", count = 0, label = "JS execution failed" }
        end

        return { severity = "unreadable", count = 0, label = missingLabel }
    end

    return function()
        runProbe("/usr/bin/osascript", { "-l", "JavaScript", "-e", script },
            function(exitCode, stdOut, stdErr)
                if exitCode ~= 0 then
                    -- JXA itself failed — Chrome may not be running, or doesn't
                    -- have "Allow JavaScript from Apple Events" enabled
                    if chromeRunning() then
                        cachedResult = { severity = "unreadable", count = 0, label = "enable JS in Chrome" }
                    else
                        cachedResult = { severity = "unreadable", count = 0, label = "not running" }
                    end
                    return
                end
                cachedResult = buildResult(stdOut and stdOut:gsub("%s+$", "") or "")
            end)

        return cachedResult
    end
end

return chrometab
