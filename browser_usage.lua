-- browser_usage.lua: Generic, non-blocking usage reader for authenticated web apps.
-- Runs AppleScript via hs.task so refresh never blocks the Hammerspoon main thread.
-- Providers configure a Chrome tab matcher, a JS fetch snippet, and a JSON parser.

local browser_usage = {}

local providers = {}
local cachedState = {}
local runningTasks = {}

local REFRESH_INTERVAL = 300  -- 5 minutes
local refreshTimer = nil

-- Write an AppleScript for a provider that searches browser tabs and executes JS.
-- Providers can specify browserApp (default: "Google Chrome"; use "Microsoft Edge" etc.).
local function buildAppleScript(jsCode)
    local app = jsCode.browserApp or "Google Chrome"
    local match2 = jsCode.tabMatch2 and (' and URL of t contains "' .. jsCode.tabMatch2 .. '"') or ''
    return 'tell application "' .. app .. '"\n' ..
        '    repeat with w in windows\n' ..
        '        repeat with t in tabs of w\n' ..
        '            if URL of t contains "' .. jsCode.tabMatch .. '"' .. match2 .. ' then\n' ..
        '                return execute t javascript "' .. jsCode.script .. '"\n' ..
        '            end if\n' ..
        '        end repeat\n' ..
        '    end repeat\n' ..
        'end tell'
end

-- Open an invisible browser window with the provider URL if no matching tab exists.
-- This lets the dashboard read authenticated usage pages without the user keeping tabs open.
local function buildTabOpener(jsCode)
    local app = jsCode.browserApp or "Google Chrome"
    local match2 = jsCode.tabMatch2 and (' and URL of t contains "' .. jsCode.tabMatch2 .. '"') or ''
    return 'tell application "' .. app .. '"\n' ..
        '    set found to false\n' ..
        '    repeat with w in windows\n' ..
        '        repeat with t in tabs of w\n' ..
        '            if URL of t contains "' .. jsCode.tabMatch .. '"' .. match2 .. ' then\n' ..
        '                set found to true\n' ..
        '            end if\n' ..
        '        end repeat\n' ..
        '    end repeat\n' ..
        '    if not found then\n' ..
        '        set w to make new window with properties {bounds:{-800, -600, -400, -200}}\n' ..
        '        set URL of active tab of w to "' .. jsCode.openUrl .. '"\n' ..
        '    end if\n' ..
        'end tell'
end

local function ensureProvider(id)
    local p = providers[id]
    if not p or not p.openUrl or p.openUrl == "" then return end

    local scpt = buildTabOpener(p)
    local tmp = os.tmpname() .. "_" .. id .. "_open.scpt"
    local f = io.open(tmp, "w")
    if not f then return end
    f:write(scpt)
    f:close()

    hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
        os.remove(tmp)
    end, { tmp }):start()
end

local function parseClaudeUsage(jsonStr)
    local data = hs.json.decode(jsonStr)
    if not data or data.error then
        return { available = false, error = data and data.error or "parse_error" }
    end

    local spend = data.spend
    if not spend then
        return { available = false, error = "no_spend_field" }
    end

    local function toDollars(amt)
        if not amt or not amt.amount_minor then return 0 end
        return amt.amount_minor / (10 ^ (amt.exponent or 2))
    end

    local spent = toDollars(spend.used)
    local limit = toDollars(spend.limit)

    return {
        available = true,
        spent = spent,
        limit = limit,
        percent = spend.percent or 0,
        severity = spend.severity or "normal",
        currency = (spend.used and spend.used.currency) or "USD",
        display = string.format("$%.2f / $%.2f", spent, limit)
    }
end

local function parseDevinUsage(text)
    if not text or text == "" then
        return { available = false, error = "empty_text" }
    end

    -- Extract usage percentages and balances from the rendered page text.
    -- Examples from Devin Usage & Limits:
    --   Daily quota
    --   10% used
    --   Weekly quota
    --   5% used
    --   Remaining balance
    --   $-0.03
    --   Your on-demand usage
    --   $0.00

    -- Use lazy patterns and %s- (any whitespace including newlines) so line endings
    -- don’t matter and we don’t depend on literal \n escape handling.
    local dailyPercent = text:match("Daily quota.-%s-(%d+)%% used")
    local weeklyPercent = text:match("Weekly quota.-%s-(%d+)%% used")
    local balance = text:match("Remaining balance.-%s-%$(%-?%d+%.%d%d)")
    local onDemand = text:match("Your on%-demand usage.-%s-%$(%-?%d+%.%d%d)")
    local plan = text:match("Current plan.-%s-([^%s]+)")

    if not dailyPercent and not weeklyPercent and not balance then
        return { available = false, error = "usage_data_not_found" }
    end

    local percent = 0
    if dailyPercent or weeklyPercent then
        percent = math.max(tonumber(dailyPercent) or 0, tonumber(weeklyPercent) or 0)
    end

    return {
        available = true,
        spent = tonumber(balance) or 0,
        limit = tonumber(onDemand) or 0,
        percent = percent,
        severity = percent >= 90 and "critical" or (percent >= 75 and "warning" or "normal"),
        currency = "USD",
        display = plan,
        label_detail = plan,
        quotas = {
            { label = "Daily", percent = tonumber(dailyPercent) or 0 },
            { label = "Weekly", percent = tonumber(weeklyPercent) or 0 }
        }
    }
end

