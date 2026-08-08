-- providers/slack.lua: Slack attention provider
-- Reads unread counts from Slack's root-state.json which contains
-- per-workspace unreads and unreadHighlights counts.
-- Falls back to LevelDB strings search if root-state.json is unavailable.

local slack = {}

local STORAGE_DIR = os.getenv("HOME") .. "/Library/Application Support/Slack"
local ROOT_STATE = STORAGE_DIR .. "/storage/root-state.json"
local LS_DIR = STORAGE_DIR .. "/Local Storage/leveldb"

function slack.getAttention()
    local app = hs.application.find("Slack")
    if not app then
        return { severity = "none", count = 0, label = "" }
    end

    -- Try root-state.json first (most reliable)
    local f = io.open(ROOT_STATE, "r")
    if f then
        local content = f:read("*all")
        f:close()

        -- Sum unreads and unreadHighlights across all workspaces
        local totalUnreads = 0
        local totalHighlights = 0
        for unreads in content:gmatch('"unreads":(%d+)') do
            totalUnreads = totalUnreads + tonumber(unreads)
        end
        for highlights in content:gmatch('"unreadHighlights":(%d+)') do
            totalHighlights = totalHighlights + tonumber(highlights)
        end

        if totalUnreads > 0 or totalHighlights > 0 then
            local count = totalUnreads
            if totalHighlights > 0 then
                return {
                    severity = "urgent",
                    count = count,
                    label = totalHighlights .. " mention" .. (totalHighlights > 1 and "s" or "")
                }
            end
            return {
                severity = "attention",
                count = count,
                label = count .. " unread"
            }
        end
    end

    -- Fallback: search LevelDB for stats blob
    local output = hs.execute(
        'strings "' .. LS_DIR .. '"/*.log "' .. LS_DIR .. '"/*.ldb 2>/dev/null | ' ..
        'grep "unreadDmConversationsCount" | tail -1'
    )

    if not output or output == "" then
        return { severity = "none", count = 0, label = "" }
    end

    local unreadDms = tonumber(output:match('"unreadDmConversationsCount":(%d+)') or "0") or 0
    local badgedDms = tonumber(output:match('"badgedDmsCount":(%d+)') or "0") or 0
    local badgedThreads = tonumber(output:match('"badgedThreadsCount":(%d+)') or "0") or 0
    local badgedActivity = tonumber(output:match('"badgedActivityCount":(%d+)') or "0") or 0
    local unreadChannels = tonumber(output:match('"unreadChannelsCount":(%d+)') or "0") or 0

    local totalBadged = badgedDms + badgedThreads + badgedActivity
    local totalUnread = unreadDms + unreadChannels + totalBadged

    if totalUnread == 0 then
        return { severity = "none", count = 0, label = "" }
    end

    if totalBadged > 0 then
        return {
            severity = "urgent",
            count = totalUnread,
            label = totalBadged .. " mentions"
        }
    end

    return {
        severity = "attention",
        count = totalUnread,
        label = totalUnread .. " unread"
    }
end

return slack
