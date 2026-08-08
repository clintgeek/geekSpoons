-- providers/messages.lua: Google Messages (Edge PWA) attention provider
-- Google Messages for web is installed as an Edge PWA. The page title
-- changes to include unread count, e.g. "(1) Google Messages for web: Conversations"
-- We read this from the accessibility tree. The PWA's AXWindows array is empty,
-- but AXFocusedWindow contains an AXGroup with the page title.

local messages = {}

-- The PWA's bundle ID
local BUNDLE_ID = "com.microsoft.edgemac.app.hpfldicfbfomlpcikngkocigghgafkph"

-- Recursively search for AXGroup elements with a title containing "Google Messages"
local function findUnreadCount(elem, depth)
    if not elem or depth > 8 then return nil end

    local role = elem:attributeValue("AXRole")
    local title = elem:attributeValue("AXTitle")

    -- Google Messages puts unread count in the page title
    -- Format: "(N) Google Messages for web: Conversations"
    if role == "AXGroup" and title then
        local titleStr = tostring(title)
        if titleStr:match("Google Messages") then
            -- Look for (N) pattern in the title
            local count = titleStr:match("%((%d+)%)")
            if count then
                return tonumber(count) or 0
            end
            -- No (N) means 0 unread
            return 0
        end
    end

    local children = elem:attributeValue("AXChildren")
    if children then
        for _, child in ipairs(children) do
            local result = findUnreadCount(child, depth + 1)
            if result then return result end
        end
    end

    return nil
end

function messages.getAttention()
    local apps = hs.application.applicationsForBundleID(BUNDLE_ID)
    if not apps or #apps == 0 then
        return { severity = "none", count = 0, label = "" }
    end

    local app = apps[1]
    local elem = hs.axuielement.applicationElement(app)
    if not elem then
        return { severity = "none", count = 0, label = "" }
    end

    -- The PWA's AXWindows array is empty, but AXFocusedWindow works
    local win = elem:attributeValue("AXFocusedWindow")
    if win then
        local count = findUnreadCount(win, 0)
        if count and count > 0 then
            return {
                severity = "attention",
                count = count,
                label = count .. " unread"
            }
        end
    end

    -- Fallback: try AXWindows (in case behavior changes)
    local windows = elem:attributeValue("AXWindows")
    if windows then
        for _, w in ipairs(windows) do
            local count = findUnreadCount(w, 0)
            if count and count > 0 then
                return {
                    severity = "attention",
                    count = count,
                    label = count .. " unread"
                }
            end
        end
    end

    return { severity = "none", count = 0, label = "" }
end

return messages
