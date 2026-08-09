-- providers/outlook.lua: Outlook unread mail attention provider
-- Reads unread count from Outlook's OSA (Outlook Service API) sync logs.
-- The new Edge-based Outlook doesn't expose mail via AppleScript or AXUIElement,
-- but its sync logs contain GetFolder responses with <UnreadCount> per folder.
-- We search across recent OSA sessions for the latest GetFolder response
-- (not GetFolderList, which doesn't contain unread counts).

local outlook = {}

function outlook.getAttention()
    local app = hs.application.find("Microsoft Outlook")
    if not app then
        return { severity = "unreadable", count = 0, label = "not running" }
    end

    -- Path to the OSA log directory
    local osaBase = os.getenv("HOME") ..
        "/Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles/Main Identity/Osa"

    -- Search the 3 most recent OSA sessions for a GetFolder response
    -- (not GetFolderList, which doesn't have UnreadCount)
    local sessions = hs.execute('ls -t "' .. osaBase .. '" 2>/dev/null | head -3')
    if not sessions or sessions == "" then
        return { severity = "none", count = 0, label = "" }
    end

    for session in sessions:gmatch("[^\n]+") do
        session = session:gsub("%s+$", "")
        local sessionDir = osaBase .. "/" .. session

        -- Find the most recent GetFolder response (exclude GetFolderList)
        local latestFile = hs.execute(
            'ls -t "' .. sessionDir .. '" 2>/dev/null | ' ..
            'grep "sync\\.GetFolder\\." | grep "res" | head -1'
        )
        if latestFile and latestFile ~= "" then
            latestFile = latestFile:gsub("%s+$", "")

            -- Decompress the XML
            local content = hs.execute('gunzip -c "' .. sessionDir .. '/' .. latestFile .. '" 2>/dev/null')
            if content and content ~= "" then
                -- Parse line by line: track the current folder type, then grab the next UnreadCount
                local currentFolderType = nil
                local inboxCount = 0

                for line in content:gmatch("[^\r\n]+") do
                    -- Match folder type lines like <Type>Inbox (1)</Type> (not <Type>0</Type>)
                    local folderType = line:match("<Type>([A-Za-z]+[^<]*)</Type>")
                    if folderType then
                        currentFolderType = folderType
                    end

                    -- Match unread count lines
                    local unread = line:match("<UnreadCount>(%d+)</UnreadCount>")
                    if unread and currentFolderType then
                        if currentFolderType:match("Inbox") then
                            inboxCount = tonumber(unread) or 0
                        end
                        currentFolderType = nil
                    end
                end

                if inboxCount > 0 then
                    return {
                        severity = "attention",
                        count = inboxCount,
                        label = inboxCount .. " unread"
                    }
                end

                -- Found a GetFolder response but Inbox has 0 unread
                return { severity = "none", count = 0, label = "" }
            end
        end
    end

    -- Outlook is running but no sync data found yet
    return { severity = "none", count = 0, label = "" }
end

return outlook
