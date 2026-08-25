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

-- Look this app up by bundle ID, never by name. hs.application.get()/find()
-- search by name with exact=false, and when nothing matches they fall through
-- to hs.window.find(), which calls allWindows() on *every* running
-- application -- a synchronous Accessibility IPC round-trip each. So the
-- "app isn't running" case, which this provider hits routinely, blocked
-- Hammerspoon's main thread for over a second every refresh and starved the
-- HTTP server. applicationsForBundleID() never does the window sweep.
local function findApp(bundleID)
    return hs.application.applicationsForBundleID(bundleID)[1]
end

local OUTLOOK_BUNDLE_ID = "com.microsoft.Outlook"

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

-- The AX query is slow (200+ element BFS), so it runs asynchronously in
-- an osascript subprocess and updates this cache; getAttention() kicks
-- off a refresh (if one isn't in flight) and returns the cached result.
local cachedResult = { severity = "none", count = 0, label = "" }
local taskRef = nil -- keep hs.task alive so GC doesn't collect it mid-run

local function buildResult(queryOutput)
    -- AX available (old Outlook): parse the Inbox unread count
    if queryOutput and queryOutput ~= "" and queryOutput ~= "NOTFOUND" and queryOutput ~= "NOWINDOW" then
        local count = parseUnreadCount(queryOutput)
        if count and count > 0 then
            return { severity = "attention", count = count, label = count .. " unread" }
        end
        return { severity = "none", count = 0, label = "" }
    end
    -- AX tree not available (new Outlook or window not visible) — just show running
    return { severity = "none", count = 0, label = "" }
end

function outlook.getAttention()
    local app = findApp(OUTLOOK_BUNDLE_ID)
    if not app then
        cachedResult = { severity = "unreadable", count = 0, label = "not running" }
        return cachedResult
    end

    if not taskRef then
        taskRef = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
            taskRef = nil
            if exitCode == 0 then
                cachedResult = buildResult(stdOut and stdOut:gsub("%s+$", "") or "")
            end
            -- Non-zero exit (e.g. Outlook quit mid-query): keep the last
            -- cached result; the "not running" case above handles quits.
        end, { "-e", INBOX_AX_QUERY })
        taskRef:start()
    end

    return cachedResult
end

return outlook
