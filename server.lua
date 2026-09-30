-- server.lua: Embedded HTTP & HTTPS server for Android Tablet Stream Deck (Explicit Load Button Touch Handlers)
local server = {}

local spotify = require("spotify")
local mute = require("mute")
local meeting = require("meeting")
local winManager = require("window")
local audio = require("audio")
local screenshot = require("screenshot")
local record = require("record")
local apps = require("apps")
local attention = require("attention")
local camera = require("camera")
local calendar = require("calendar")
local weather = require("weather")

local httpServer = nil
local port = 8080

local function corsHeaders(contentType)
    return {
        ["Content-Type"] = contentType or "text/html; charset=utf-8",
        ["Access-Control-Allow-Origin"] = "*",
        ["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS",
        ["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With",
        ["Cache-Control"] = "no-cache, no-store, must-revalidate"
    }
end

local function jsonResponse(data)
    local ok, jsonStr = pcall(hs.json.encode, data)
    if not ok then
        print("json encode error: " .. tostring(jsonStr))
        return '{"error":"json encode failed"}', 500, corsHeaders("application/json")
    end
    return jsonStr, 200, corsHeaders("application/json")
end

local function getManifestJSON()
    local manifest = {
        name = "Hammerspoon Workstation Controller",
        short_name = "Workstation",
        description = "Hammerspoon Workstation Controller v2.4",
        start_url = "/",
        scope = "/",
        display = "fullscreen",
        orientation = "landscape",
        background_color = "#080D13",
        theme_color = "#080D13",
        icons = {
            {
                src = "/icon.svg",
                sizes = "512x512",
                type = "image/svg+xml",
                purpose = "any maskable"
            }
        }
    }
    return hs.json.encode(manifest), 200, corsHeaders("application/manifest+json")
end

local function getServiceWorkerJS()
    local sw = [[
        self.addEventListener('install', (e) => self.skipWaiting());
        self.addEventListener('activate', (e) => self.clients.claim());
        self.addEventListener('fetch', (e) => e.respondWith(fetch(e.request)));
    ]]
    return sw, 200, corsHeaders("application/javascript")
end

local function getIconSVG()
    local svg = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
        <rect width="512" height="512" rx="100" fill="#060911"/>
        <circle cx="256" cy="256" r="200" fill="rgba(168, 85, 247, 0.2)" stroke="#00ff41" stroke-width="8"/>
        <text x="256" y="320" font-size="220" text-anchor="middle" fill="#00ff41" font-family="-apple-system, sans-serif" font-weight="bold">⚡</text>
    </svg>]]
    return svg, 200, corsHeaders("image/svg+xml")
end

local function getHTML()
    local f = io.open(hs.configdir .. "/index.html", "rb")
    if not f then
        return "dashboard not found", 500, corsHeaders("text/plain; charset=utf-8")
    end
    local c = f:read("*all")
    f:close()
    return c, 200, corsHeaders("text/html; charset=utf-8")
end

-- Static assets split out of index.html. An exact-match whitelist rather than
-- a path join, so no request can walk out of the config directory.
--
-- These are served no-store like everything else here. Caching them would be
-- the usual reason to split a page up, but this config already fought a stale
-- asset problem (hence the disabled service worker), and on a LAN the transfer
-- is free. The win being taken here is a navigable file, not a cached one.
local STATIC_FILES = {
    ["/app.css"] = "text/css; charset=utf-8",
    ["/app.js"]  = "application/javascript; charset=utf-8",
}

local function serveStatic(path)
    local f = io.open(hs.configdir .. path, "rb")
    if not f then
        return "not found: " .. path, 404, corsHeaders("text/plain; charset=utf-8")
    end
    local c = f:read("*all")
    f:close()
    return c, 200, corsHeaders(STATIC_FILES[path])
end

local function notFound(path)
    return "not found: " .. path, 404, corsHeaders("text/plain; charset=utf-8")
end

