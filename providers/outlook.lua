-- providers/outlook.lua: Outlook unread mail attention provider
--
-- The new Edge-based Outlook (IsRunningNewOutlook=1) doesn't expose its
-- window via the accessibility tree, doesn't support AppleScript mail queries,
-- doesn't store mail in the local SQLite DB, and doesn't have a dock badge.
-- Its preference plist is locked by cfprefsd, so we can't check
-- IsRunningNewOutlook via `defaults read` (it hangs).
--
-- Strategy: Try the AX tree query. If it returns "NOWINDOW", the window isn't
-- accessible (new Outlook or minimized). In that case, just show "running".
-- If the AX tree is available (old Outlook), parse the Inbox unread count
-- from the cell description — this is real-time data.

local outlook = {}

-- AppleScript to find the Inbox folder's description in Outlook's AX tree.
-- Breadth-first search capped at 200 elements. Returns the description string,
-- "NOTFOUND" if no Inbox cell, or "NOWINDOW" if the AX tree has no windows.
local INBOX_AX_QUERY = [[
tell application "System Events"
    tell process "Microsoft Outlook"
        set winCount to count of windows
        if winCount is 0 then return "NOWINDOW"
        
        set searchQueue to {}
        set winChildren to UI elements of window 1
        repeat with child in winChildren
            set end of searchQueue to child
        end repeat
        
        repeat 200 times
            if (count of searchQueue) is 0 then exit repeat
            set elem to item 1 of searchQueue
            set searchQueue to rest of searchQueue
            
            try
                set elemRole to role of elem
                if elemRole is "AXCell" then
                    set elemDesc to description of elem
                    if elemDesc starts with "Inbox" then
                        return elemDesc
                    end if
                end if
                set elemChildren to UI elements of elem
                repeat with child in elemChildren
                    set end of searchQueue to child
                end repeat
            end try
        end repeat
        
        return "NOTFOUND"
    end tell
end tell
]]

-- Parse the unread count from an Inbox description like "Inbox; 3 unread messages"
local function parseUnreadCount(desc)
    if not desc then return nil end
    local count = desc:match("Inbox;%s*(%d+)%s+unread")
    if count then return tonumber(count) end
    if desc:match("^Inbox") then return 0 end
    return nil
end

function outlook.getAttention()
    local app = hs.application.find("Microsoft Outlook")
    if not app then
        return { severity = "unreadable", count = 0, label = "not running" }
    end

    -- Try AX tree (works with old Outlook; new Outlook returns "NOWINDOW")
    local ok, result = hs.osascript.applescript(INBOX_AX_QUERY)
    if ok and result and result ~= "NOTFOUND" and result ~= "NOWINDOW" then
        local count = parseUnreadCount(result)
        if count and count > 0 then
            return { severity = "attention", count = count, label = count .. " unread" }
        end
        -- AX found Inbox with 0 unread
        return { severity = "none", count = 0, label = "" }
    end

    -- AX tree not available (new Outlook or window not visible) — just show running
    return { severity = "none", count = 0, label = "" }
end

return outlook
