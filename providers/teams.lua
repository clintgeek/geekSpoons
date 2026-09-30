-- providers/teams.lua: Microsoft Teams attention provider
-- Reads cached unread counts from a temp file populated by a background node
-- script that connects to Teams' Chrome DevTools Protocol on port 9223.
-- The provider triggers the node script on every refresh (asynchronously via
-- hs.task), then reads the cache file.

local teams = {}

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

local TEAMS_BUNDLE_ID = "com.microsoft.teams2"

local nodebin = require("nodebin")
local taskguard = require("taskguard")

local CACHE_FILE = "/tmp/teams_attention.json"
local REFRESH_SCRIPT = hs.configdir .. "/scripts/teams_unread.js"

-- Build the attention result from cached counts (people, meetings, channels).
-- DMs from people are urgent; everything else is attention-level.
local function buildResult(people, meetings, channels)
    local total = people + meetings + channels
    if total == 0 then
        return { severity = "none", count = 0, label = "" }
    end

    local parts = {}
    local segments = {}
    if meetings > 0 then
        table.insert(parts, meetings .. " mtg")
        table.insert(segments, { text = meetings .. " mtg", color = "amber" })
    end
    if people > 0 then
        table.insert(parts, people .. " dm")
        table.insert(segments, { text = people .. " dm", color = "red" })
    end
    if channels > 0 then
        table.insert(parts, channels .. " ch")
        table.insert(segments, { text = channels .. " ch", color = "amber" })
    end

    local label = table.concat(parts, " ")
    if people > 0 then
        return { severity = "urgent", count = total, label = label, segments = segments }
    end
    return { severity = "attention", count = total, label = label, segments = segments }
end

-- Read cached result from the background refresh script.
local function readCache()
    local f = io.open(CACHE_FILE, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    if not content or content == "" then return nil end

    local ok, data = pcall(hs.json.decode, content)
    if not ok or not data or data.error then return nil end

    return buildResult(data.people or 0, data.meetings or 0, data.channels or 0)
end

-- Fallback: read the dock badge for Teams via AXUIElement traversal.
local function readDockBadge()
    local dockApp = hs.application.find("Dock")
    if not dockApp then return nil end
    local dockElem = hs.axuielement.applicationElement(dockApp)
    if not dockElem then return nil end
    local children = dockElem:attributeValue("AXChildren")
    if not children then return nil end

    -- Find the AXList (the dock icons row)
    local dockList = nil
    for _, child in ipairs(children) do
        if child:attributeValue("AXRole") == "AXList" then
            dockList = child
            break
        end
    end
    if not dockList then return nil end

    -- Find the Teams icon and read its status badge
    local items = dockList:attributeValue("AXChildren")
    if not items then return nil end
    for _, item in ipairs(items) do
        local title = item:attributeValue("AXTitle")
        if title and tostring(title) == "Microsoft Teams" then
            local badge = item:attributeValue("AXStatusLabel")
            if badge then
                local count = tonumber(tostring(badge)) or 0
                if count > 0 then
                    return { severity = "attention", count = count, label = count .. " unread" }
                end
            end
            break
        end
    end
    return nil
end

-- Launch the node script to refresh the cache file, asynchronously.
-- hs.task, not hs.execute. hs.execute pipes the command through io.popen
-- and reads to EOF, and a trailing "&" does not help: the backgrounded
-- subshell inherits the pipe's write end, so the read blocks until the whole
-- chain exits. The node script takes ~3s, and that was 3s of Hammerspoon's
-- main thread — which the HTTP server needs, since every request is
-- dispatched synchronously onto the main queue. hs.task is genuinely async.
-- Single-flight runner: holds the task reference and terminates a node script
-- that hangs, so a wedged probe can't stop this provider refreshing for good.
local runRefresh = taskguard.new(20)

local function refreshCache()
    local node = nodebin.path()
    if not node then return end
    runRefresh(node, { REFRESH_SCRIPT }, function(exitCode, stdOut, stdErr)
        if exitCode ~= 0 or not stdOut or stdOut == "" then return end
        -- Write to a temp file and rename so readers never see a partial write.
        local tmp = CACHE_FILE .. ".tmp"
        local f = io.open(tmp, "w")
        if not f then return end
        f:write(stdOut)
        f:close()
        os.rename(tmp, CACHE_FILE)
    end)
end

function teams.getAttention()
    -- Use bundle ID to find the main Teams app, not the background agent process
    local app = findApp(TEAMS_BUNDLE_ID)
    if not app then
        return { severity = "unreadable", count = 0, label = "not running" }
    end
    -- Verify it's the main app (has a window), not just the background agent
    if not app:mainWindow() then
        return { severity = "unreadable", count = 0, label = "not running" }
    end

    -- Trigger a background cache refresh (non-blocking)
    refreshCache()

    -- Try cache first (instant file I/O), fall back to dock badge
    local result = readCache()
    if result then return result end

    result = readDockBadge()
    if result then return result end

    return { severity = "none", count = 0, label = "" }
end

return teams
