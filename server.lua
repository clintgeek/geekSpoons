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
    if not f then return "HTML not found" end
    local c = f:read("*all")
    f:close()
    return c
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
        -- Get window titles via hs.window (faster than AXUIElement)
        for _, appName in ipairs({"Microsoft Outlook", "MSTeams", "Slack", "Messages"}) do
            local app = hs.application.find(appName)
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
            mute_toggle    = function() return {micMuted = mute.toggleMute()} end,
            talk_start     = function() return {micMuted = mute.startTalk()} end,
            talk_stop      = function() return {micMuted = mute.stopTalk()} end,
            audio_mute     = function() return {audioMuted = audio.toggleMute()} end,
            cam_toggle     = function()
                meeting.toggleCamera()
                -- Wait briefly for the camera state to settle, then refresh
                -- and return the new state so the frontend updates immediately
                hs.timer.doAfter(1.5, function() camera.refresh() end)
                return {camera = camera.getStatus()}
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
            app_firefox        = function() apps.smartLaunch("firefox") end,
            spotify_playpause  = function() spotify.playPause() end,
            spotify_next       = function() spotify.nextTrack() end,
            spotify_prev       = function() spotify.previousTrack() end,
            spotify_shuffle    = function() spotify.toggleShuffle() end,
            spotify_repeat     = function() spotify.toggleRepeat() end,
            spotify_like       = function() spotify.likeCurrentTrack() end,
            window_next_screen = function() winManager.moveToNextScreen() end,
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

    return getHTML(), 200, corsHeaders("text/html; charset=utf-8")
end

function server.start()
    if httpServer then httpServer:stop() end

    -- Start HTTP Server on 8080
    httpServer = hs.httpserver.new(false, true)
    httpServer:setName("Hammerspoon Stream Deck")
    httpServer:setPort(port)
    httpServer:setCallback(handleRequest)
    httpServer:start()
    print("Stream Deck HTTP Server running on port " .. port)
end

return server
