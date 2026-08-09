-- claude_usage.lua: Reads Claude AI usage data from the authenticated Chrome session.
-- Uses Chrome's AppleScript JavaScript execution to fetch the usage API endpoint
-- from within the page's authenticated context. No API keys, no cookie decryption.
-- Requires: Chrome → View → Developer → Allow JavaScript from Apple Events enabled.
-- Requires: A claude.ai tab open in Chrome (any page, not just settings/usage).

local claude_usage = {}

local cachedStatus = {
    available = false,
    spent = 0,
    limit = 0,
    percent = 0,
    severity = "unknown",
    currency = "USD",
    error = "Not yet fetched"
}

local refreshTimer = nil
local REFRESH_INTERVAL = 300  -- 5 minutes

-- JavaScript executed inside the Chrome tab.
-- Uses simple string indexOf instead of regex to avoid AppleScript escaping issues.
-- In Lua: \\\" produces \" in the output, which AppleScript interprets as a literal "
-- In Lua: \\ produces \ in the output (for any backslashes needed in JS)
local JS_FETCH = '(function(){' ..
    'try{' ..
        'var e=performance.getEntriesByType(\\\"resource\\\");' ..
        'var o=null;' ..
        'for(var i=0;i<e.length;i++){' ..
            'var n=e[i].name;' ..
            'var m=\\\"/api/organizations/\\\";' ..
            'var idx=n.indexOf(m);' ..
            'if(idx>=0){' ..
                'var r=n.substring(idx+m.length);' ..
                'var s=r.indexOf(\\\"/usage\\\");' ..
                'if(s>0){o=r.substring(0,s);break;}' ..
            '}' ..
        '}' ..
        'if(!o)return JSON.stringify({error:\\\"org_id_not_found\\\"});' ..
        'var x=new XMLHttpRequest();' ..
        'x.open(\\\"GET\\\",\\\"/api/organizations/\\\"+o+\\\"/usage\\\",false);' ..
        'x.send();' ..
        'if(x.status===200){return x.responseText;}' ..
        'else{return JSON.stringify({error:\\\"http_\\\"+x.status});}' ..
    '}catch(err){return JSON.stringify({error:err.message});}' ..
'})()'

local function refresh()
    local script = 'tell application "Google Chrome"\n' ..
        '    repeat with w in windows\n' ..
        '        repeat with t in tabs of w\n' ..
        '            if URL of t contains "claude.ai" then\n' ..
        '                return execute t javascript "' .. JS_FETCH .. '"\n' ..
        '            end if\n' ..
        '        end repeat\n' ..
        '    end repeat\n' ..
        'end tell'

    local ok, result = hs.osascript.applescript(script)
    if not ok or not result then
        cachedStatus = {
            available = false,
            spent = 0,
            limit = 0,
            percent = 0,
            severity = "unknown",
            currency = "USD",
            error = "Chrome tab not found"
        }
        return
    end

    -- result is the JSON string returned by the JavaScript
    local data = hs.json.decode(result)
    if not data or data.error then
        cachedStatus = {
            available = false,
            spent = 0,
            limit = 0,
            percent = 0,
            severity = "unknown",
            currency = "USD",
            error = data and data.error or "parse_error"
        }
        return
    end

    -- Extract spend data from the response
    local spend = data.spend
    if not spend then
        cachedStatus = {
            available = false,
            spent = 0,
            limit = 0,
            percent = 0,
            severity = "unknown",
            currency = "USD",
            error = "no_spend_field"
        }
        return
    end

    -- amount_minor with exponent gives us the dollar amount
    -- e.g. amount_minor=5522, exponent=2 → $55.22
    local function toDollars(amt)
        if not amt or not amt.amount_minor then return 0 end
        local exp = amt.exponent or 2
        return amt.amount_minor / (10 ^ exp)
    end

    local spent = toDollars(spend.used)
    local limit = toDollars(spend.limit)
    local percent = spend.percent or 0
    local severity = spend.severity or "normal"
    local currency = (spend.used and spend.used.currency) or "USD"

    cachedStatus = {
        available = true,
        spent = spent,
        limit = limit,
        percent = percent,
        severity = severity,
        currency = currency,
        error = nil
    }
end

function claude_usage.getStatus()
    return cachedStatus
end

function claude_usage.refresh()
    refresh()
end

function claude_usage.start()
    if refreshTimer then refreshTimer:stop() end
    -- Initial refresh after a short delay so it doesn't block init
    _claudeUsageInitialTimer = hs.timer.doAfter(5, refresh)
    refreshTimer = hs.timer.doEvery(REFRESH_INTERVAL, refresh)
end

return claude_usage
