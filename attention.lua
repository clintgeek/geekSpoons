local attention = {}
local providers = {}

-- Cache attention state so /api/status stays fast.
-- Each provider has its own refresh timer with an interval tuned to how
-- expensive it is and how quickly its data changes. This avoids running
-- all providers on a single slow timer and lets fast providers update
-- more frequently without waiting for slow ones.

local cachedState = {}
local refreshTimers = {}

-- Per-provider refresh intervals (seconds).
-- Tuned for "live data" without blocking or resource drain:
--   slack/teams: 15s — node scripts run detached (non-blocking), safe to run often
--   outlook:     10s — AX AppleScript is ~200ms, cheap enough for main thread
--   messages:    15s — JXA Chrome probe is ~500ms, slightly heavier
local DEFAULT_INTERVAL = 15
local PROVIDER_INTERVALS = {
    slack = 15,
    teams = 15,
    outlook = 10,
    messages = 15,
}

-- Refresh a single provider and update its cached state.
-- Preserves loading state for a limited time: a periodic refresh won't
-- overwrite a loading marker for LOADING_TIMEOUT_SECS, after which the
-- loading state is cleared and the provider is re-evaluated.
local LOADING_TIMEOUT_SECS = 30  -- max time to show "Loading..." before giving up
local loadingSince = {}

local function refreshProvider(appId)
    if cachedState[appId] and cachedState[appId].severity == "loading" then
        -- Check if loading state has expired
        if loadingSince[appId] and (os.time() - loadingSince[appId]) < LOADING_TIMEOUT_SECS then
            return  -- still within the loading grace period
        end
        -- Loading has timed out — clear it and re-evaluate
        cachedState[appId] = nil
        loadingSince[appId] = nil
    end
    local providerFn = providers[appId]
    if not providerFn then return end

    local ok, result = pcall(providerFn)
    if ok and type(result) == "table" then
        cachedState[appId] = result
    else
        -- Truncate the debug log if it grows past 256KB so it can't
        -- fill /tmp during a long-running error condition.
        local logPath = "/tmp/attention_debug.log"
        local attrs = hs.fs.attributes(logPath)
        local mode = (attrs and attrs.size and attrs.size > 262144) and "w" or "a"
        local f = io.open(logPath, mode)
        if f then
            f:write(os.date("%H:%M:%S") .. " provider " .. appId .. " error: " .. tostring(result) .. "\n")
            f:close()
        end
        cachedState[appId] = { severity = "none", count = 0, label = "" }
    end
end

-- Refresh all providers (used by refreshNow after app launch).
local function refreshAll()
    for appId, _ in pairs(providers) do
        refreshProvider(appId)
    end
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
    loadingSince[appId] = os.time()
end

-- Trigger an immediate refresh of all providers, clearing all loading state.
-- Used after app launch sequences complete.
function attention.refreshNow()
    for appId, state in pairs(cachedState) do
        if state.severity == "loading" then
            cachedState[appId] = nil
        end
    end
    refreshAll()
end

-- Refresh a single provider immediately, clearing any loading state first.
-- Used by appWatcher settle timers after an app launches.
-- Clears loading unconditionally — the app has had time to settle, so we
-- should show real data even if the cache file still has an error from
-- the previous failed connection attempt.
function attention.refreshProvider(appId)
    if cachedState[appId] and cachedState[appId].severity == "loading" then
        cachedState[appId] = nil
    end
    refreshProvider(appId)
end

-- Start per-provider refresh timers. Call once after all providers are registered.
-- Timers are staggered so providers don't all fire at the same instant.
function attention.start()
    -- Stop any existing timers
    for _, timer in pairs(refreshTimers) do
        if timer then timer:stop() end
    end
    refreshTimers = {}

    local stagger = 0
    for appId, _ in pairs(providers) do
        local interval = PROVIDER_INTERVALS[appId] or DEFAULT_INTERVAL
        -- Stagger initial fire by 2s per provider so they don't collide
        local initialDelay = 3 + stagger
        stagger = stagger + 2

        -- Initial refresh (deferred so it doesn't block init.lua loading)
        hs.timer.doAfter(initialDelay, function()
            refreshProvider(appId)
        end)

        -- Ongoing refresh timer
        refreshTimers[appId] = hs.timer.doEvery(interval, function()
            refreshProvider(appId)
        end)
    end
end

return attention
