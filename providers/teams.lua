-- providers/teams.lua: Microsoft Teams attention provider
-- Reads the dock badge from the Dock's AXUIElement tree.
-- The Dock process exposes AXDockItem elements with an AXStatusLabel
-- attribute that contains the badge number shown on the app icon.

local teams = {}

function teams.getAttention()
    local app = hs.application.find("Microsoft Teams")
    if not app then
        return { severity = "unreadable", count = 0, label = "not running" }
    end

    -- Find the Dock process and navigate to the Teams dock item
    local dockApp = hs.application.find("Dock")
    if not dockApp then
        return { severity = "none", count = 0, label = "" }
    end

    local dockElem = hs.axuielement.applicationElement(dockApp)
    if not dockElem then
        return { severity = "none", count = 0, label = "" }
    end

    -- The Dock has a single AXList child containing all dock items
    local children = dockElem:attributeValue("AXChildren")
    if not children then
        return { severity = "none", count = 0, label = "" }
    end

    local dockList = nil
    for _, child in ipairs(children) do
        local role = child:attributeValue("AXRole")
        if role == "AXList" then
            dockList = child
            break
        end
    end
    if not dockList then
        return { severity = "none", count = 0, label = "" }
    end

    local items = dockList:attributeValue("AXChildren")
    if not items then
        return { severity = "none", count = 0, label = "" }
    end

    -- Find the "Microsoft Teams" dock item and read its AXStatusLabel
    for _, item in ipairs(items) do
        local title = item:attributeValue("AXTitle")
        if title and tostring(title) == "Microsoft Teams" then
            local badge = item:attributeValue("AXStatusLabel")
            if badge then
                local count = tonumber(tostring(badge)) or 0
                if count > 0 then
                    return {
                        severity = "attention",
                        count = count,
                        label = count .. " unread"
                    }
                end
            end
            break
        end
    end

    -- Teams is running but no badge found — dock badge not available
    return { severity = "none", count = 0, label = "" }
end

return teams
