-- providers/slack.lua: Slack attention provider
-- Reads cached unread counts from a temp file populated by a background node
-- script that connects to Slack's Chrome DevTools Protocol on port 9222.
-- The provider triggers the node script on every refresh (asynchronously via
-- hs.task), then reads the cache file.

local slack = {}

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

local SLACK_BUNDLE_ID = "com.tinyspeck.slackmacgap"

local nodebin = require("nodebin")

local CACHE_FILE = "/tmp/slack_attention.json"
local ROOT_STATE = os.getenv("HOME") .. "/Library/Application Support/Slack/storage/root-state.json"
local REFRESH_SCRIPT = hs.configdir .. "/scripts/slack_unread.js"

-- Launch the node script to refresh the cache file, asynchronously.
-- hs.task, not hs.execute. hs.execute pipes the command through io.popen
-- and reads to EOF, and a trailing "&" does not help: the backgrounded
-- subshell inherits the pipe's write end, so the read blocks until the whole
-- chain exits. The node script takes ~3s, and that was 3s of Hammerspoon's
-- main thread — which the HTTP server needs, since every request is
-- dispatched synchronously onto the main queue. hs.task is genuinely async.
local taskRef = nil -- keep the task alive so GC doesn't collect it mid-run

local function refreshCache()
    if taskRef then return end -- refresh already in flight
    local node = nodebin.path()
    if not node then return end
    taskRef = hs.task.new(node, function(exitCode, stdOut, stdErr)
        taskRef = nil
        if exitCode ~= 0 or not stdOut or stdOut == "" then return end
        -- Write to a temp file and rename so readers never see a partial write.
        local tmp = CACHE_FILE .. ".tmp"
        local f = io.open(tmp, "w")
        if not f then return end
        f:write(stdOut)
        f:close()
        os.rename(tmp, CACHE_FILE)
    end, { REFRESH_SCRIPT })
    taskRef:start()
end

function slack.getAttention()
    local app = findApp(SLACK_BUNDLE_ID)
    if not app then
        return { severity = "unreadable", count = 0, label = "not running" }
    end
    if not app:mainWindow() then
        return { severity = "unreadable", count = 0, label = "not running" }
    end

    -- Trigger a background cache refresh (non-blocking)
    refreshCache()

    -- Read the existing cache file (may be from the previous refresh cycle)
    local f = io.open(CACHE_FILE, "r")
    if f then
        local content = f:read("*all")
        f:close()
        if content and content ~= "" then
            local ok, data = pcall(hs.json.decode, content)
            if ok and data and not data.error then
                local channels = data.channels or 0
                local dms = data.dms or 0
                local total = channels + dms

                if total == 0 then
                    return { severity = "none", count = 0, label = "" }
                end

                local parts = {}
                local segments = {}
                if channels > 0 then
                    table.insert(parts, channels .. " ch")
                    table.insert(segments, { text = channels .. " ch", color = "amber" })
                end
                if dms > 0 then
                    table.insert(parts, dms .. " dm")
                    table.insert(segments, { text = dms .. " dm", color = "red" })
                end
                local label = table.concat(parts, " ")

                if dms > 0 then
                    return { severity = "urgent", count = total, label = label, segments = segments }
                end
                return { severity = "attention", count = total, label = label, segments = segments }
            end
        end
    end

    -- Fallback: root-state.json (fast file read, always available)
    local f2 = io.open(ROOT_STATE, "r")
    if f2 then
        local content = f2:read("*all")
        f2:close()
        local totalUnreads = 0
        local totalHighlights = 0
        for unreads in content:gmatch('"unreads":(%d+)') do
            totalUnreads = totalUnreads + tonumber(unreads)
        end
        for highlights in content:gmatch('"unreadHighlights":(%d+)') do
            totalHighlights = totalHighlights + tonumber(highlights)
        end
        if totalHighlights > 0 then
            return { severity = "urgent", count = totalUnreads, label = totalUnreads .. " unread (" .. totalHighlights .. " mention" .. (totalHighlights > 1 and "s" or "") .. ")" }
        end
        if totalUnreads > 0 then
            return { severity = "attention", count = totalUnreads, label = totalUnreads .. " unread" }
        end
        return { severity = "none", count = 0, label = "" }
    end
    return { severity = "unreadable", count = 0, label = "no data" }
end

return slack
