-- providers/outlook.lua: Outlook unread mail attention provider
-- Uses accessibility (AXUIElement) to read unread counts from the Outlook sidebar.
-- New Outlook (16.111+) doesn't expose Exchange messages via AppleScript, but the
-- navigation pane shows "FolderName; N unread messages" in cell descriptions.

local outlook = {}

-- Recursively search for AXCell elements with "; N unread messages" in their description
local function findUnreadInCells(elem, found, depth)
    if not elem or depth > 10 then return end

    local role = elem:attributeValue("AXRole")
    local desc = elem:attributeValue("AXDescription")

    -- Match cells like "Inbox; 9 unread messages"
    if role == "AXCell" and desc then
        local descStr = tostring(desc)
        local folderName, count = descStr:match("^(.-);%s*(%d+)%s+unread%s+messages")
        if folderName and count then
            local n = tonumber(count) or 0
            -- Only count Inbox (skip Deleted Items, Junk, Promotions, etc.)
            if folderName:lower() == "inbox" and n > 0 then
                table.insert(found, { folder = folderName, count = n })
            end
        end
    end

    local children = elem:attributeValue("AXChildren")
    if children then
        for _, child in ipairs(children) do
            findUnreadInCells(child, found, depth + 1)
        end
    end
end

function outlook.getAttention()
    local app = hs.application.find("Microsoft Outlook")
    if not app then
        return { severity = "none", count = 0, label = "" }
    end

    local elem = hs.axuielement.applicationElement(app)
    if not elem then
        return { severity = "none", count = 0, label = "" }
    end

    -- Find the Inbox window (not the Reminders window)
    local windows = elem:attributeValue("AXWindows")
    if not windows then
        return { severity = "none", count = 0, label = "" }
    end

    local found = {}
    for _, win in ipairs(windows) do
        local title = win:attributeValue("AXTitle")
        if title and tostring(title):match("Inbox") then
            findUnreadInCells(win, found, 0)
        end
    end

    local totalCount = 0
    for _, item in ipairs(found) do
        totalCount = totalCount + item.count
    end

    if totalCount == 0 then
        return { severity = "none", count = 0, label = "" }
    end

    return {
        severity = "attention",
        count = totalCount,
        label = totalCount .. " unread"
    }
end

return outlook
