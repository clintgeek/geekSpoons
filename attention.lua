local attention = {}
local providers = {}

-- Cache attention state so /api/status stays fast.
-- Providers (AX traversal, LevelDB reads) can take 1-2+ seconds each,
-- which would block the 1-second status polling. Instead we refresh
-- in the background on a timer and serve cached data to callers.
local cachedState = {}
local refreshTimer = nil
local REFRESH_INTERVAL = 10  -- seconds between background refreshes

local function refresh()
    local newState = {}
    for appId, providerFn in pairs(providers) do
        local ok, result = pcall(providerFn)
        if ok and type(result) == "table" then
            newState[appId] = result
        else
            local f = io.open("/tmp/attention_debug.log", "a")
            if f then
                f:write(os.date("%H:%M:%S") .. " provider " .. appId .. " error: " .. tostring(result) .. "\n")
                f:close()
            end
            newState[appId] = { severity = "none", count = 0, label = "" }
        end
    end
    cachedState = newState
end

function attention.register(appId, providerFn)
    providers[appId] = providerFn
end

function attention.getStatus()
    return cachedState
end

-- Start background refresh timer. Call once after all providers are registered.
-- Initial refresh is deferred so it doesn't block init.lua loading.
function attention.start()
    if refreshTimer then refreshTimer:stop() end
    -- Defer initial refresh by 3 seconds to let Hammerspoon fully initialize
    hs.timer.doAfter(3, refresh)
    refreshTimer = hs.timer.doEvery(REFRESH_INTERVAL, refresh)
end

return attention
