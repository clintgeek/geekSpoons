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
local browserUsage = require("browser_usage")

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
    local jsonStr = hs.json.encode(data)
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
    --[==[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    
    <!-- PWA Fullscreen Chromeless Meta Tags -->
    <meta name="mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <meta name="theme-color" content="#060911">
    <meta name="application-name" content="Stream Deck">
    <meta name="apple-mobile-web-app-title" content="Stream Deck">
    
    <link rel="manifest" href="/manifest.json">
    <link rel="icon" type="image/svg+xml" href="/icon.svg">
    <link rel="apple-touch-icon" href="/icon.svg">

    <title>Stream Deck</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=VT323&family=Share+Tech+Mono&family=Outfit:wght@600;700;800&family=Plus+Jakarta+Sans:wght@500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-main: #060911;
            --bg-card: rgba(18, 24, 38, 0.65);
            --border-card: rgba(255, 255, 255, 0.08);
            --border-glow: rgba(255, 255, 255, 0.18);

            --accent-red: #ff3b5c;
            --accent-red-glow: rgba(255, 59, 92, 0.4);
            --accent-green: #00e676;
            --accent-green-glow: rgba(0, 230, 118, 0.4);
            --accent-blue: #00b0ff;
            --accent-purple: #a855f7;

            --winamp-green: #00ff41;
            --winamp-yellow: #ffff00;
            --winamp-red: #ff0044;
            --winamp-metal: #232731;
            --winamp-border: #3b4150;

            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
        }

        * {
            box-sizing: border-box;
            user-select: none;
            -webkit-user-select: none;
            touch-action: manipulation;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Plus Jakarta Sans', -apple-system, sans-serif;
            background: var(--bg-main);
            background-image:
                radial-gradient(at 0% 0%, rgba(168, 85, 247, 0.15) 0px, transparent 55%),
                radial-gradient(at 100% 0%, rgba(0, 176, 255, 0.15) 0px, transparent 55%),
                radial-gradient(at 50% 100%, rgba(0, 255, 65, 0.08) 0px, transparent 55%);
            background-attachment: fixed;
            color: var(--text-primary);
            height: 100dvh;
            max-height: -webkit-fill-available;
            width: 100vw;
            overflow: hidden;
            padding: max(10px, env(safe-area-inset-top)) 14px max(10px, env(safe-area-inset-bottom)) 14px;
            display: flex;
            flex-direction: column;
            position: relative;
        }

        .main-deck {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
            flex: 1;
            min-height: 0;
            min-width: 0;
        }

        .col {
            display: flex;
            flex-direction: column;
            gap: 10px;
            height: 100%;
            min-width: 0;
            overflow: hidden;
        }

        .card-box {
            background: var(--bg-card);
            border: 1px solid var(--border-card);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border-radius: 16px;
            padding: 10px 12px;
            display: flex;
            flex-direction: column;
            gap: 8px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35);
            flex: 1;
            min-width: 0;
        }

        .section-title {
            font-family: 'Outfit', sans-serif;
            font-size: 0.78rem;
            font-weight: 700;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 1px;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .grid {
            display: grid;
            gap: 8px;
            flex: 1;
        }

        .grid-2col { grid-template-columns: repeat(2, 1fr); }
        .grid-3col { grid-template-columns: repeat(3, 1fr); }
        .grid-4col { grid-template-columns: repeat(4, 1fr); }

        .tile {
            background: rgba(255, 255, 255, 0.04);
            border: 1px solid var(--border-card);
            border-radius: 12px;
            padding: 8px 6px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 4px;
            cursor: pointer;
            transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2), inset 0 1px 0 rgba(255, 255, 255, 0.05);
            flex: 1;
        }

        .tile:hover {
            border-color: var(--border-glow);
            transform: translateY(-2px);
        }

        .tile:active {
            transform: scale(0.94);
            background: rgba(30, 41, 59, 0.85);
        }

        .tile-icon {
            font-size: 1.6rem;
            filter: drop-shadow(0 3px 6px rgba(0,0,0,0.35));
        }

        .tile-label {
            font-size: 0.75rem;
            font-weight: 700;
            color: var(--text-primary);
            text-align: center;
            line-height: 1.1;
        }

        .tile-mic.muted {
            background: linear-gradient(135deg, rgba(255, 59, 92, 0.3) 0%, rgba(20, 10, 18, 0.85) 100%);
            border: 1px solid var(--accent-red);
            box-shadow: 0 0 20px var(--accent-red-glow), inset 0 1px 0 rgba(255, 59, 92, 0.2);
        }
        .tile-mic.muted .tile-label { color: var(--accent-red); }

        .tile-mic.live {
            background: linear-gradient(135deg, rgba(0, 230, 118, 0.3) 0%, rgba(10, 24, 18, 0.85) 100%);
            border: 1px solid var(--accent-green);
            box-shadow: 0 0 20px var(--accent-green-glow), inset 0 1px 0 rgba(255, 255, 255, 0.2);
        }
        .tile-mic.live .tile-label { color: var(--accent-green); }

        .tile-sound.muted {
            background: rgba(255, 59, 92, 0.2);
            border-color: var(--accent-red);
        }

        /* GEEKAMP RETRO HERO DISPLAY CARD - STRICT FIXED WIDTH */
        .winamp-skin {
            background: var(--winamp-metal);
            border: 2px solid var(--winamp-border);
            border-radius: 14px;
            padding: 10px;
            display: flex;
            flex-direction: column;
            gap: 8px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.6), inset 1px 1px 0 #555, inset -1px -1px 0 #111;
            flex: 1.35;
            width: 100%;
            max-width: 100%;
            min-width: 0;
            overflow: hidden;
        }

        .winamp-titlebar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: linear-gradient(90deg, #111622 0%, #2a3245 100%);
            border: 1px solid #111;
            border-radius: 6px;
            padding: 4px 8px;
            font-family: 'VT323', monospace;
            font-size: 1.05rem;
            color: #00ff41;
            letter-spacing: 1px;
            text-shadow: 0 0 5px rgba(0,255,65,0.6);
            cursor: pointer;
            transition: all 0.2s ease;
            width: 100%;
            min-width: 0;
        }

        .winamp-titlebar:hover {
            border-color: #00ff41;
            box-shadow: 0 0 8px rgba(0,255,65,0.4);
        }

        .winamp-screen {
            background: #000;
            border: 2px inset #222;
            border-radius: 8px;
            padding: 8px;
            display: flex;
            flex-direction: column;
            gap: 6px;
            box-shadow: inset 0 0 10px rgba(0,255,65,0.15);
            width: 100%;
            max-width: 100%;
            min-width: 0;
            overflow: hidden;
        }

        .winamp-screen-top {
            display: flex;
            align-items: center;
            justify-content: space-between;
            width: 100%;
        }

        .winamp-timer {
            font-family: 'VT323', monospace;
            font-size: 2.1rem;
            color: var(--winamp-green);
            text-shadow: 0 0 8px var(--winamp-green);
            line-height: 1;
        }

        .winamp-info-box {
            display: flex;
            flex-direction: column;
            align-items: flex-end;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.72rem;
            color: #00ff41;
            opacity: 0.85;
        }

        /* Strict Fixed Width LCD Container */
        .winamp-marquee-container {
            background: #041004;
            border: 1px solid #005500;
            border-radius: 6px;
            padding: 5px 8px;
            height: 32px;
            width: 100%;
            max-width: 100%;
            min-width: 0;
            overflow: hidden;
            position: relative;
            display: flex;
            align-items: center;
        }

        .winamp-marquee-text {
            font-family: 'VT323', monospace;
            font-size: 1.25rem;
            color: #00ff41;
            text-shadow: 0 0 6px #00ff41;
            line-height: 1;
            white-space: nowrap;
        }

        .winamp-marquee-text.truncated {
            display: block;
            overflow: hidden;
            text-overflow: ellipsis;
            width: 100%;
            max-width: 100%;
        }

        .winamp-marquee-text.scrolling {
            display: inline-block;
            width: auto;
            max-width: none;
            animation: winampScrollOnce 6s linear 1 forwards;
        }

        @keyframes winampScrollOnce {
            0% {
                transform: translateX(0%);
            }
            15% {
                transform: translateX(0%);
            }
            85% {
                transform: translateX(var(--scroll-dist, -50%));
            }
            100% {
                transform: translateX(0%);
            }
        }

        /* 8-Band Spectrum Analyzer */
        .winamp-eq {
            display: flex;
            align-items: flex-end;
            gap: 4px;
            height: 26px;
            background: #020802;
            border: 1px solid #002200;
            border-radius: 4px;
            padding: 4px 6px;
            width: 100%;
        }

        .winamp-eq-bar {
            flex: 1;
            height: 100%;
            display: flex;
            flex-direction: column;
            justify-content: flex-end;
            gap: 2px;
        }

        .winamp-eq-seg {
            width: 100%;
            height: 4px;
            background: #002200;
            border-radius: 1px;
            opacity: 0.2;
            transition: background 0.05s, opacity 0.05s, box-shadow 0.05s;
        }

        .winamp-eq-seg.lit.seg-green {
            background: #00ff41;
            opacity: 1;
            box-shadow: 0 0 6px #00ff41;
        }

        .winamp-eq-seg.lit.seg-yellow {
            background: #ffff00;
            opacity: 1;
            box-shadow: 0 0 6px #ffff00;
        }

        .winamp-eq-seg.lit.seg-red {
            background: #ff0044;
            opacity: 1;
            box-shadow: 0 0 8px #ff0044;
        }

        .winamp-btn {
            background: linear-gradient(180deg, #444c5e 0%, #2b313d 45%, #1b1f28 50%, #151820 100%);
            border-top: 1px solid #77839b;
            border-left: 1px solid #77839b;
            border-right: 1px solid #000000;
            border-bottom: 1px solid #000000;
            border-radius: 4px;
            color: #c5d1e8;
            box-shadow: 1px 1px 0 #000, inset 1px 1px 0 rgba(255,255,255,0.25);
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 3px;
            padding: 6px 4px;
        }

        .winamp-btn:active {
            background: linear-gradient(180deg, #151820 0%, #1b1f28 50%, #2b313d 55%, #444c5e 100%);
            border-top: 1px solid #000;
            border-left: 1px solid #000;
            border-right: 1px solid #77839b;
            border-bottom: 1px solid #77839b;
            box-shadow: inset 1px 1px 3px #000;
            transform: translateY(1px);
        }

        .wa-symbol {
            font-family: 'VT323', monospace;
            font-size: 1.3rem;
            font-weight: 700;
            line-height: 1;
            text-shadow: 1px 1px 0 #000;
            color: #00ff41;
        }

        .wa-label {
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.72rem;
            font-weight: 700;
            color: #b0c0d8;
            letter-spacing: 0.5px;
        }

        .wa-led {
            width: 6px;
            height: 6px;
            border-radius: 50%;
            background-color: #003300;
            border: 1px solid #001100;
            box-shadow: inset 0 0 2px #000;
            transition: all 0.2s ease;
        }

        .winamp-btn.active-led .wa-led {
            background-color: #00ff41;
            box-shadow: 0 0 8px #00ff41;
            cursor: pointer;
            box-shadow: 0 0 16px rgba(30, 215, 96, 0.25);
            transition: transform 0.05s, box-shadow 0.1s;
        }
        .sp-btn-main:hover { transform: scale(1.04); box-shadow: 0 0 22px rgba(30, 215, 96, 0.4); }
        .sp-btn-main:active { transform: scale(0.96); }

        .sp-open-btn {
            background: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            padding: 8px 12px;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.75rem;
            font-weight: bold;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            cursor: pointer;
            margin-top: 4px;
            transition: background 0.1s;
        }
        .sp-open-btn:hover { background: var(--bg-elevated); border-color: var(--border-highlight); color: var(--text-bright); }

        /* Workspace Applications 4x2 Grid */
        .app-launcher-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 8px;
            flex: 1;
        }
        .app-launch-tile {
            background: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 6px;
            padding: 10px 4px;
            cursor: pointer;
            transition: background 0.1s, border-color 0.1s;
        }
        .app-launch-tile:hover {
            background: var(--bg-elevated);
            border-color: var(--border-highlight);
        }
        .app-tile-icon { font-size: 1.5rem; }
        .app-tile-name {
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.72rem;
            color: var(--text-primary);
            text-align: center;
        }

        /* 6. Global Status Bar */
        .app-statusbar {
            background: #06090E;
            border-top: 1px solid var(--border-color);
            padding: 4px 10px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.68rem;
            color: var(--text-secondary);
            height: 24px;
            flex-shrink: 0;
        }
        .sb-left { display: flex; align-items: center; gap: 16px; }
        .sb-right { display: flex; align-items: center; gap: 16px; }
        .sb-status-ok { color: var(--green-main); font-weight: bold; }

        /* Modal Playlist Presets */
        .retro-modal {
            position: absolute;
            top: 36px;
            right: 20px;
            width: 480px;
            background: var(--bg-panel);
            border: 1px solid var(--border-color);
            box-shadow: inset 1px 1px 0 var(--border-highlight), 0 10px 30px rgba(0,0,0,0.9);
            z-index: 1000;
            display: none;
            flex-direction: column;
            padding: 4px;
            gap: 4px;
            border-radius: 4px;
        }
        .retro-modal.active { display: flex; }
        .modal-header {
            background: var(--bg-surface);
            padding: 4px 8px;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.78rem;
            color: var(--amber-main);
            font-weight: bold;
            display: flex;
            justify-content: space-between;
        }
        .modal-close { cursor: pointer; color: var(--red-error); }
        .modal-body {
            background: var(--bg-inset);
            border: 1px solid var(--border-color);
            padding: 6px;
            display: flex;
            flex-direction: column;
            gap: 4px;
            max-height: 320px;
            overflow-y: auto;
        }
        .modal-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            color: var(--green-main);
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.75rem;
            padding: 4px 8px;
            cursor: pointer;
            background: #0B1017;
            border: 1px solid var(--border-color);
            border-radius: 3px;
        }
        .modal-item:hover {
            background: #141F2E;
            border-color: var(--amber-main);
        }
    </style>
