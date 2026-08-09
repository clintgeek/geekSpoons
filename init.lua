-- Auto-reload Hammerspoon config on file save
local function reloadConfig(files)
    local doReload = false
    for _, file in ipairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
            break
        end
    end
    if doReload then
        hs.reload()
    end
end

if configFileWatcher then
    configFileWatcher:stop()
end
configFileWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

-- Load core modules
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
local outlookProvider = require("providers.outlook")
local slackProvider = require("providers.slack")
local teamsProvider = require("providers.teams")
local messagesProvider = require("providers.messages")
local server = require("server")

-- Register attention providers
attention.register("outlook", outlookProvider.getAttention)
attention.register("slack", slackProvider.getAttention)
attention.register("teams", teamsProvider.getAttention)
attention.register("messages", messagesProvider.getAttention)

-- Start background attention refresh (caches provider data every 10s)
attention.start()

-- Start background camera status refresh (caches ioreg data every 5s)
camera.start()

-- -- Start Messages webview for reading unread count from Google Messages
-- messagesProvider.start()

-- Start Stream Deck HTTP Server on port 8080
server.start()

-- Global Hotkey Bindings (Mac keyboard backups)
-- Hyper Key = Cmd + Alt + Ctrl + Shift
local hyper = {"cmd", "alt", "ctrl", "shift"}

-- Hyper + R: Reload Hammerspoon config manually
hs.hotkey.bind(hyper, "R", function()
    hs.reload()
end)

-- Hyper + M: Mic Mute Toggle
hs.hotkey.bind(hyper, "M", function()
    mute.toggleMute()
end)

-- Hyper + Space: Spotify Play/Pause Toggle
hs.hotkey.bind(hyper, "space", function()
    spotify.playPause()
end)

-- Hyper + S: 50/50 Window Split
hs.hotkey.bind(hyper, "S", function()
    winManager.split5050()
end)