local function handleRequest(method, path, headers, body)
    if method == "OPTIONS" then
        return "", 200, corsHeaders()
    end

    if path == "/manifest.json" then
        return getManifestJSON()
    elseif path == "/sw.js" then
        return getServiceWorkerJS()
    elseif path == "/icon.svg" then
        return getIconSVG()
    elseif path == "/api/status" then
        local function safeStatus(fn)
            local ok, result = pcall(fn)
            if ok then return result else return { error = tostring(result) } end
        end
        local data = {
            micMuted = safeStatus(function() return mute.isMuted() end),
            audio = safeStatus(function() return audio.getStatus() end),
            spotify = safeStatus(function() return spotify.getStatus() end),
            attention = safeStatus(function() return attention.getStatus() end),
            camera = safeStatus(function() return camera.getStatus() end),
            nextUp = safeStatus(function() return calendar.getStatus() end),
            weather = safeStatus(function() return weather.getStatus() end),
        }
        return jsonResponse(data)
    elseif path == "/api/debug/attention" then
        local data = {
            cached = attention.getStatus(),
            windows = {},
        }
        -- Resolve by bundle ID. hs.application.find() searches by name with
        -- exact=false, and on a miss it falls through to hs.window.find(),
        -- which runs allWindows() against every running app -- the same
        -- synchronous AX sweep the rest of this config goes out of its way to
        -- avoid. A miss is the normal case here, since these apps are often
        -- closed.
        local DEBUG_APPS = {
            ["Microsoft Outlook"] = "com.microsoft.Outlook",
            ["Microsoft Teams"]   = "com.microsoft.teams2",
            ["Slack"]             = "com.tinyspeck.slackmacgap",
            ["Google Chrome"]     = "com.google.Chrome",
        }
        for appName, bundleID in pairs(DEBUG_APPS) do
            local app = hs.application.applicationsForBundleID(bundleID)[1]
            if app then
                local wins = app:allWindows()
                local titles = {}
                for _, w in ipairs(wins) do
                    table.insert(titles, w:title())
                end
                data.windows[appName] = { pid = app:pid(), titles = titles }
            else
                data.windows[appName] = { found = false }
            end
        end
        return jsonResponse(data)
    elseif path:find("/api/action/set_output", 1, true) then
        local name = path:match("name=([^&]+)")
        if name then
            name = name:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
            local dev = hs.audiodevice.findDeviceByName(name)
            if dev then
                dev:setDefaultOutputDevice()
                return jsonResponse({status = "ok", output = dev:name()})
            end
        end
        return jsonResponse({status = "error", error = "device not found"})
    elseif path:find("/api/action/join_meeting", 1, true) then
        local url = path:match("url=([^&]+)")
        if not url then
            return jsonResponse({status = "error", error = "missing url"})
        end
        -- Simple URL decode (hs.http.urlPartDecode can crash on some inputs)
        url = url:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        -- Only allow http(s) links, and open without a shell (hs.urlevent)
        -- so a crafted url can't inject shell commands.
        if not url:match("^https?://") then
            return jsonResponse({status = "error", error = "invalid url"})
        end
        hs.timer.doAfter(0, function()
            pcall(function() hs.urlevent.openURL(url) end)
        end)
        return jsonResponse({status = "ok"})
    elseif path:find("/api/action/play_uri", 1, true) then
        local track = path:match("track=([^&]+)")
        local context = path:match("context=([^&]+)")
        if track or context then
            local function urlDecode(s) return s and s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end) or "" end
            track = urlDecode(track)
            context = urlDecode(context)
            hs.timer.doAfter(0, function()
                spotify.playURI(track, context)
            end)
        end
        return jsonResponse({status = "ok"})
    elseif path:sub(1, 12) == "/api/action/" then
        local action = path:sub(13)

        -- Actions that return a result (synchronous, need pcall)
        local actionResults = {
            mute_toggle    = function() local m = mute.toggleMute(); meeting.toggleMute(); return {micMuted = m} end,
            talk_start     = function() local m = mute.startTalk(); meeting.startTalk(); return {micMuted = m} end,
            talk_stop      = function() local m = mute.stopTalk(); meeting.stopTalk(); return {micMuted = m} end,
            audio_mute     = function() return {audioMuted = audio.toggleMute()} end,
            cam_toggle     = function()
                meeting.toggleCamera()
                -- macOS takes a moment to report the camera as in use, so poll
                -- the state a few times across the settle window instead of
                -- once at 1.5s -- that lands the new state as soon as it's
                -- available rather than always waiting for the worst case.
                for _, delay in ipairs({0.3, 0.7, 1.2, 2.0}) do
                    hs.timer.doAfter(delay, function() camera.refresh() end)
                end
                -- Deliberately no camera state in the response: at this point
                -- it is still the pre-toggle value, and returning it made the
                -- frontend repaint the old state before the refresh landed.
                return {}
            end,
        }

        -- Actions that fire-and-forget (deferred via hs.timer)
        local actionDeferred = {
            audio_cycle        = function() audio.cycleOutput() end,
            audio_volup        = function() audio.volumeUp() end,
            audio_voldown      = function() audio.volumeDown() end,
            snap_selection     = function() screenshot.selection() end,
            record_screen      = function() record.screen() end,
            app_chrome         = function() apps.smartLaunch("chrome") end,
            app_messages       = function() apps.smartLaunch("messages") end,
            app_chatgpt        = function() apps.smartLaunch("chatgpt") end,
            app_teams          = function() apps.smartLaunch("teams") end,
            app_slack          = function() apps.smartLaunch("slack") end,
            app_outlook        = function() apps.smartLaunch("outlook") end,
            app_outlookweb     = function() apps.smartLaunch("outlookweb") end,
            app_firefox        = function() apps.smartLaunch("firefox") end,
            spotify_playpause  = function() spotify.playPause() end,
            spotify_next       = function() spotify.nextTrack() end,
            spotify_prev       = function() spotify.previousTrack() end,
            spotify_shuffle    = function() spotify.toggleShuffle() end,
            spotify_repeat     = function() spotify.toggleRepeat() end,
            spotify_like       = function() spotify.likeCurrentTrack() end,
            app_managers_toolbox = function() apps.smartLaunch("managersToolbox") end,
            weather_refresh     = function() weather.refresh() end,
            window_split       = function() winManager.split5050() end,
            spotify_open       = function() hs.application.launchOrFocus("Spotify") end,
        }

        if actionResults[action] then
            local ok, result = pcall(actionResults[action])
            if ok then
                local response = {status = "ok"}
                for k, v in pairs(result) do response[k] = v end
                return jsonResponse(response)
            else
                return jsonResponse({status = "error", error = tostring(result)})
            end
        elseif actionDeferred[action] then
            hs.timer.doAfter(0, function()
                local ok, err = pcall(actionDeferred[action])
                if not ok then print("action '" .. action .. "' error: " .. tostring(err)) end
            end)
            return jsonResponse({status = "ok"})
        end

        return jsonResponse({status = "error", error = "unknown action: " .. action})
    end

    -- Serve the dashboard only for the document paths. Everything else used to
    -- fall through to a 200 with the full 98KB page, which masked typo'd API
    -- routes and made a missing asset look like a successful load.
    if path == "/" or path == "" or path == "/index.html" then
        return getHTML()
    end

    if STATIC_FILES[path] then
        return serveStatic(path)
    end

    return notFound(path)
end

function server.start()
    if httpServer then httpServer:stop() end

    -- Start HTTP Server on 8080, listening on all interfaces. This must
    -- be LAN-reachable: nginx runs on a separate network server and
    -- proxies hs.clintgeek.com to this machine's LAN IP. The security
    -- boundary is the home LAN itself (non-routable address behind the
    -- router) plus nginx's client-IP restrictions on the HTTPS side.
    -- Do NOT setInterface("loopback") — it 502s the dashboard.
    httpServer = hs.httpserver.new(false, true)
    httpServer:setName("Hammerspoon Stream Deck")
    httpServer:setPort(port)
    httpServer:setCallback(handleRequest)
    httpServer:start()
    print("Stream Deck HTTP Server running on port " .. port)
end

return server
