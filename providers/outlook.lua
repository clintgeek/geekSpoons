-- providers/outlook.lua: Outlook unread mail attention provider
-- Reads unread count from Outlook's OSA (Outlook Service API) sync logs.
-- The new Edge-based Outlook doesn't expose mail via AppleScript or AXUIElement,
-- but its sync logs contain GetFolder responses with <UnreadCount> per folder.
-- We search across recent OSA sessions for the latest GetFolder response.
-- Only sessions modified within the last 2 hours are considered valid;
-- older sessions return "unreadable" to avoid showing stale counts.

local outlook = {}

local FRESHNESS_SECS = 2 * 60 * 60  -- 2 hours

function outlook.getAttention()
    local app = hs.application.find("Microsoft Outlook")
    if not app then
        return { severity = "unreadable", count = 0, label = "not running" }
    end

    -- Path to the OSA log directory
    local osaBase = os.getenv("HOME") ..
        "/Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles/Main Identity/Osa"

    -- Search the 5 most recent OSA sessions for a GetFolder response
    local sessions = hs.execute('ls -t "' .. osaBase .. '" 2>/dev/null | head -5')
    if not sessions or sessions == "" then
        return { severity = "unreadable", count = 0, label = "no sync data" }
    end

    local now = os.time()

    for session in sessions:gmatch("[^\n]+") do
        session = session:gsub("%s+$", "")
        local sessionDir = osaBase .. "/" .. session

        -- Find the most recent GetFolder response (exclude GetFolderList)
        -- Matches both sync.GetFolder and fetch.GetFolder
        local latestFile = hs.execute(
            'ls -t "' .. sessionDir .. '" 2>/dev/null | ' ..
            'grep "\\.GetFolder\\." | grep "res" | head -1'
        )
        if latestFile and latestFile ~= "" then
            latestFile = latestFile:gsub("%s+$", "")
            local filePath = sessionDir .. '/' .. latestFile

            -- Check the GetFolder file's freshness (not the session directory's)
            local fileMtimeOutput = hs.execute('stat -f "%m" "' .. filePath .. '" 2>/dev/null')
            local fileMtime = tonumber(fileMtimeOutput and fileMtimeOutput:gsub("%s+", "") or "")
            if fileMtime and (now - fileMtime) > FRESHNESS_SECS then
                -- GetFolder file is too old — skip this session
            else

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

                    -- Found a recent GetFolder response but Inbox has 0 unread
                    return { severity = "none", count = 0, label = "" }
                end
            end
        end
    end

    -- Outlook is running but no recent sync data found
    return { severity = "unreadable", count = 0, label = "no recent sync" }
end

return outlook
