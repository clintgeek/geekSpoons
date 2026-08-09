-- server.lua: Embedded HTTP & HTTPS server for Android Tablet Stream Deck (Explicit Load Button Touch Handlers)
local server = {}

local spotify = require("spotify")
local mute = require("mute")
local meeting = require("meeting")
local winManager = require("window")
local browser = require("browser")
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
    elseif path:find("/api/action/play_uri") then
        local track = path:match("track=([^&]+)")
        local context = path:match("context=([^&]+)")
        if track or context then
            track = track and hs.http.urlPartDecode(track) or ""
            context = context and hs.http.urlPartDecode(context) or ""
            hs.timer.doAfter(0, function()
                spotify.playURI(track, context)
            end)
        end
        return jsonResponse({status = "ok"})
elseif path:sub(1, 12) == "/api/action/" then
        local action = path:sub(13)

        if action == "mute_toggle" then
            local muted = mute.toggleMute()
            return jsonResponse({status = "ok", micMuted = muted})
        elseif action == "talk_start" then
            local muted = mute.startTalk()
            return jsonResponse({status = "ok", micMuted = muted})
        elseif action == "talk_stop" then
            local muted = mute.stopTalk()
            return jsonResponse({status = "ok", micMuted = muted})
        elseif action == "cam_toggle" then
            hs.timer.doAfter(0, meeting.toggleCamera)
        elseif action == "audio_cycle" then
            hs.timer.doAfter(0, audio.cycleOutput)
        elseif action == "audio_mute" then
            local muted = audio.toggleMute()
            return jsonResponse({status = "ok", audioMuted = muted})
        elseif action == "audio_volup" then
            hs.timer.doAfter(0, audio.volumeUp)
        elseif action == "audio_voldown" then
            hs.timer.doAfter(0, audio.volumeDown)
        elseif action == "snap_selection" then
            hs.timer.doAfter(0, screenshot.selection)
        elseif action == "record_screen" then
            hs.timer.doAfter(0, record.screen)
        elseif action == "app_chrome" then
            hs.timer.doAfter(0, function() apps.smartLaunch("chrome") end)
        elseif action == "app_messages" then
            hs.timer.doAfter(0, function() apps.smartLaunch("messages") end)
        elseif action == "app_chatgpt" then
            hs.timer.doAfter(0, function() apps.smartLaunch("chatgpt") end)
        elseif action == "app_teams" then
            hs.timer.doAfter(0, function() apps.smartLaunch("teams") end)
        elseif action == "app_slack" then
            hs.timer.doAfter(0, function() apps.smartLaunch("slack") end)
        elseif action == "app_outlook" then
            hs.timer.doAfter(0, function() apps.smartLaunch("outlook") end)
        elseif action == "app_firefox" then
            hs.timer.doAfter(0, function() apps.smartLaunch("firefox") end)
        elseif action == "spotify_playpause" then
            hs.timer.doAfter(0, spotify.playPause)
        elseif action == "spotify_next" then
            hs.timer.doAfter(0, spotify.nextTrack)
        elseif action == "spotify_prev" then
            hs.timer.doAfter(0, spotify.previousTrack)
        elseif action == "spotify_shuffle" then
            hs.timer.doAfter(0, spotify.toggleShuffle)
        elseif action == "spotify_repeat" then
            hs.timer.doAfter(0, spotify.toggleRepeat)
        elseif action == "spotify_like" then
            hs.timer.doAfter(0, spotify.likeCurrentTrack)
        elseif action == "window_next_screen" then
            hs.timer.doAfter(0, winManager.moveToNextScreen)
        elseif action == "window_split" then
            hs.timer.doAfter(0, winManager.split5050)
        elseif action == "spotify_open" then
            hs.timer.doAfter(0, function() hs.application.launchOrFocus("Spotify") end)
        end

        return jsonResponse({status = "ok"})
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
