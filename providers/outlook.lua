-- providers/outlook.lua: Outlook unread mail attention provider
-- Reads unread count from Outlook's OSA (Outlook Service API) sync logs.
-- The new Edge-based Outlook doesn't expose mail via AppleScript or AXUIElement,
-- but its sync logs contain GetFolder responses with <UnreadCount> per folder.
-- We search across recent OSA sessions for the latest GetFolder response.
-- Only sessions modified within the last 2 hours are considered valid;
-- older sessions return "unreadable" to avoid showing stale counts.

local outlook = {}

local env = require("env")
local FRESHNESS_SECS = 2 * 60 * 60  -- 2 hours

-- UBF8T346G9 is Microsoft's shared Office group container ID (same for all installs)
local OSA_BASE = env.get("OUTLOOK_OSA_PATH") or
    (os.getenv("HOME") .. "/Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles/Main Identity/Osa")

-- Escape a string for safe use inside double quotes in a shell command.
local function shellEscape(s)
    return (s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('`', '\\`'):gsub('%$', '\\$'))
end

-- Parse OSA sync XML to extract the Inbox unread count.
-- Tracks <Type>Inbox...</Type> then grabs the following <UnreadCount>.
local function parseInboxUnread(xml)
    local currentFolderType = nil
    for line in xml:gmatch("[^\r\n]+") do
        local folderType = line:match("<Type>([A-Za-z]+[^<]*)</Type>")
        if folderType then
            currentFolderType = folderType
        end
        local unread = line:match("<UnreadCount>(%d+)</UnreadCount>")
        if unread and currentFolderType then
            if currentFolderType:match("Inbox") then
                return tonumber(unread) or 0
            end
            currentFolderType = nil
        end
    end
    return 0
end

-- Find the most recent GetFolder response file in a session directory.
-- Returns the file path, or nil if not found.
local function findGetFolderFile(sessionDir)
    local latestFile = hs.execute(
        'ls -t "' .. shellEscape(sessionDir) .. '" 2>/dev/null | ' ..
        'grep "\\.GetFolder\\." | grep "res" | head -1'
    )
    if not latestFile or latestFile == "" then return nil end
    latestFile = latestFile:gsub("%s+$", "")
    return sessionDir .. '/' .. latestFile
end

-- Check if a file was modified within FRESHNESS_SECS.
-- Uses hs.fs.attributes (no shell command) for the modification time.
local function isFileFresh(filePath)
    local attrs = hs.fs.attributes(filePath)
    if not attrs or not attrs.modification then return false end
    return (os.time() - attrs.modification) <= FRESHNESS_SECS
end

-- Read and decompress a gzip file, returning the contents or nil.
local function readGzipFile(filePath)
    local content = hs.execute('gunzip -c "' .. shellEscape(filePath) .. '" 2>/dev/null')
    if content and content ~= "" then return content end
    return nil
end

function outlook.getAttention()
    local app = hs.application.find("Microsoft Outlook")
    if not app then
        return { severity = "unreadable", count = 0, label = "not running" }
    end

    -- Search the 5 most recent OSA sessions for a GetFolder response
    local sessions = hs.execute('ls -t "' .. shellEscape(OSA_BASE) .. '" 2>/dev/null | head -5')
    if not sessions or sessions == "" then
        return { severity = "unreadable", count = 0, label = "no sync data" }
    end

    for session in sessions:gmatch("[^\n]+") do
        session = session:gsub("%s+$", "")
        local sessionDir = OSA_BASE .. "/" .. session

        local filePath = findGetFolderFile(sessionDir)
        if filePath and isFileFresh(filePath) then
            local xml = readGzipFile(filePath)
            if xml then
                local inboxCount = parseInboxUnread(xml)
                if inboxCount > 0 then
                    return { severity = "attention", count = inboxCount, label = inboxCount .. " unread" }
                end
                -- Found a recent GetFolder response but Inbox has 0 unread
                return { severity = "none", count = 0, label = "" }
            end
        end
    end

    -- Outlook is running but no recent sync data found
    return { severity = "unreadable", count = 0, label = "no recent sync" }
end

return outlook
