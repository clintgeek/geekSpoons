local attention = {}
local providers = {}

-- Cache attention state so /api/status stays fast.
-- Providers (AX traversal, LevelDB reads) can take 1-2+ seconds each,
-- which would block the 1-second status polling. Instead we refresh
-- in the background on a timer and serve cached data to callers.
local cachedState = {}
local refreshTimer = nil
local initialTimer = nil
local REFRESH_INTERVAL = 60  -- seconds between background refreshes

local function refresh()
    local newState = {}
    for appId, providerFn in pairs(providers) do
        -- Preserve loading state: don't let periodic refresh overwrite
        -- a loading marker with fallback data. The loading state is only
        -- cleared by refreshNow() after cache files are written.
        if cachedState[appId] and cachedState[appId].severity == "loading" then
            newState[appId] = cachedState[appId]
        else
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
    end
    cachedState = newState
end

function attention.register(appId, providerFn)
    providers[appId] = providerFn
end

function attention.getStatus()
    return cachedState
end

-- Immediately mark an app as not running (called on app termination).
function attention.markNotRunning(appId)
    cachedState[appId] = { severity = "unreadable", count = 0, label = "not running" }
end

-- Mark an app as loading (called when app launches, before cache data is ready).
function attention.markLoading(appId)
    cachedState[appId] = { severity = "loading", count = 0, label = "Loading..." }
    local dbg = io.open("/tmp/attention_refresh.log", "a")
    if dbg then dbg:write(os.date("%H:%M:%S") .. " markLoading(" .. appId .. ")\n") dbg:close() end
end

-- Trigger an immediate refresh, but only clear loading markers for apps
-- whose cache files have been freshly written with valid data.
-- This prevents falling back to stale data if the background script failed.
function attention.refreshNow()
    for appId, state in pairs(cachedState) do
        if state.severity == "loading" then
            local cachePath = "/tmp/" .. appId .. "_attention.json"
            local f = io.open(cachePath, "r")
            local valid = false
            if f then
                local content = f:read("*all")
                f:close()
                -- Check if the cache file has real data (no error field)
                if content and content ~= "" then
                    local data = hs.json.decode(content)
                    if data and not data.error then
                        valid = true
                    end
                end
            end
            if valid then
                cachedState[appId] = nil  -- cache is good, clear loading
            end
            -- else: cache is stale or errored, keep loading state
        end
    end
    refresh()
end

-- Start background refresh timer. Call once after all providers are registered.
-- Initial refresh is deferred so it doesn't block init.lua loading.
function attention.start()
    if refreshTimer then refreshTimer:stop() end
    _attentionInitialTimer = hs.timer.doAfter(3, refresh)
    refreshTimer = hs.timer.doEvery(REFRESH_INTERVAL, refresh)
end

return attention