local function parseGeminiUsage(text)
    if not text or text == "" then
        return { available = false, error = "empty_text" }
    end

    -- Gemini Usage limits page text examples:
    --   Usage limits
    --   PRO
    --   Current usage
    --   0% used
    --   Weekly limit
    --   0% used

    local plan = text:match("Usage limits%s-([^%s]+)")
    local currentPercent = text:match("Current usage%s-(%d+)%% used")
    local weeklyPercent = text:match("Weekly limit%s-(%d+)%% used")

    if not currentPercent and not weeklyPercent then
        return { available = false, error = "usage_data_not_found" }
    end

    local percent = math.max(tonumber(currentPercent) or 0, tonumber(weeklyPercent) or 0)

    return {
        available = true,
        spent = 0,
        limit = 0,
        percent = percent,
        severity = percent >= 90 and "critical" or (percent >= 75 and "warning" or "normal"),
        currency = "USD",
        display = plan or "Gemini",
        label_detail = plan,
        quotas = {
            { label = "Daily", percent = tonumber(currentPercent) or 0 },
            { label = "Weekly", percent = tonumber(weeklyPercent) or 0 }
        }
    }
end

-- Default providers -----------------------------------------------------------
providers.claude = {
    label = "Claude",
    color = "#E5B84B",  -- amber
    tabMatch = "claude.ai",
    openUrl = "https://claude.ai/new#settings/usage",
    script = '(function(){try{var e=performance.getEntriesByType(\\\"resource\\\");var o=null;for(var i=0;i<e.length;i++){var n=e[i].name;var m=\\\"/api/organizations/\\\";var idx=n.indexOf(m);if(idx>=0){var r=n.substring(idx+m.length);var s=r.indexOf(\\\"/usage\\\");if(s>0){o=r.substring(0,s);break;}}}if(!o)return JSON.stringify({error:\\\"org_id_not_found\\\"});var x=new XMLHttpRequest();x.open(\\\"GET\\\",\\\"/api/organizations/\\\"+o+\\\"/usage\\\",false);x.send();if(x.status===200){return x.responseText;}else{return JSON.stringify({error:\\\"http_\\\"+x.status});}}catch(err){return JSON.stringify({error:err.message});}})()',
    parse = parseClaudeUsage
}

providers.antigravity = {
    label = "Antigravity",
    color = "#4285F4",
    browserApp = "Microsoft Edge",
    tabMatch = "gemini.google.com",
    openUrl = "https://gemini.google.com/usage",
    tabMatch2 = "usage",
    script = 'document.body.innerText',
    parse = parseGeminiUsage
}

providers.devin = {
    label = "Devin",
    color = "#6366F1",
    tabMatch = "app.devin.ai",
    openUrl = "https://app.devin.ai/org/your-organization-ff31b9ec/settings/usage",
    tabMatch2 = "settings/usage",
    script = 'document.body.innerText',
    parse = parseDevinUsage
}

local function updateProvider(id, result)
    local p = providers[id]
    if not p then return end

    local status
    if not result or result == "" then
        status = { available = false, error = "Browser tab not found" }
    elseif p.parse then
        local ok, res = pcall(p.parse, result)
        if ok then
            status = res
        else
            status = { available = false, error = tostring(res) }
        end
    else
        status = { available = false, error = "no parser" }
    end

    -- Merge with defaults so callers always have all keys
    status.label = p.label
    status.color = p.color
    status._updated = os.time()
    cachedState[id] = status
    runningTasks[id] = nil
end

local function refreshProvider(id)
    local p = providers[id]
    if not p then return end

    if not p.script or p.script == "" then
        cachedState[id] = { available = false, error = "not configured", label = p.label, color = p.color, _updated = os.time() }
        return
    end

    if runningTasks[id] then
        -- Already refreshing; skip this cycle
        return
    end

    local scpt = buildAppleScript(p)
    local tmp = os.tmpname() .. "_" .. id .. "_usage.scpt"
    local f = io.open(tmp, "w")
    if not f then
        updateProvider(id, nil)
        return
    end
    f:write(scpt)
    f:close()

    runningTasks[id] = true

    local task = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
        os.remove(tmp)
        if exitCode == 0 then
            updateProvider(id, stdOut)
        else
            updateProvider(id, nil)
        end
    end, { tmp })

    task:start()
end

local function refreshAll()
    for id, _ in pairs(providers) do
        refreshProvider(id)
    end
end

function browser_usage.getStatus()
    local rows = {}
    local order = { "claude", "antigravity", "devin" }
    local now = os.time()
    local stale = 7200  -- 2 hours

    for _, id in ipairs(order) do
        local p = providers[id]
        local s = cachedState[id]
        local fresh = s and s._updated and (now - s._updated) < stale

        if s and s.available and fresh then
            local display
            if s.quotas then
                local dp = tonumber(s.quotas[1].percent) or 0
                local wp = tonumber(s.quotas[2].percent) or 0
                display = string.format("Daily: %d%%  Weekly: %d%%", dp, wp)
            else
                display = string.format("Monthly: $%.2f", s.spent or 0)
            end

            table.insert(rows, {
                label = p and p.label or id,
                color = p and p.color or "var(--text-muted)",
                display = display,
                percent = s.percent or 0,
                severity = s.severity or "normal",
                available = true
            })
        else
            table.insert(rows, {
                label = p and p.label or id,
                color = p and p.color or "var(--text-muted)",
                display = "UNKNOWN",
                percent = 0,
                severity = "normal",
                available = false
            })
        end
    end

    return rows
end

function browser_usage.start()
    if refreshTimer then refreshTimer:stop() end
    -- Open hidden windows for any provider that doesn't have a tab already.
    -- Give the pages time to load/auth before the first refresh.
    for id, _ in pairs(providers) do
        ensureProvider(id)
    end
    _browserUsageInitialTimer = hs.timer.doAfter(15, refreshAll)
    refreshTimer = hs.timer.doEvery(REFRESH_INTERVAL, refreshAll)
end

function browser_usage.register(id, config)
    providers[id] = config
    cachedState[id] = { available = false, error = "registered" }
end

return browser_usage