</head>
<body>

    <!-- 1. APPLICATION SHELL FRAME -->
    <div class="app-window">

        <!-- 2. TITLE BAR -->
        <div class="app-titlebar">
            <div class="app-title-left">
                <span>🎙️</span>
                <span>HAMMERSPOON WORKSTATION CONTROLLER v2.4</span>
            </div>
            <div class="app-title-right">
                <span>HOST: LOCALHOST &nbsp;|&nbsp; WORKSTATION CONTROLLER</span>
                <div class="win-controls">
                    <span class="win-btn">_</span>
                    <span class="win-btn">□</span>
                    <span class="win-btn">×</span>
                </div>
            </div>
        </div>

        <!-- 3. MENU BAR -->
        <div class="app-menubar">
            <span class="menu-item">FILE</span>
            <span class="menu-item">EDIT</span>
            <span class="menu-item">VIEW</span>
            <span class="menu-item">AUDIO</span>
            <span class="menu-item">TOOLS</span>
            <span class="menu-item" onclick="togglePlaylistModal()">PLAYLISTS</span>
            <span class="menu-item">HELP</span>
        </div>

        <!-- 4. QUICK ACTION TOOLBAR -->
        <div class="app-toolbar">
            <button id="micBtn" class="tb-btn active-muted" onclick="triggerAction('mute_toggle')">
                <span>🎙️</span> <span id="micLabel">MIC MUTED</span>
            </button>
            <button id="sysMuteBtn" class="tb-btn" onclick="triggerAction('audio_mute')">
                <span>🔊</span> <span id="sysMuteLabel">MUTE SOUND (37%)</span>
            </button>
            <button class="tb-btn" onclick="triggerAction('audio_cycle')">
                <span>🎧</span> <span>SWITCH DEV</span>
            </button>
            <button class="tb-btn" onclick="triggerAction('snap_copy')">
                <span>📋</span> <span>CLIPBOARD</span>
            </button>
            <button class="tb-btn" onclick="triggerAction('snap_file')">
                <span>💾</span> <span>SNAP FILE</span>
            </button>
            <button id="spPlayBtn" class="tb-btn" onclick="triggerAction('spotify_playpause')">
                <span id="spPlaySymbol">►</span> <span>PLAY/PAUSE</span>
            </button>
        </div>

        <!-- 5. MAIN WORKSPACE (2-COLUMN ASYMMETRICAL LAYOUT) -->
        <div class="app-workspace">
            
            <!-- LEFT COLUMN: WORKSTATION UTILITIES -->
            <div class="col">
                
                <!-- PANEL 1: MEETING CONTROLS -->
                <div class="panel-box" style="flex: 1.05;">
                    <div class="panel-header">
                        <span>👥 MEETING CONTROLS</span>
                        <span>^</span>
                    </div>
                    <div class="panel-body">
                        <div class="meeting-grid">
                            <div id="micTile" class="meeting-tile active-muted" onclick="triggerAction('mute_toggle')">
                                <span class="meeting-icon">🎙️</span>
                                <span id="micTileLabel" class="meeting-label">MIC MUTED</span>
                            </div>
                            <div id="talkBtn" class="meeting-tile">
                                <span class="meeting-icon">🗣️</span>
                                <span class="meeting-label">PUSH TO TALK</span>
                            </div>
                            <div class="meeting-tile" onclick="triggerAction('cam_toggle')">
                                <span class="meeting-icon">📹</span>
                                <span class="meeting-label">CAMERA TOGGLE</span>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- PANEL 2: AUDIO & MIC DEVICES -->
                <div class="panel-box" style="flex: 1.35;">
                    <div class="panel-header">
                        <span>🎧 AUDIO & MIC DEVICES</span>
                        <span>^</span>
                    </div>
                    <div class="panel-body">
                        <div class="audio-grid">
                            <!-- Output Device -->
                            <div class="audio-card">
                                <span class="audio-card-icon">🔊</span>
                                <div class="audio-card-content">
                                    <span class="audio-card-meta">OUTPUT DEVICE</span>
                                    <span id="outputDevLabel" class="audio-card-val">Klipsch Groove XL</span>
                                    <span class="audio-card-status">● CONNECTED</span>
                                </div>
                            </div>
                            <!-- System Volume -->
                            <div class="vol-card">
                                <span class="audio-card-icon">🔇</span>
                                <div class="audio-card-content">
                                    <div style="display: flex; justify-content: space-between;" class="audio-card-meta">
                                        <span>SYSTEM VOLUME</span>
                                        <span id="volValText">37%</span>
                                    </div>
                                    <div class="vol-slider-track">
                                        <div class="vol-slider-fill" id="volFillBar" style="width: 37%;"></div>
                                    </div>
                                </div>
                            </div>
                            <!-- Input Device -->
                            <div class="audio-card">
                                <span class="audio-card-icon">🎙️</span>
                                <div class="audio-card-content">
                                    <span class="audio-card-meta">INPUT DEVICE</span>
                                    <span class="audio-card-val">Internal Microphone</span>
                                    <span class="audio-card-status">● ACTIVE</span>
                                </div>
                            </div>
                            <!-- Mic Volume -->
                            <div class="vol-card">
                                <span class="audio-card-icon">🎚️</span>
                                <div class="audio-card-content">
                                    <div style="display: flex; justify-content: space-between;" class="audio-card-meta">
                                        <span>MIC VOLUME</span>
                                        <span>46%</span>
                                    </div>
                                    <div class="vol-slider-track">
                                        <div class="vol-slider-fill" style="width: 46%;"></div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Audio Control Action Buttons -->
                        <div class="audio-actions-row">
                            <button class="btn-audio-sub" onclick="triggerAction('audio_voldown')">
                                <span>VOL -</span>
                                <span>🔉</span>
                            </button>
                            <button class="btn-audio-sub" onclick="triggerAction('audio_cycle')">
                                <span>AUDIO SETTINGS</span>
                                <span style="color: var(--text-secondary); font-size: 0.6rem;">SOUND PREFERENCES</span>
                            </button>
                            <button class="btn-audio-sub" onclick="triggerAction('audio_volup')">
                                <span>VOL +</span>
                                <span>🔊</span>
                            </button>
                        </div>
                    </div>
                </div>

                <!-- PANEL 3: SCREEN CAPTURE & REGION -->
                <div class="panel-box" style="flex: 1.05;">
                    <div class="panel-header">
                        <span>📸 SCREEN CAPTURE & REGION</span>
                        <span>^</span>
                    </div>
                    <div class="panel-body">
                        <div class="snap-grid">
                            <div class="snap-btn" onclick="triggerAction('snap_copy')">
                                <span class="snap-icon">📋</span>
                                <span class="snap-title">RECTANGLE ➔ CLIPBOARD</span>
                                <span class="snap-desc">CAPTURE AREA</span>
                            </div>
                            <div class="snap-btn" onclick="triggerAction('snap_file')">
                                <span class="snap-icon">💾</span>
                                <span class="snap-title">RECTANGLE ➔ FILE</span>
                                <span class="snap-desc">SAVE TO DISK</span>
                            </div>
                        </div>
                    </div>
                </div>

            </div>

            <!-- RIGHT COLUMN: SPOTIFY & APPLICATIONS -->
            <div class="col">

                <!-- PANEL 4: SPOTIFY MEDIA CONTROLLER -->
                <div class="spotify-panel">
                    <div class="spotify-header">
                        <span>🟢 SPOTIFY MEDIA CONTROLLER</span>
                        <span>^</span>
                    </div>
                    <div class="panel-body">
                        
                        <!-- Now Playing Card -->
                        <div class="sp-now-playing">
                            <img src="https://i.scdn.co/image/ab67616d0000b273b4009a25b59740e53a2908f0" class="sp-album-art" alt="Album Cover" onerror="this.src='data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' width=\'180\' height=\'180\'><rect width=\'100%\' height=\'100%\' fill=\'%23151c28\'/><text x=\'50%\' y=\'50%\' fill=\'%231ED760\' font-size=\'40\' text-anchor=\'middle\' dy=\'.3em\'>🎵</text></svg>'">
                            
                            <div class="sp-meta-col">
                                <div>
                                    <div class="sp-top-meta">
                                        <span class="sp-now-tag">🟢 NOW PLAYING</span>
                                        <span class="sp-conn-tag">
                                            <span style="color: var(--spotify-green);">●</span> SPOTIFY CONNECTED &nbsp;•&nbsp; 320 kbps
                                        </span>
                                    </div>
                                    <div id="waTrackTitle" class="sp-track-title">Plush (Acoustic)</div>
                                    <div id="waArtistName" class="sp-artist-name">Stone Temple Pilots</div>
                                    <div id="waAlbumName" class="sp-album-name">Thank You (20th Anniversary Super Deluxe)</div>
                                    
                                    <div class="sp-tags-row">
                                        <span class="sp-tag-pill">ACOUSTIC</span>
                                        <span class="sp-tag-pill">ROCK</span>
                                        <span class="sp-tag-pill">1994</span>
                                    </div>
                                </div>

                                <!-- Equalizer Spectrum Bars -->
                                <div class="sp-spectrum-container">
                                    <div class="sp-bar" style="height: 40%;"></div>
                                    <div class="sp-bar" style="height: 75%;"></div>
                                    <div class="sp-bar" style="height: 30%;"></div>
                                    <div class="sp-bar" style="height: 90%;"></div>
                                    <div class="sp-bar" style="height: 60%;"></div>
                                    <div class="sp-bar" style="height: 100%;"></div>
                                    <div class="sp-bar" style="height: 45%;"></div>
                                    <div class="sp-bar" style="height: 80%;"></div>
                                    <div class="sp-bar" style="height: 35%;"></div>
                                    <div class="sp-bar" style="height: 65%;"></div>
                                    <div class="sp-bar" style="height: 95%;"></div>
                                    <div class="sp-bar" style="height: 50%;"></div>
                                    <div class="sp-bar" style="height: 85%;"></div>
                                    <div class="sp-bar" style="height: 40%;"></div>
                                    <div class="sp-bar" style="height: 70%;"></div>
                                    <div class="sp-bar" style="height: 30%;"></div>
                                    <div class="sp-bar" style="height: 88%;"></div>
                                    <div class="sp-bar" style="height: 55%;"></div>
                                </div>
                            </div>
                        </div>

                        <!-- Progress Bar Slider -->
                        <div class="sp-progress-row">
                            <span id="waTimer">00:18</span>
                            <div class="sp-progress-track">
                                <div class="sp-progress-fill" id="spProgressFill" style="width: 25%;">
                                    <div class="sp-progress-thumb"></div>
                                </div>
                            </div>
                            <span id="waTotalTime">04:43</span>
                        </div>

                        <!-- Playback Transport Row -->
                        <div class="sp-transport-row">
                            <button id="shufBtn" class="sp-btn-sub" onclick="triggerAction('spotify_shuffle')">🔀</button>
                            <button class="sp-btn-sub" onclick="triggerAction('spotify_prev')">|◄◄</button>
                            <button id="spPlayBtnMain" class="sp-btn-main" onclick="triggerAction('spotify_playpause')">
                                <span id="spPlaySymbolMain">❚❚</span>
                            </button>
                            <button class="sp-btn-sub" onclick="triggerAction('spotify_next')">►►|</button>
                            <button id="repBtn" class="sp-btn-sub" onclick="triggerAction('spotify_repeat')">🔁</button>
                            <button class="sp-btn-sub" onclick="triggerAction('spotify_like')">♥</button>
                        </div>

                        <!-- Open Spotify Portal Button -->
                        <button class="sp-open-btn" onclick="triggerAction('app_spotify')">
                            <span>OPEN SPOTIFY</span>
                            <span style="font-size: 0.85rem;">↗</span>
                        </button>

                    </div>
                </div>

                <!-- PANEL 5: WORKSPACE APPLICATIONS -->
                <div class="panel-box" style="flex: 1.1;">
                    <div class="panel-header">
                        <span>🎛️ WORKSPACE APPLICATIONS</span>
                        <span>^</span>
                    </div>
                    <div class="panel-body">
                        <div class="app-launcher-grid">
                            <div class="app-launch-tile" onclick="triggerAction('app_chrome')">
                                <span class="app-tile-icon">🌐</span>
                                <span class="app-tile-name">Chrome</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_messages')">
                                <span class="app-tile-icon">💬</span>
                                <span class="app-tile-name">Messages</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_chatgpt')">
                                <span class="app-tile-icon">🤖</span>
                                <span class="app-tile-name">ChatGPT</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_teams')">
                                <span class="app-tile-icon">👥</span>
                                <span class="app-tile-name">Teams</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_slack')">
                                <span class="app-tile-icon">📢</span>
                                <span class="app-tile-name">Slack</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_outlook')">
                                <span class="app-tile-icon">✉️</span>
                                <span class="app-tile-name">Outlook</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_firefox')">
                                <span class="app-tile-icon">🦊</span>
                                <span class="app-tile-name">Firefox</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('window_next_screen')">
                                <span class="app-tile-icon">🖥️</span>
                                <span class="app-tile-name">Next Display</span>
                            </div>
                        </div>
                    </div>
                </div>

            </div>

        </div>

        <!-- 6. GLOBAL STATUS BAR -->
        <div class="app-statusbar">
            <div class="sb-left">
                <span>STATUS: <span class="sb-status-ok">SYSTEM OPERATIONAL</span></span>
                <span>UPTIME: 3D 14H 22M</span>
            </div>
            <div class="sb-right">
                <span>CPU: 12%</span>
                <span>MEM: 43%</span>
                <span>MAY 12, 2025 &nbsp;10:24:38 AM</span>
            </div>
        </div>

    </div>

    <!-- MODAL 1: GEEKAMP PLAYLIST PRESETS -->
    <div id="playlistModal" class="retro-modal">
        <div class="modal-header">
            <span>*** SPOTIFY PLAYLIST PRESETS ***</span>
            <span class="modal-close" onclick="togglePlaylistModal()">[X]</span>
        </div>
        <div class="modal-body">
            <div class="modal-item" onclick="playUri('spotify:track:1DCdIWCE5UFiObCsTSpKFv', 'spotify:playlist:0NyPLheWZbkk2wgwq7NIC8')">
                <span>01. 🌧️ Rust and Rain</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('spotify:track:1DCdIWCE5UFiObCsTSpKFv', 'spotify:playlist:0NyPLheWZbkk2wgwq7NIC8'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:7zaZlzl0XhthNwH3GQcyZ0', 'spotify:playlist:7Eldq78AevyJ8vSnbGpu9d')">
                <span>02. ⛰️ Peak</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('spotify:track:7zaZlzl0XhthNwH3GQcyZ0', 'spotify:playlist:7Eldq78AevyJ8vSnbGpu9d'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:5vYA1mW9g2Coh1HUFUSmlb', 'spotify:playlist:6PP4LnUwxEYitIC9Z0dOv1')">
                <span>03. 🚗 Windows Down Crusin'</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('spotify:track:5vYA1mW9g2Coh1HUFUSmlb', 'spotify:playlist:6PP4LnUwxEYitIC9Z0dOv1'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:5eewTcv33R0w9DmyJU9R1W', 'spotify:playlist:37i9dQZF1DX2TRYkJECvfC')">
                <span>04. ☕ Deep House Relax</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('spotify:track:5eewTcv33R0w9DmyJU9R1W', 'spotify:playlist:37i9dQZF1DX2TRYkJECvfC'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:3ckd4YA4LcD3j50rfIVwUe', 'spotify:playlist:0BsPYkpv2PWHCNiYzn2eTa')">
                <span>05. ⚡ Anger Management 101</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('spotify:track:3ckd4YA4LcD3j50rfIVwUe', 'spotify:playlist:0BsPYkpv2PWHCNiYzn2eTa'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('', 'spotify:user:spotify:collection')">
                <span>06. ❤️ Your Liked Songs</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('', 'spotify:user:spotify:collection'); event.stopPropagation();">[LOAD]</button>
            </div>
        </div>
    </div>

  function getHTML() {
    return [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    
    <!-- PWA Fullscreen Chromeless Meta Tags -->
    <meta name="mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <meta name="theme-color" content="#080D13">
    <meta name="application-name" content="Workstation Controller">
    <meta name="apple-mobile-web-app-title" content="Workstation Controller">
    
    <link rel="manifest" href="/manifest.json">
    <link rel="icon" type="image/svg+xml" href="/icon.svg">
    <link rel="apple-touch-icon" href="/icon.svg">

    <title>Hammerspoon Workstation Controller v2.4</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=Plus+Jakarta+Sans:wght@500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-canvas: #080D13;
            --bg-panel: #101722;
            --bg-surface: #151C28;
            --bg-elevated: #19212E;
            --bg-inset: #080D12;
            
            --border-color: #293544;
            --border-highlight: #344253;
            
            --text-primary: #D8DEE7;
            --text-secondary: #8492A6;
            --text-bright: #FFFFFF;
            
            --amber-main: #D6A73A;
            --amber-bright: #E5B84B;
            
            --green-main: #18D866;
            --green-dark: #063A25;
            --spotify-green: #1ED760;
            --red-error: #E5484D;
        }

        * {
            box-sizing: border-box;
            user-select: none;
            -webkit-user-select: none;
            touch-action: manipulation;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Plus Jakarta Sans', -apple-system, sans-serif;
            background: var(--bg-canvas);
            color: var(--text-primary);
            height: 100dvh;
            width: 100vw;
            overflow: hidden;
            padding: max(4px, env(safe-area-inset-top)) 8px max(4px, env(safe-area-inset-bottom)) 8px;
            display: flex;
            flex-direction: column;
        }

        /* 1. App Window Shell */
        .app-window {
            background: var(--bg-canvas);
            border: 1px solid var(--border-color);
            box-shadow: inset 1px 1px 0 var(--border-highlight), 0 10px 40px rgba(0,0,0,0.9);
            display: flex;
            flex-direction: column;
            height: 100%;
            width: 100%;
            overflow: hidden;
            border-radius: 4px;
        }

        /* 2. Title Bar */
        .app-titlebar {
            background: #0A0F18;
            border-bottom: 1px solid var(--border-color);
            padding: 4px 10px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            height: 28px;
            flex-shrink: 0;
            font-family: 'Share Tech Mono', monospace;
        }

        .app-title-left {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 0.8rem;
            font-weight: bold;
            color: var(--amber-main);
            letter-spacing: 0.5px;
        }

        .app-title-right {
            display: flex;
            align-items: center;
            gap: 16px;
            font-size: 0.72rem;
            color: var(--text-secondary);
        }

        .win-controls {
            display: flex;
            gap: 6px;
        }
        .win-btn {
            color: var(--text-secondary);
            font-size: 0.75rem;
            cursor: pointer;
            width: 14px;
            text-align: center;
        }
        .win-btn:hover { color: var(--text-bright); }

        /* 3. Menu Bar */
        .app-menubar {
            background: #0D131D;
            border-bottom: 1px solid var(--border-color);
            padding: 3px 12px;
            display: flex;
            gap: 16px;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.72rem;
            color: var(--amber-main);
            flex-shrink: 0;
        }
        .menu-item { cursor: pointer; opacity: 0.85; }
        .menu-item:hover { opacity: 1; text-decoration: underline; }

        /* 4. Toolbar */
        .app-toolbar {
            background: #0F1622;
            border-bottom: 1px solid var(--border-color);
            padding: 4px 10px;
            display: flex;
            align-items: center;
            gap: 6px;
            height: 38px;
            flex-shrink: 0;
        }
        .tb-btn {
            background: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 3px;
            color: var(--text-primary);
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.72rem;
            font-weight: bold;
            padding: 4px 10px;
            display: flex;
            align-items: center;
            gap: 6px;
            cursor: pointer;
            height: 28px;
            transition: background 0.1s;
        }
        .tb-btn:hover {
            background: var(--bg-elevated);
            border-color: var(--border-highlight);
        }
        .tb-btn.active-live {
            background: rgba(24, 216, 102, 0.12);
            border-color: var(--green-main);
            color: var(--green-main);
            box-shadow: 0 0 8px rgba(24, 216, 102, 0.2);
        }
        .tb-btn.active-muted {
            background: rgba(229, 72, 77, 0.12);
            border-color: var(--red-error);
            color: var(--red-error);
        }

        /* 5. Main Workspace Layout */
        .app-workspace {
            display: grid;
            grid-template-columns: 42.5% 57.5%;
            gap: 10px;
            padding: 10px;
            flex: 1;
            min-height: 0;
            overflow: hidden;
        }

        .col {
            display: flex;
            flex-direction: column;
            gap: 10px;
            height: 100%;
            min-width: 0;
            overflow: hidden;
        }

        /* Framed Application Panels */
        .panel-box {
            background: var(--bg-panel);
            border: 1px solid var(--border-color);
            border-radius: 5px;
            box-shadow: inset 1px 1px 0 rgba(255,255,255,0.03), 0 4px 12px rgba(0,0,0,0.4);
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }

        .panel-header {
            padding: 6px 10px;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.78rem;
            font-weight: bold;
            color: var(--amber-main);
            letter-spacing: 0.5px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-shrink: 0;
            border-bottom: 1px solid rgba(41, 53, 68, 0.5);
        }

        .panel-body {
            padding: 10px;
            display: flex;
            flex-direction: column;
            gap: 8px;
            flex: 1;
            overflow-y: auto;
        }

        /* Meeting Controls 3-Column Grid */
        .meeting-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 8px;
            flex: 1;
        }

        .meeting-tile {
            background: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 10px;
            cursor: pointer;
            padding: 12px 6px;
            transition: background 0.1s, border-color 0.1s;
        }
        .meeting-tile:hover {
            background: var(--bg-elevated);
            border-color: var(--border-highlight);
        }

        .meeting-tile.active-live {
            background: linear-gradient(180deg, rgba(24, 216, 102, 0.15) 0%, rgba(6, 58, 37, 0.3) 100%);
            border: 1.5px solid var(--green-main);
            box-shadow: inset 0 0 12px rgba(24, 216, 102, 0.2), 0 0 10px rgba(24, 216, 102, 0.15);
        }
        .meeting-tile.active-live .meeting-icon { color: var(--green-main); }
        .meeting-tile.active-live .meeting-label { color: var(--green-main); font-weight: bold; }

        .meeting-tile.active-muted {
            background: linear-gradient(180deg, rgba(229, 72, 77, 0.15) 0%, rgba(58, 6, 10, 0.3) 100%);
            border: 1.5px solid var(--red-error);
        }
        .meeting-tile.active-muted .meeting-icon { color: var(--red-error); }
        .meeting-tile.active-muted .meeting-label { color: var(--red-error); font-weight: bold; }

        .meeting-icon { font-size: 1.6rem; color: var(--text-secondary); }
        .meeting-label {
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.75rem;
            color: var(--text-primary);
            text-align: center;
        }

        /* Audio & Mic Devices Panel */
        .audio-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 8px;
        }

        .audio-card {
            background: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            padding: 8px 10px;
            display: flex;
            gap: 10px;
            align-items: center;
        }

        .audio-card-icon { font-size: 1.4rem; color: var(--text-secondary); flex-shrink: 0; }
        .audio-card-content { display: flex; flex-direction: column; gap: 2px; flex: 1; min-width: 0; }
        .audio-card-meta { font-family: 'Share Tech Mono', monospace; font-size: 0.65rem; color: var(--text-secondary); }
        .audio-card-val { font-size: 0.82rem; font-weight: 700; color: var(--text-bright); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .audio-card-status { font-family: 'Share Tech Mono', monospace; font-size: 0.65rem; color: var(--green-main); display: flex; align-items: center; gap: 4px; }

        /* Volume Controls with Sliders */
        .vol-card {
            background: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            padding: 8px 10px;
            display: flex;
            gap: 8px;
            align-items: center;
        }

        .vol-slider-track {
            flex: 1;
            height: 5px;
            background: var(--bg-inset);
            border-radius: 3px;
            position: relative;
            overflow: hidden;
            border: 1px solid rgba(255,255,255,0.05);
        }
        .vol-slider-fill {
            height: 100%;
            background: linear-gradient(90deg, #967425 0%, var(--amber-main) 100%);
            border-radius: 3px;
        }

        .audio-actions-row {
            display: grid;
            grid-template-columns: 1fr 1.5fr 1fr;
            gap: 8px;
            margin-top: 2px;
        }
        .btn-audio-sub {
            background: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 3px;
            padding: 6px 8px;
            color: var(--text-primary);
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.7rem;
            cursor: pointer;
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 3px;
            transition: background 0.1s;
        }
        .btn-audio-sub:hover { background: var(--bg-elevated); border-color: var(--border-highlight); }

        /* Screen Capture Panel */
        .snap-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 8px;
            flex: 1;
        }
        .snap-btn {
            background: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            padding: 10px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 6px;
            cursor: pointer;
            transition: background 0.1s;
        }
        .snap-btn:hover { background: var(--bg-elevated); border-color: var(--border-highlight); }
        .snap-icon { font-size: 1.4rem; color: var(--text-secondary); }
        .snap-title { font-family: 'Share Tech Mono', monospace; font-size: 0.72rem; font-weight: bold; color: var(--text-bright); text-align: center; }
        .snap-desc { font-family: 'Share Tech Mono', monospace; font-size: 0.62rem; color: var(--text-secondary); text-align: center; }

        /* Spotify Subsystem Container */
        .spotify-panel {
            background: #0A1118;
            border: 1px solid #1A2B20;
            border-radius: 5px;
            box-shadow: inset 0 0 20px rgba(30, 215, 96, 0.04), 0 4px 12px rgba(0,0,0,0.5);
            display: flex;
            flex-direction: column;
            overflow: hidden;
            flex: 1.3;
        }
        .spotify-header {
            padding: 6px 10px;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.78rem;
            font-weight: bold;
            color: var(--amber-main);
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid #17261C;
        }

        /* Spotify Now Playing Card */
        .sp-now-playing {
            background: #080D14;
            border: 1px solid #16241B;
            border-radius: 4px;
            padding: 10px;
            display: flex;
            gap: 12px;
        }
        .sp-album-art {
            width: 175px;
            height: 175px;
            border-radius: 4px;
            object-fit: cover;
            border: 1px solid var(--border-color);
            box-shadow: 0 4px 12px rgba(0,0,0,0.6);
            flex-shrink: 0;
            background: #151c28;
        }
        .sp-meta-col {
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            flex: 1;
            min-width: 0;
        }
        .sp-top-meta {
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.68rem;
        }
        .sp-now-tag { color: var(--spotify-green); font-weight: bold; display: flex; align-items: center; gap: 4px; }
        .sp-conn-tag { color: var(--text-secondary); display: flex; align-items: center; gap: 4px; }
        .sp-track-title { font-size: 1.25rem; font-weight: 800; color: var(--text-bright); margin-top: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .sp-artist-name { font-size: 0.88rem; font-weight: 700; color: var(--amber-main); margin-top: 1px; }
        .sp-album-name { font-size: 0.75rem; color: var(--text-secondary); margin-top: 1px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

        .sp-tags-row { display: flex; gap: 6px; margin-top: 6px; }
        .sp-tag-pill {
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.6rem;
            color: var(--spotify-green);
            background: rgba(30, 215, 96, 0.08);
            border: 1px solid rgba(30, 215, 96, 0.2);
            padding: 1px 5px;
            border-radius: 2px;
        }

        /* Equalizer Spectrum Bars */
        .sp-spectrum-container {
            display: flex;
            align-items: flex-end;
            gap: 2px;
            height: 24px;
            margin-top: 6px;
            padding-top: 4px;
        }
        .sp-bar {
            flex: 1;
            background: linear-gradient(180deg, #1ED760 0%, #0c5928 100%);
            border-radius: 1px 1px 0 0;
            min-height: 2px;
            opacity: 0.85;
        }

        /* Spotify Progress Slider */
        .sp-progress-row {
            display: flex;
            align-items: center;
            gap: 10px;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.7rem;
            color: var(--text-secondary);
            margin-top: 6px;
        }
        .sp-progress-track {
            flex: 1;
            height: 5px;
            background: var(--bg-inset);
            border-radius: 3px;
            position: relative;
            border: 1px solid rgba(255,255,255,0.05);
        }
        .sp-progress-fill {
            height: 100%;
            width: 12%;
            background: var(--amber-main);
            border-radius: 3px;
            position: relative;
        }
        .sp-progress-thumb {
            width: 10px;
            height: 10px;
            background: var(--amber-bright);
            border-radius: 50%;
            position: absolute;
            right: -4px;
            top: -2.5px;
            box-shadow: 0 0 6px var(--amber-main);
        }

        /* Spotify Transport Row */
        .sp-transport-row {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
            margin-top: 4px;
        }
        .sp-btn-sub {
            background: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            width: 36px;
            height: 36px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--spotify-green);
            font-size: 0.9rem;
            cursor: pointer;
            transition: background 0.1s;
        }
        .sp-btn-sub:hover { background: var(--bg-elevated); border-color: var(--spotify-green); }
        .sp-btn-sub.active { background: rgba(30, 215, 96, 0.15); border-color: var(--spotify-green); }

        .sp-btn-main {
            background: #0A1610;
            border: 2px solid var(--spotify-green);
            border-radius: 50%;
            width: 58px;
            height: 58px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--spotify-green);
            font-size: 1.3rem;
            cursor: pointer;
            box-shadow: 0 0 16px rgba(30, 215, 96, 0.25);
            transition: transform 0.05s, box-shadow 0.1s;
        }
        .sp-btn-main:hover { transform: scale(1.04); box-shadow: 0 0 22px rgba(30, 215, 96, 0.4); }
        .sp-btn-main:active { transform: scale(0.96); }

        .sp-open-btn {
            background: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            padding: 8px 12px;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.75rem;
            font-weight: bold;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            cursor: pointer;
            margin-top: 4px;
            transition: background 0.1s;
        }
        .sp-open-btn:hover { background: var(--bg-elevated); border-color: var(--border-highlight); color: var(--text-bright); }

        /* Workspace Applications 4x2 Grid */
        .app-launcher-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 8px;
            flex: 1;
        }
        .app-launch-tile {
            background: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 6px;
            padding: 10px 4px;
            cursor: pointer;
            transition: background 0.1s, border-color 0.1s;
        }
        .app-launch-tile:hover {
            background: var(--bg-elevated);
            border-color: var(--border-highlight);
        }
        .app-tile-icon { font-size: 1.5rem; }
        .app-tile-name {
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.72rem;
            color: var(--text-primary);
            text-align: center;
        }

        /* 6. Global Status Bar */
        .app-statusbar {
            background: #06090E;
            border-top: 1px solid var(--border-color);
            padding: 4px 10px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.68rem;
            color: var(--text-secondary);
            height: 24px;
            flex-shrink: 0;
        }
        .sb-left { display: flex; align-items: center; gap: 16px; }
        .sb-right { display: flex; align-items: center; gap: 16px; }
        .sb-status-ok { color: var(--green-main); font-weight: bold; }

        /* Modal Playlist Presets */
        .retro-modal {
            position: absolute;
            top: 36px;
            right: 20px;
            width: 480px;
            background: var(--bg-panel);
            border: 1px solid var(--border-color);
            box-shadow: inset 1px 1px 0 var(--border-highlight), 0 10px 30px rgba(0,0,0,0.9);
            z-index: 1000;
            display: none;
            flex-direction: column;
            padding: 4px;
            gap: 4px;
            border-radius: 4px;
        }
        .retro-modal.active { display: flex; }
        .modal-header {
            background: var(--bg-surface);
            padding: 4px 8px;
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.78rem;
            color: var(--amber-main);
            font-weight: bold;
            display: flex;
            justify-content: space-between;
        }
        .modal-close { cursor: pointer; color: var(--red-error); }
        .modal-body {
            background: var(--bg-inset);
            border: 1px solid var(--border-color);
            padding: 6px;
            display: flex;
            flex-direction: column;
            gap: 4px;
            max-height: 320px;
            overflow-y: auto;
        }
        .modal-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            color: var(--green-main);
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.75rem;
            padding: 4px 8px;
            cursor: pointer;
            background: #0B1017;
            border: 1px solid var(--border-color);
            border-radius: 3px;
        }
        .modal-item:hover {
            background: #141F2E;
            border-color: var(--amber-main);
        }
    </style>
</head>
<body>

    <!-- 1. APPLICATION SHELL FRAME -->
    <div class="app-window">

        <!-- 2. TITLE BAR -->
        <div class="app-titlebar">
            <div class="app-title-left">
                <span>🎙️</span>
                <span>HAMMERSPOON WORKSTATION CONTROLLER v2.4</span>
            </div>
            <div class="app-title-right">
                <span>HOST: LOCALHOST &nbsp;|&nbsp; WORKSTATION CONTROLLER</span>
                <div class="win-controls">
                    <span class="win-btn">_</span>
                    <span class="win-btn">□</span>
                    <span class="win-btn">×</span>
                </div>
            </div>
        </div>

        <!-- 3. MENU BAR -->
        <div class="app-menubar">
            <span class="menu-item">FILE</span>
            <span class="menu-item">EDIT</span>
            <span class="menu-item">VIEW</span>
            <span class="menu-item">AUDIO</span>
            <span class="menu-item">TOOLS</span>
            <span class="menu-item" onclick="togglePlaylistModal()">PLAYLISTS</span>
            <span class="menu-item">HELP</span>
        </div>

        <!-- 4. QUICK ACTION TOOLBAR -->
        <div class="app-toolbar">
            <button id="micBtn" class="tb-btn active-muted" onclick="triggerAction('mute_toggle')">
                <span>🎙️</span> <span id="micLabel">MIC MUTED</span>
            </button>
            <button id="sysMuteBtn" class="tb-btn" onclick="triggerAction('audio_mute')">
                <span>🔊</span> <span id="sysMuteLabel">MUTE SOUND (37%)</span>
            </button>
            <button class="tb-btn" onclick="triggerAction('audio_cycle')">
                <span>🎧</span> <span>SWITCH DEV</span>
            </button>
            <button class="tb-btn" onclick="triggerAction('snap_copy')">
                <span>📋</span> <span>CLIPBOARD</span>
            </button>
            <button class="tb-btn" onclick="triggerAction('snap_file')">
                <span>💾</span> <span>SNAP FILE</span>
            </button>
            <button id="spPlayBtn" class="tb-btn" onclick="triggerAction('spotify_playpause')">
                <span id="spPlaySymbol">►</span> <span>PLAY/PAUSE</span>
            </button>
        </div>

        <!-- 5. MAIN WORKSPACE (2-COLUMN ASYMMETRICAL LAYOUT) -->
        <div class="app-workspace">
            
            <!-- LEFT COLUMN: WORKSTATION UTILITIES -->
            <div class="col">
                
                <!-- PANEL 1: MEETING CONTROLS -->
                <div class="panel-box" style="flex: 1.05;">
                    <div class="panel-header">
                        <span>👥 MEETING CONTROLS</span>
                        <span>^</span>
                    </div>
                    <div class="panel-body">
                        <div class="meeting-grid">
                            <div id="micTile" class="meeting-tile active-muted" onclick="triggerAction('mute_toggle')">
                                <span class="meeting-icon">🎙️</span>
                                <span id="micTileLabel" class="meeting-label">MIC MUTED</span>
                            </div>
                            <div id="talkBtn" class="meeting-tile">
                                <span class="meeting-icon">🗣️</span>
                                <span class="meeting-label">PUSH TO TALK</span>
                            </div>
                            <div class="meeting-tile" onclick="triggerAction('cam_toggle')">
                                <span class="meeting-icon">📹</span>
                                <span class="meeting-label">CAMERA TOGGLE</span>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- PANEL 2: AUDIO & MIC DEVICES -->
                <div class="panel-box" style="flex: 1.35;">
                    <div class="panel-header">
                        <span>🎧 AUDIO & MIC DEVICES</span>
                        <span>^</span>
                    </div>
                    <div class="panel-body">
                        <div class="audio-grid">
                            <!-- Output Device -->
                            <div class="audio-card">
                                <span class="audio-card-icon">🔊</span>
                                <div class="audio-card-content">
                                    <span class="audio-card-meta">OUTPUT DEVICE</span>
                                    <span id="outputDevLabel" class="audio-card-val">Klipsch Groove XL</span>
                                    <span class="audio-card-status">● CONNECTED</span>
                                </div>
                            </div>
                            <!-- System Volume -->
                            <div class="vol-card">
                                <span class="audio-card-icon">🔇</span>
                                <div class="audio-card-content">
                                    <div style="display: flex; justify-content: space-between;" class="audio-card-meta">
                                        <span>SYSTEM VOLUME</span>
                                        <span id="volValText">37%</span>
                                    </div>
                                    <div class="vol-slider-track">
                                        <div class="vol-slider-fill" id="volFillBar" style="width: 37%;"></div>
                                    </div>
                                </div>
                            </div>
                            <!-- Input Device -->
                            <div class="audio-card">
                                <span class="audio-card-icon">🎙️</span>
                                <div class="audio-card-content">
                                    <span class="audio-card-meta">INPUT DEVICE</span>
                                    <span class="audio-card-val">Internal Microphone</span>
                                    <span class="audio-card-status">● ACTIVE</span>
                                </div>
                            </div>
                            <!-- Mic Volume -->
                            <div class="vol-card">
                                <span class="audio-card-icon">🎚️</span>
                                <div class="audio-card-content">
                                    <div style="display: flex; justify-content: space-between;" class="audio-card-meta">
                                        <span>MIC VOLUME</span>
                                        <span>46%</span>
                                    </div>
                                    <div class="vol-slider-track">
                                        <div class="vol-slider-fill" style="width: 46%;"></div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Audio Control Action Buttons -->
                        <div class="audio-actions-row">
                            <button class="btn-audio-sub" onclick="triggerAction('audio_voldown')">
                                <span>VOL -</span>
                                <span>🔉</span>
                            </button>
                            <button class="btn-audio-sub" onclick="triggerAction('audio_cycle')">
                                <span>AUDIO SETTINGS</span>
                                <span style="color: var(--text-secondary); font-size: 0.6rem;">SOUND PREFERENCES</span>
                            </button>
                            <button class="btn-audio-sub" onclick="triggerAction('audio_volup')">
                                <span>VOL +</span>
                                <span>🔊</span>
                            </button>
                        </div>
                    </div>
                </div>

                <!-- PANEL 3: SCREEN CAPTURE & REGION -->
                <div class="panel-box" style="flex: 1.05;">
                    <div class="panel-header">
                        <span>📸 SCREEN CAPTURE & REGION</span>
                        <span>^</span>
                    </div>
                    <div class="panel-body">
                        <div class="snap-grid">
                            <div class="snap-btn" onclick="triggerAction('snap_copy')">
                                <span class="snap-icon">📋</span>
                                <span class="snap-title">RECTANGLE ➔ CLIPBOARD</span>
                                <span class="snap-desc">CAPTURE AREA</span>
                            </div>
                            <div class="snap-btn" onclick="triggerAction('snap_file')">
                                <span class="snap-icon">💾</span>
                                <span class="snap-title">RECTANGLE ➔ FILE</span>
                                <span class="snap-desc">SAVE TO DISK</span>
                            </div>
                        </div>
                    </div>
                </div>

            </div>

            <!-- RIGHT COLUMN: SPOTIFY & APPLICATIONS -->
            <div class="col">

                <!-- PANEL 4: SPOTIFY MEDIA CONTROLLER -->
                <div class="spotify-panel">
                    <div class="spotify-header">
                        <span>🟢 SPOTIFY MEDIA CONTROLLER</span>
                        <span>^</span>
                    </div>
                    <div class="panel-body">
                        
                        <!-- Now Playing Card -->
                        <div class="sp-now-playing">
                            <img src="https://i.scdn.co/image/ab67616d0000b273b4009a25b59740e53a2908f0" class="sp-album-art" alt="Album Cover" onerror="this.src='data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' width=\'180\' height=\'180\'><rect width=\'100%\' height=\'100%\' fill=\'%23151c28\'/><text x=\'50%\' y=\'50%\' fill=\'%231ED760\' font-size=\'40\' text-anchor=\'middle\' dy=\'.3em\'>🎵</text></svg>'">
                            
                            <div class="sp-meta-col">
                                <div>
                                    <div class="sp-top-meta">
                                        <span class="sp-now-tag">🟢 NOW PLAYING</span>
                                        <span class="sp-conn-tag">
                                            <span style="color: var(--spotify-green);">●</span> SPOTIFY CONNECTED &nbsp;•&nbsp; 320 kbps
                                        </span>
                                    </div>
                                    <div id="waTrackTitle" class="sp-track-title">Plush (Acoustic)</div>
                                    <div id="waArtistName" class="sp-artist-name">Stone Temple Pilots</div>
                                    <div id="waAlbumName" class="sp-album-name">Thank You (20th Anniversary Super Deluxe)</div>
                                    
                                    <div class="sp-tags-row">
                                        <span class="sp-tag-pill">ACOUSTIC</span>
                                        <span class="sp-tag-pill">ROCK</span>
                                        <span class="sp-tag-pill">1994</span>
                                    </div>
                                </div>

                                <!-- Equalizer Spectrum Bars -->
                                <div class="sp-spectrum-container">
                                    <div class="sp-bar" style="height: 40%;"></div>
                                    <div class="sp-bar" style="height: 75%;"></div>
                                    <div class="sp-bar" style="height: 30%;"></div>
                                    <div class="sp-bar" style="height: 90%;"></div>
                                    <div class="sp-bar" style="height: 60%;"></div>
                                    <div class="sp-bar" style="height: 100%;"></div>
                                    <div class="sp-bar" style="height: 45%;"></div>
                                    <div class="sp-bar" style="height: 80%;"></div>
                                    <div class="sp-bar" style="height: 35%;"></div>
                                    <div class="sp-bar" style="height: 65%;"></div>
                                    <div class="sp-bar" style="height: 95%;"></div>
                                    <div class="sp-bar" style="height: 50%;"></div>
                                    <div class="sp-bar" style="height: 85%;"></div>
                                    <div class="sp-bar" style="height: 40%;"></div>
                                    <div class="sp-bar" style="height: 70%;"></div>
                                    <div class="sp-bar" style="height: 30%;"></div>
                                    <div class="sp-bar" style="height: 88%;"></div>
                                    <div class="sp-bar" style="height: 55%;"></div>
                                </div>
                            </div>
                        </div>

                        <!-- Progress Bar Slider -->
                        <div class="sp-progress-row">
                            <span id="waTimer">00:18</span>
                            <div class="sp-progress-track">
                                <div class="sp-progress-fill" id="spProgressFill" style="width: 25%;">
                                    <div class="sp-progress-thumb"></div>
                                </div>
                            </div>
                            <span id="waTotalTime">04:43</span>
                        </div>

                        <!-- Playback Transport Row -->
                        <div class="sp-transport-row">
                            <button id="shufBtn" class="sp-btn-sub" onclick="triggerAction('spotify_shuffle')">🔀</button>
                            <button class="sp-btn-sub" onclick="triggerAction('spotify_prev')">|◄◄</button>
                            <button id="spPlayBtnMain" class="sp-btn-main" onclick="triggerAction('spotify_playpause')">
                                <span id="spPlaySymbolMain">❚❚</span>
                            </button>
                            <button class="sp-btn-sub" onclick="triggerAction('spotify_next')">►►|</button>
                            <button id="repBtn" class="sp-btn-sub" onclick="triggerAction('spotify_repeat')">🔁</button>
                            <button class="sp-btn-sub" onclick="triggerAction('spotify_like')">♥</button>
                        </div>

                        <!-- Open Spotify Portal Button -->
                        <button class="sp-open-btn" onclick="triggerAction('app_spotify')">
                            <span>OPEN SPOTIFY</span>
                            <span style="font-size: 0.85rem;">↗</span>
                        </button>

                    </div>
                </div>

                <!-- PANEL 5: WORKSPACE APPLICATIONS -->
                <div class="panel-box" style="flex: 1.1;">
                    <div class="panel-header">
                        <span>🎛️ WORKSPACE APPLICATIONS</span>
                        <span>^</span>
                    </div>
                    <div class="panel-body">
                        <div class="app-launcher-grid">
                            <div class="app-launch-tile" onclick="triggerAction('app_chrome')">
                                <span class="app-tile-icon">🌐</span>
                                <span class="app-tile-name">Chrome</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_messages')">
                                <span class="app-tile-icon">💬</span>
                                <span class="app-tile-name">Messages</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_chatgpt')">
                                <span class="app-tile-icon">🤖</span>
                                <span class="app-tile-name">ChatGPT</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_teams')">
                                <span class="app-tile-icon">👥</span>
                                <span class="app-tile-name">Teams</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_slack')">
                                <span class="app-tile-icon">📢</span>
                                <span class="app-tile-name">Slack</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_outlook')">
                                <span class="app-tile-icon">✉️</span>
                                <span class="app-tile-name">Outlook</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('app_firefox')">
                                <span class="app-tile-icon">🦊</span>
                                <span class="app-tile-name">Firefox</span>
                            </div>
                            <div class="app-launch-tile" onclick="triggerAction('window_next_screen')">
                                <span class="app-tile-icon">🖥️</span>
                                <span class="app-tile-name">Next Display</span>
                            </div>
                        </div>
                    </div>
                </div>

            </div>

        </div>

        <!-- 6. GLOBAL STATUS BAR -->
        <div class="app-statusbar">
            <div class="sb-left">
                <span>STATUS: <span class="sb-status-ok">SYSTEM OPERATIONAL</span></span>
                <span>UPTIME: 3D 14H 22M</span>
            </div>
            <div class="sb-right">
                <span>CPU: 12%</span>
                <span>MEM: 43%</span>
                <span>MAY 12, 2025 &nbsp;10:24:38 AM</span>
            </div>
        </div>

    </div>

    <!-- MODAL 1: GEEKAMP PLAYLIST PRESETS -->
    <div id="playlistModal" class="retro-modal">
        <div class="modal-header">
            <span>*** SPOTIFY PLAYLIST PRESETS ***</span>
            <span class="modal-close" onclick="togglePlaylistModal()">[X]</span>
        </div>
        <div class="modal-body">
            <div class="modal-item" onclick="playUri('spotify:track:1DCdIWCE5UFiObCsTSpKFv', 'spotify:playlist:0NyPLheWZbkk2wgwq7NIC8')">
                <span>01. 🌧️ Rust and Rain</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('spotify:track:1DCdIWCE5UFiObCsTSpKFv', 'spotify:playlist:0NyPLheWZbkk2wgwq7NIC8'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:7zaZlzl0XhthNwH3GQcyZ0', 'spotify:playlist:7Eldq78AevyJ8vSnbGpu9d')">
                <span>02. ⛰️ Peak</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('spotify:track:7zaZlzl0XhthNwH3GQcyZ0', 'spotify:playlist:7Eldq78AevyJ8vSnbGpu9d'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:5vYA1mW9g2Coh1HUFUSmlb', 'spotify:playlist:6PP4LnUwxEYitIC9Z0dOv1')">
                <span>03. 🚗 Windows Down Crusin'</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('spotify:track:5vYA1mW9g2Coh1HUFUSmlb', 'spotify:playlist:6PP4LnUwxEYitIC9Z0dOv1'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:5eewTcv33R0w9DmyJU9R1W', 'spotify:playlist:37i9dQZF1DX2TRYkJECvfC')">
                <span>04. ☕ Deep House Relax</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('spotify:track:5eewTcv33R0w9DmyJU9R1W', 'spotify:playlist:37i9dQZF1DX2TRYkJECvfC'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:3ckd4YA4LcD3j50rfIVwUe', 'spotify:playlist:0BsPYkpv2PWHCNiYzn2eTa')">
                <span>05. ⚡ Anger Management 101</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('spotify:track:3ckd4YA4LcD3j50rfIVwUe', 'spotify:playlist:0BsPYkpv2PWHCNiYzn2eTa'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('', 'spotify:user:spotify:collection')">
                <span>06. ❤️ Your Liked Songs</span>
                <button class="tb-btn" style="padding: 2px 6px; font-size: 0.65rem;" onclick="playUri('', 'spotify:user:spotify:collection'); event.stopPropagation();">[LOAD]</button>
            </div>
        </div>
    </div>

    <script>
        // Register Service Worker for Android PWA Installability
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.register('/sw.js').catch(() => {});
        }

        // Auto Request Fullscreen on First Touch / Click
        function goFullscreen() {
            if (!document.fullscreenElement && !document.webkitFullscreenElement) {
                const el = document.documentElement;
                if (el.requestFullscreen) {
                    el.requestFullscreen().catch(() => {});
                } else if (el.webkitRequestFullscreen) {
                    el.webkitRequestFullscreen().catch(() => {});
                }
            }
        }
        document.addEventListener('touchstart', goFullscreen, { once: true });
        document.addEventListener('click', goFullscreen, { once: true });

        function triggerAction(action) {
            fetch('/api/action/' + action, { method: 'POST' });
            setTimeout(updateStatus, 150);
        }

        function playUri(trackUri, contextUri) {
            fetch('/api/action/play_uri?track=' + encodeURIComponent(trackUri) + '&context=' + encodeURIComponent(contextUri), { method: 'POST' });
            togglePlaylistModal();
            setTimeout(updateStatus, 500);
        }

        function togglePlaylistModal() {
            const pModal = document.getElementById('playlistModal');
            pModal.classList.toggle('active');
        }

        const talkBtn = document.getElementById('talkBtn');
        if (talkBtn) {
            talkBtn.addEventListener('touchstart', (e) => {
                e.preventDefault();
                fetch('/api/action/talk_start', { method: 'POST' });
            });
            talkBtn.addEventListener('touchend', (e) => {
                e.preventDefault();
                fetch('/api/action/talk_stop', { method: 'POST' });
            });
        }

        function formatTime(seconds) {
            const m = Math.floor(seconds / 60);
            const s = Math.floor(seconds % 60);
            return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
        }

        let eqTimer = null;
        function updateLiveSpectrum(isPlaying) {
            const bars = document.querySelectorAll('.winamp-eq-bar');
            if (!isPlaying) {
                if (eqTimer) { clearInterval(eqTimer); eqTimer = null; }
                bars.forEach(bar => {
                    const segs = bar.querySelectorAll('.winamp-eq-seg');
                    segs.forEach(s => s.classList.remove('lit'));
                });
                return;
            }

            if (eqTimer) return;

            eqTimer = setInterval(() => {
                bars.forEach((bar, bIdx) => {
                    const segs = bar.querySelectorAll('.winamp-eq-seg');
                    let litCount = Math.floor(Math.random() * 5);
                    if (bIdx === 0 || bIdx === 1) {
                        litCount = Math.min(4, Math.floor(Math.random() * 3) + 2);
                    }

                    segs.forEach((seg, sIdx) => {
                        const levelFromBottom = 4 - sIdx;
                        if (levelFromBottom <= litCount) {
                            seg.classList.add('lit');
                        } else {
                            seg.classList.remove('lit');
                        }
                    });
                });
            }, 80);
        }

        let lastTrackStr = '';
        function setTrackMarquee(trackStr) {
            const waText = document.getElementById('waTrackText');
            if (trackStr === lastTrackStr) return;

            lastTrackStr = trackStr;
            waText.innerText = trackStr;

            // Start in truncated state to prevent layout expansion
            waText.className = 'winamp-marquee-text truncated';
            waText.style.removeProperty('--scroll-dist');

            const container = waText.parentElement;
            const containerWidth = container.clientWidth;
            
            // Temporary check for scroll width
            waText.classList.remove('truncated');
            waText.style.display = 'inline-block';
            const textWidth = waText.scrollWidth;

            if (textWidth > containerWidth + 10) {
                const overflowPx = (textWidth - containerWidth) + 30;
                waText.style.setProperty('--scroll-dist', '-' + overflowPx + 'px');
                waText.className = 'winamp-marquee-text scrolling';

                waText.onanimationend = () => {
                    waText.style.display = '';
                    waText.className = 'winamp-marquee-text truncated';
                };
            } else {
                waText.style.display = '';
                waText.className = 'winamp-marquee-text truncated';
            }
        }

        function updateStatus() {
            fetch('/api/status')
                .then(r => r.json())
                .then(data => {
                    const micBtn = document.getElementById('micBtn');
                    const micLabel = document.getElementById('micLabel');
                    const micTile = document.getElementById('micTile');
                    const micTileLabel = document.getElementById('micTileLabel');
                    if (data.micMuted) {
                        micBtn.className = 'tb-btn active-muted';
                        micLabel.innerText = 'MIC MUTED';
                        if (micTile) { micTile.className = 'meeting-tile active-muted'; }
                        if (micTileLabel) { micTileLabel.innerText = 'MIC MUTED'; }
                    } else {
                        micBtn.className = 'tb-btn active-live';
                        micLabel.innerText = 'MIC LIVE';
                        if (micTile) { micTile.className = 'meeting-tile active-live'; }
                        if (micTileLabel) { micTileLabel.innerText = 'MIC LIVE'; }
                    }

                    if (data.audio) {
                        const outLabel = data.audio.name ? (data.audio.name + (data.audio.inputName ? ' & ' + data.audio.inputName : '')) : 'Switch Audio & Mic';
                        document.getElementById('outputDevLabel').innerText = data.audio.name || 'Switch Audio & Mic';
                        
                        const sysMuteBtn = document.getElementById('sysMuteBtn');
                        const sysMuteLabel = document.getElementById('sysMuteLabel');
                        if (data.audio.isMuted) {
                            sysMuteBtn.className = 'tile tile-sound muted';
                            sysMuteLabel.innerText = 'SOUND MUTED';
                        } else {
                            sysMuteBtn.className = 'tile tile-sound';
                            sysMuteLabel.innerText = 'Mute Sound (' + data.audio.volume + '%)';
                        }
                    }

                    if (data.spotify) {
                        const sp = data.spotify;
                        const trackStr = sp.isPlaying 
                            ? ('1. ' + sp.track + ' - ' + sp.artist + (sp.album ? ' [' + sp.album + ']' : '')).toUpperCase()
                            : 'GEEKAMP [PAUSED]';

                        setTrackMarquee(trackStr);
                        document.getElementById('waTimer').innerText = formatTime(sp.position || 0);
                        document.getElementById('waStatusText').innerText = sp.isPlaying ? 'PLAYING' : 'PAUSED';
                        document.getElementById('spPlayLabel').innerText = sp.isPlaying ? 'PAUSE' : 'PLAY';
                        document.getElementById('spPlaySymbol').innerText = sp.isPlaying ? '❚❚' : '►';

                        const shufBtn = document.getElementById('shufBtn');
                        if (sp.shuffle) { shufBtn.className = 'tile winamp-btn active-led'; }
                        else { shufBtn.className = 'tile winamp-btn'; }

                        const repBtn = document.getElementById('repBtn');
                        if (sp.repeatState) { repBtn.className = 'tile winamp-btn active-led'; }
                        else { repBtn.className = 'tile winamp-btn'; }

                        updateLiveSpectrum(sp.isPlaying);
                    }
                })
                .catch(err => console.log('Poll error:', err));
        }

        setInterval(updateStatus, 1000);
        updateStatus();
    </script>
</body>
</html>]==]
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
        local data = {
            micMuted = mute.isMuted(),
            audio = audio.getStatus(),
            spotify = spotify.getStatus(),
            attention = attention.getStatus(),
            camera = camera.getStatus(),
            aiUsage = browserUsage.getStatus(),
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
