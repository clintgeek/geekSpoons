-- browser.lua: Smart browser bookmark handling with tab focus / de-duplication
local browser = {}

function browser.openURL(url, preferredBrowser)
    preferredBrowser = preferredBrowser or "Google Chrome"

    local domain = url:match("^https?://([^/]+)") or url
    -- Clean domain name for AppleScript search
    domain = domain:gsub("^www%.", "")

    local script = string.format([[
        tell application "%s"
            if it is running then
                repeat with w in windows
                    set tabIndex to 0
                    repeat with t in tabs of w
                        set tabIndex to tabIndex + 1
                        if URL of t contains "%s" then
                            set active tab index of w to tabIndex
                            set index of w to 1
                            activate
                            return "FOCUSED"
                        end if
                    end repeat
                end repeat
            end if
        end tell
        return "NEW"
    ]], preferredBrowser, domain)

    local success, result = hs.applescript(script)
    if success and result == "FOCUSED" then
        return true
    end

    -- Fallback if tab not open or browser not AppleScript scriptable
    hs.urlevent.openURL(url)
    return true
end

return browser
