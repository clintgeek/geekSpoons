-- providers/outlook.lua: Outlook unread mail attention provider
-- Tier 2: Uses macOS dock badge (hs.application.dockIconBadge) to detect unread count.
-- Falls back to 0 if Outlook is not running or badge is not a number.

local outlook = {}

local OUTLOOK_BUNDLE = "com.microsoft.Outlook"
local OUTLOOK_NAME = "Outlook"

local function getDockBadge()
    local app = hs.application.find(OUTLOOK_BUNDLE)
    if not app then
        app = hs.application.find(OUTLOOK_NAME)
    end
    if not app then return nil end

    -- dockIconBadge returns the badge text as a string
    local badge = app:dockIconBadge()
    if not badge or badge == "" then return 0 end

    -- Strip non-numeric characters (e.g. "!" for some apps)
    local num = tonumber(badge:gsub("[^%d]", ""))
    return num or 0
end

-- Returns normalized attention state for Outlook
function outlook.getAttention()
    local count = getDockBadge() or 0
    if count == 0 then
        return { severity = "none", count = 0, label = "" }
    end

    -- Tier 2 doesn't distinguish mention vs unread; treat all as "attention"
    -- unless the count is very high, which we leave as attention (not urgent).
    return {
        severity = "attention",
        count = count,
        label = count .. " unread"
    }
end

return outlook
