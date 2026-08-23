-- nodebin.lua: Resolve the node binary to an absolute path, cached.
-- hs.execute and hs.task run without the user's shell PATH (no nvm or
-- homebrew), so a bare "node" fails silently. Every module that shells
-- out to node must resolve it through this module.
-- Resolution order: NODE_BIN_PATH from .env, homebrew, newest nvm
-- version, then a PATH lookup as a last resort.

local nodebin = {}

local env = require("env")

local cached = nil

local function isFile(path)
    return path and hs.fs.attributes(path, "mode") == "file"
end

-- Returns the absolute path to node, or nil if it can't be found.
function nodebin.path()
    if cached then return cached end

    local override = env.get("NODE_BIN_PATH")
    if isFile(override) then
        cached = override
        return cached
    end

    local candidates = {
        "/opt/homebrew/bin/node",
        "/usr/local/bin/node",
    }

    -- Newest nvm-installed version first
    local nvmDir = os.getenv("HOME") .. "/.nvm/versions/node"
    local nvmVersions = {}
    local ok, iter, dirObj = pcall(hs.fs.dir, nvmDir)
    if ok and iter then
        for name in iter, dirObj do
            if name ~= "." and name ~= ".." then
                table.insert(nvmVersions, name)
            end
        end
    end
    table.sort(nvmVersions)
    for i = #nvmVersions, 1, -1 do
        table.insert(candidates, nvmDir .. "/" .. nvmVersions[i] .. "/bin/node")
    end

    for _, path in ipairs(candidates) do
        if isFile(path) then
            cached = path
            return cached
        end
    end

    local p = (hs.execute("which node 2>/dev/null") or ""):gsub("%s+$", "")
    if p ~= "" then
        cached = p
        return cached
    end

    return nil
end

return nodebin
