-- providers/slack.lua: Slack attention provider
-- Reads cached unread counts from a temp file populated by a background refresh.
-- The node script runs asynchronously via init.lua's background launcher,
-- writing JSON to /tmp/slack_attention.json. This provider just reads the file.

local slack = {}

local CACHE_FILE = "/tmp/slack_attention.json"
local ROOT_STATE = os.getenv("HOME") .. "/Library/Application Support/Slack/storage/root-state.json"

function slack.getAttention()
    local app = hs.application.get("Slack")
    if not app then
        return { severity = "unreadable", count = 0, label = "not running" }
    end
    if not app:mainWindow() then
        return { severity = "unreadable", count = 0, label = "not running" }
    end

    -- Read cached result from background refresh (instant file I/O)
    local f = io.open(CACHE_FILE, "r")
    if f then
        local content = f:read("*all")
        f:close()
        if content and content ~= "" then
            local data = hs.json.decode(content)
            if data and not data.error then
                local channels = data.channels or 0
                local dms = data.dms or 0
                local total = channels + dms

                if total == 0 then
                    return { severity = "none", count = 0, label = "" }
                end

                local parts = {}
                local segments = {}
                if channels > 0 then
                    table.insert(parts, channels .. " ch")
                    table.insert(segments, { text = channels .. " ch", color = "amber" })
                end
                if dms > 0 then
                    table.insert(parts, dms .. " dm")
                    table.insert(segments, { text = dms .. " dm", color = "red" })
                end
                local label = table.concat(parts, " ")

                if dms > 0 then
                    return { severity = "urgent", count = total, label = label, segments = segments }
                end
                return { severity = "attention", count = total, label = label, segments = segments }
            end
        end
    end

    -- Fallback: root-state.json (fast file read)
    local f2 = io.open(ROOT_STATE, "r")
    if f2 then
        local content = f2:read("*all")
        f2:close()
        local totalUnreads = 0
        local totalHighlights = 0
        for unreads in content:gmatch('"unreads":(%d+)') do
            totalUnreads = totalUnreads + tonumber(unreads)
        end
        for highlights in content:gmatch('"unreadHighlights":(%d+)') do
            totalHighlights = totalHighlights + tonumber(highlights)
        end
        if totalHighlights > 0 then
            return { severity = "urgent", count = totalUnreads, label = totalUnreads .. " unread (" .. totalHighlights .. " mention" .. (totalHighlights > 1 and "s" or "") .. ")" }
        end
        if totalUnreads > 0 then
            return { severity = "attention", count = totalUnreads, label = totalUnreads .. " unread" }
        end
        return { severity = "none", count = 0, label = "" }
    end
    return { severity = "unreadable", count = 0, label = "no data" }
end

return slack
