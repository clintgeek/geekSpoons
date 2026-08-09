-- env.lua: Load .env file and store values in a module table.
-- Other modules call env.get("KEY") instead of os.getenv().

local env = {}

local values = {}

local function parseLine(line)
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line == "" or line:sub(1, 1) == "#" then return end

    local eq = line:find("=")
    if not eq then return end

    local key = line:sub(1, eq - 1):gsub("^%s+", ""):gsub("%s+$", "")
    local val = line:sub(eq + 1):gsub("^%s+", ""):gsub("%s+$", "")
    val = val:gsub('^"', ""):gsub('"$', ""):gsub("^'", ""):gsub("'$", "")

    if key ~= "" then
        values[key] = val
    end
end

function env.load()
    local path = hs.configdir .. "/.env"
    local f = io.open(path, "r")
    if not f then return end
    for line in f:lines() do
        parseLine(line)
    end
    f:close()
end

-- get(key, fallback) - returns env value or os.getenv or fallback
function env.get(key, fallback)
    if values[key] ~= nil then return values[key] end
    local osval = os.getenv(key)
    if osval then return osval end
    return fallback
end

return env
