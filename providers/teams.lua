-- providers/teams.lua: Microsoft Teams attention provider
-- Reads cached unread counts from a temp file populated by a background refresh.
-- The node script runs asynchronously via init.lua's background launcher,
-- writing JSON to /tmp/teams_attention.json. This provider just reads the file.

local teams = {}

local CACHE_FILE = "/tmp/teams_attention.json"

function teams.getAttention()
    -- Use bundle ID to find the main Teams app, not the background agent process
    local app = hs.application.get("com.microsoft.teams2")
    if not app then
        return { severity = "unreadable", count = 0, label = "not running" }
    end
    -- Verify it's the main app (has a window), not just the background agent
    if not app:mainWindow() then
        return { severity = "unreadable", count = 0, label = "not running" }
    end

    -- Read cached result from background refresh (instant file I/O)
    local f = io.open(CACHE_FILE, "r")
    if f then
        local content = f:read("*all")
        f:close()
        if content and content ~= "" then
            local data = hs.json.decode(content)
            if data and not data.error then
                local people = data.people or 0
                local meetings = data.meetings or 0
                local channels = data.channels or 0
                local total = people + meetings + channels

                if total == 0 then
                    return { severity = "none", count = 0, label = "" }
                end

                local parts = {}
                local segments = {}
                if meetings > 0 then
                    table.insert(parts, meetings .. " mtg")
                    table.insert(segments, { text = meetings .. " mtg", color = "amber" })
                end
                if people > 0 then
                    table.insert(parts, people .. " dm")
                    table.insert(segments, { text = people .. " dm", color = "red" })
                end
                if channels > 0 then
                    table.insert(parts, channels .. " ch")
                    table.insert(segments, { text = channels .. " ch", color = "amber" })
                end
                local label = table.concat(parts, " ")

                if people > 0 then
                    return { severity = "urgent", count = total, label = label, segments = segments }
                end
                return { severity = "attention", count = total, label = label, segments = segments }
            end
        end
    end

    -- Fallback: dock badge (fast AX read)
    local dockApp = hs.application.find("Dock")
    if not dockApp then return { severity = "none", count = 0, label = "" } end
    local dockElem = hs.axuielement.applicationElement(dockApp)
    if not dockElem then return { severity = "none", count = 0, label = "" } end
    local children = dockElem:attributeValue("AXChildren")
    if not children then return { severity = "none", count = 0, label = "" } end
    local dockList = nil
    for _, child in ipairs(children) do
        if child:attributeValue("AXRole") == "AXList" then dockList = child; break end
    end
    if not dockList then return { severity = "none", count = 0, label = "" } end
    local items = dockList:attributeValue("AXChildren")
    if not items then return { severity = "none", count = 0, label = "" } end
    for _, item in ipairs(items) do
        local title = item:attributeValue("AXTitle")
        if title and tostring(title) == "Microsoft Teams" then
            local badge = item:attributeValue("AXStatusLabel")
            if badge then
                local count = tonumber(tostring(badge)) or 0
                if count > 0 then
                    return { severity = "attention", count = count, label = count .. " unread" }
                end
            end
            break
        end
    end
    return { severity = "none", count = 0, label = "" }
end

return teams
