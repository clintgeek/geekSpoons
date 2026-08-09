local calendar = {}

local env = require("env")
local ICS_URL = env.get("CALENDAR_ICS_URL") or ""
local SCRIPT_PATH = os.getenv("HOME") .. "/.hammerspoon/scripts/calendar_ics.js"
local REFRESH_INTERVAL = 60

local cachedState = { available = false, title = "Loading calendar..." }
local refreshTimer = nil
local running = false

local function nodeBin()
    local p = hs.execute("which node 2>/dev/null") or ""
    return p:gsub("%s+$", "")
end

local function refresh()
    if running then return end
    running = true

    local node = nodeBin()
    if node == "" then
        cachedState = { available = false, title = "node not found" }
        running = false
        return
    end

    hs.task.new(node, function(exitCode, stdOut, stdErr)
        running = false
        if exitCode == 0 and stdOut and stdOut:gsub("%s+$", "") ~= "" then
            local data = hs.json.decode(stdOut)
            if data and type(data) == "table" then
                cachedState = data
            else
                cachedState = { available = false, title = "No upcoming events" }
            end
        else
            cachedState = { available = false, title = "Calendar unavailable" }
        end
    end, { SCRIPT_PATH, ICS_URL }):start()
end

function calendar.getStatus()
    return cachedState
end

function calendar.start()
    if refreshTimer then refreshTimer:stop() end
    refresh()
    refreshTimer = hs.timer.doEvery(REFRESH_INTERVAL, refresh)
end

return calendar
