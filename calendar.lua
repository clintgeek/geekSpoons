local calendar = {}

local env = require("env")
local nodebin = require("nodebin")
local ICS_URL = env.get("CALENDAR_ICS_URL") or ""
local SCRIPT_PATH = os.getenv("HOME") .. "/.hammerspoon/scripts/calendar_ics.js"
local REFRESH_INTERVAL = 60 -- 1 minute in seconds

local cachedState = { available = false, title = "Loading calendar..." }
local refreshTimer = nil
local running = false
local taskRef = nil -- keep hs.task alive so GC doesn't collect it before completion

local function refresh()
    if running then return end
    running = true

    local node = nodebin.path()
    if not node then
        cachedState = { available = false, title = "node not found" }
        running = false
        print("[calendar] node not found")
        return
    end

    taskRef = hs.task.new(node, function(exitCode, stdOut, stdErr)
        taskRef = nil -- clear ref after completion so it can be GC'd
        running = false
        if exitCode == 0 and stdOut and stdOut:gsub("%s+$", "") ~= "" then
            local ok, data = pcall(hs.json.decode, stdOut)
            if ok and data and type(data) == "table" then
                cachedState = data
            else
                cachedState = { available = false, title = "No upcoming events" }
            end
        else
            print("[calendar] refresh failed: exit=" .. tostring(exitCode) .. " stderr=" .. tostring(stdErr))
            cachedState = { available = false, title = "Calendar unavailable" }
        end
    end, { SCRIPT_PATH, ICS_URL })
    taskRef:start()
end

function calendar.getStatus()
    return cachedState
end

function calendar.start()
    if refreshTimer then refreshTimer:stop() end
    if ICS_URL == "" then
        cachedState = { available = false, title = "No calendar URL configured" }
        print("[calendar] CALENDAR_ICS_URL not set in .env — calendar disabled")
        return
    end
    refresh()
    refreshTimer = hs.timer.doEvery(REFRESH_INTERVAL, refresh)
end

return calendar
