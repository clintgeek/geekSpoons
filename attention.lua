-- attention.lua: Normalized attention state provider
-- Collects attention state from registered providers and exposes a unified model.
-- Providers return: { severity = "none"|"attention"|"urgent", count = N, label = "..." }

local attention = {}

local providers = {}

function attention.register(appId, providerFn)
    providers[appId] = providerFn
end

-- Returns a table keyed by appId:
--   { slack = {severity="attention", count=7, label="2 mentions"}, ... }
function attention.getStatus()
    local state = {}
    for appId, providerFn in pairs(providers) do
        local ok, result = pcall(providerFn)
        if ok and type(result) == "table" then
            state[appId] = result
        else
            state[appId] = { severity = "none", count = 0, label = "" }
        end
    end
    return state
end

return attention
