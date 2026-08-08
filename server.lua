-- server.lua: Embedded HTTP & HTTPS server for Android Tablet Stream Deck (Explicit Load Button Touch Handlers)
local server = {}

local spotify = require("spotify")
local mute = require("mute")
local meeting = require("meeting")
local winManager = require("window")
local browser = require("browser")
local audio = require("audio")
local screenshot = require("screenshot")
local apps = require("apps")

local httpServer = nil
local httpsServer = nil
local port = 8080
local httpsPort = 8443

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
        name = "GEEKAMP Stream Deck",
        short_name = "StreamDeck",
        description = "Standalone Android Tablet Stream Deck & GEEKAMP Media Controller",
        start_url = "/",
        scope = "/",
        display = "fullscreen",
        orientation = "landscape",
        background_color = "#060911",
        theme_color = "#060911",
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
    return [[<!DOCTYPE html>
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
            border-color: #00ff41;
        }

        .winamp-btn.active-led .wa-label {
            color: #00ff41;
            text-shadow: 0 0 5px #00ff41;
        }

        /* RETRO EXPANDED SCROLLING PLAYLIST MODAL */
        .retro-modal {
            position: absolute;
            top: 20px;
            right: 20px;
            width: 580px;
            background: #1e222b;
            border: 2px solid #3b4150;
            border-radius: 14px;
            box-shadow: 0 15px 50px rgba(0,0,0,0.9), 0 0 25px rgba(0,255,65,0.25);
            z-index: 1000;
            display: none;
            flex-direction: column;
            padding: 12px;
            gap: 10px;
        }

        .retro-modal.active {
            display: flex;
        }

        .modal-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: linear-gradient(90deg, #111622 0%, #2a3245 100%);
            padding: 6px 10px;
            border-radius: 6px;
            font-family: 'VT323', monospace;
            font-size: 1.2rem;
            color: #00ff41;
            text-shadow: 0 0 5px #00ff41;
        }

        .modal-close {
            cursor: pointer;
            color: #ff3b5c;
            font-weight: 800;
            font-family: sans-serif;
            font-size: 1.1rem;
        }

        .modal-body {
            background: #000;
            border: 2px inset #222;
            border-radius: 6px;
            padding: 10px;
            display: flex;
            flex-direction: column;
            gap: 6px;
            max-height: 440px;
            overflow-y: auto;
            font-family: 'VT323', monospace;
            scrollbar-width: thin;
            scrollbar-color: #00ff41 #000000;
        }

        .modal-body::-webkit-scrollbar {
            width: 8px;
        }
        .modal-body::-webkit-scrollbar-track {
            background: #000;
            border: 1px inset #222;
        }
        .modal-body::-webkit-scrollbar-thumb {
            background: #00ff41;
            border-radius: 4px;
            box-shadow: 0 0 6px #00ff41;
        }

        .modal-now-playing {
            color: #ffff00;
            font-size: 1.25rem;
            border-bottom: 1px dashed #004400;
            padding-bottom: 6px;
            margin-bottom: 4px;
        }

        .modal-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            color: #00ff41;
            font-size: 1.15rem;
            padding: 6px 8px;
            border-radius: 4px;
            cursor: pointer;
            background: #041004;
            border: 1px solid #002200;
            transition: all 0.15s ease;
        }

        .modal-item:hover {
            background: #003300;
            border-color: #00ff41;
            box-shadow: 0 0 8px rgba(0,255,65,0.4);
            transform: translateX(4px);
        }

        .load-btn {
            background: #004400;
            color: #00ff41;
            border: 1px solid #00ff41;
            padding: 4px 12px;
            border-radius: 4px;
            font-family: 'VT323', monospace;
            font-size: 1.1rem;
            cursor: pointer;
        }
        .load-btn:active {
            background: #00ff41;
            color: #000;
        }
    </style>
</head>
<body>

    <div class="main-deck">
        <!-- Left Column -->
        <div class="col">
            <!-- Card 1: Meeting Controls (Mic, Push to Talk, Camera Toggle) -->
            <div class="card-box" style="flex: 0.85;">
                <div class="section-title">🎙️ Meeting Controls</div>
                <div class="grid grid-3col">
                    <div id="micBtn" class="tile tile-mic muted" onclick="triggerAction('mute_toggle')">
                        <span class="tile-icon">🎙️</span>
                        <span id="micLabel" class="tile-label">MIC MUTED</span>
                    </div>
                    <div class="tile" id="talkBtn">
                        <span class="tile-icon">🗣️</span>
                        <span class="tile-label">Push to Talk</span>
                    </div>
                    <div class="tile" onclick="triggerAction('cam_toggle')">
                        <span class="tile-icon">📹</span>
                        <span class="tile-label">Camera Toggle</span>
                    </div>
                </div>
            </div>

            <!-- Card 2: Synchronized Audio & Mic Device Controls -->
            <div class="card-box" style="flex: 1.1;">
                <div class="section-title">🎧 macOS Audio & Mic Devices</div>
                <div class="grid grid-2col">
                    <div class="tile" onclick="triggerAction('audio_cycle')">
                        <span class="tile-icon">🎧</span>
                        <span id="outputDevLabel" class="tile-label">Switch Audio & Mic</span>
                    </div>
                    <div id="sysMuteBtn" class="tile tile-sound" onclick="triggerAction('audio_mute')">
                        <span class="tile-icon">🔇</span>
                        <span id="sysMuteLabel" class="tile-label">System Mute</span>
                    </div>
                    <div class="tile" onclick="triggerAction('audio_voldown')">
                        <span class="tile-icon">🔉</span>
                        <span id="sysVolDownLabel" class="tile-label">Vol -</span>
                    </div>
                    <div class="tile" onclick="triggerAction('audio_volup')">
                        <span class="tile-icon">🔊</span>
                        <span id="sysVolUpLabel" class="tile-label">Vol +</span>
                    </div>
                </div>
            </div>

            <div class="card-box" style="flex: 0.9;">
                <div class="section-title">📸 Interactive Screenshots</div>
                <div class="grid grid-2col">
                    <div class="tile" onclick="triggerAction('snap_copy')">
                        <span class="tile-icon">📋</span>
                        <span class="tile-label">Rectangle ➔ Clipboard</span>
                    </div>
                    <div class="tile" onclick="triggerAction('snap_file')">
                        <span class="tile-icon">💾</span>
                        <span class="tile-label">Rectangle ➔ File</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- Right Column: GEEKAMP v6.78 RETRO HERO DISPLAY -->
        <div class="col">
            <div class="winamp-skin">
                <!-- Titlebar: Click for Playlist Presets -->
                <div class="winamp-titlebar" onclick="togglePlaylistModal()">
                    <span>*** GEEKAMP v6.78 ***</span>
                    <span>[PLAYLISTS]</span>
                </div>

                <div class="winamp-screen">
                    <div class="winamp-screen-top">
                        <div id="waTimer" class="winamp-timer">00:00</div>
                        <div class="winamp-info-box">
                            <div>320 kbps</div>
                            <div>44.1 kHz</div>
                            <div id="waStatusText">STEREO</div>
                        </div>
                    </div>

                    <!-- Fixed-Width Single-Pass Marquee -->
                    <div class="winamp-marquee-container">
                        <span id="waTrackText" class="winamp-marquee-text truncated">1. GEEKAMP PLAYER - LAUNCH SPOTIFY</span>
                    </div>

                    <!-- 8-Band Live Spectrum Analyzer -->
                    <div id="waEq" class="winamp-eq">
                        <div class="winamp-eq-bar"><div class="winamp-eq-seg seg-red"></div><div class="winamp-eq-seg seg-yellow"></div><div class="winamp-eq-seg seg-green"></div><div class="winamp-eq-seg seg-green"></div></div>
                        <div class="winamp-eq-bar"><div class="winamp-eq-seg seg-red"></div><div class="winamp-eq-seg seg-yellow"></div><div class="winamp-eq-seg seg-green"></div><div class="winamp-eq-seg seg-green"></div></div>
                        <div class="winamp-eq-bar"><div class="winamp-eq-seg seg-red"></div><div class="winamp-eq-seg seg-yellow"></div><div class="winamp-eq-seg seg-green"></div><div class="winamp-eq-seg seg-green"></div></div>
                        <div class="winamp-eq-bar"><div class="winamp-eq-seg seg-red"></div><div class="winamp-eq-seg seg-yellow"></div><div class="winamp-eq-seg seg-green"></div><div class="winamp-eq-seg seg-green"></div></div>
                        <div class="winamp-eq-bar"><div class="winamp-eq-seg seg-red"></div><div class="winamp-eq-seg seg-yellow"></div><div class="winamp-eq-seg seg-green"></div><div class="winamp-eq-seg seg-green"></div></div>
                        <div class="winamp-eq-bar"><div class="winamp-eq-seg seg-red"></div><div class="winamp-eq-seg seg-yellow"></div><div class="winamp-eq-seg seg-green"></div><div class="winamp-eq-seg seg-green"></div></div>
                        <div class="winamp-eq-bar"><div class="winamp-eq-seg seg-red"></div><div class="winamp-eq-seg seg-yellow"></div><div class="winamp-eq-seg seg-green"></div><div class="winamp-eq-seg seg-green"></div></div>
                        <div class="winamp-eq-bar"><div class="winamp-eq-seg seg-red"></div><div class="winamp-eq-seg seg-yellow"></div><div class="winamp-eq-seg seg-green"></div><div class="winamp-eq-seg seg-green"></div></div>
                    </div>
                </div>

                <div class="grid grid-3col">
                    <div class="tile winamp-btn" onclick="triggerAction('spotify_prev')">
                        <span class="wa-symbol">|◄◄</span>
                        <span class="wa-label">PREV</span>
                    </div>
                    <div id="spPlayBtn" class="tile winamp-btn" onclick="triggerAction('spotify_playpause')">
                        <span id="spPlaySymbol" class="wa-symbol">►</span>
                        <span id="spPlayLabel" class="wa-label">PLAY</span>
                    </div>
                    <div class="tile winamp-btn" onclick="triggerAction('spotify_next')">
                        <span class="wa-symbol">►►|</span>
                        <span class="wa-label">NEXT</span>
                    </div>
                    <div id="shufBtn" class="tile winamp-btn" onclick="triggerAction('spotify_shuffle')">
                        <div class="wa-led"></div>
                        <span class="wa-label">SHUFFLE</span>
                    </div>
                    <div id="repBtn" class="tile winamp-btn" onclick="triggerAction('spotify_repeat')">
                        <div class="wa-led"></div>
                        <span class="wa-label">REPEAT</span>
                    </div>
                    <div class="tile winamp-btn" onclick="triggerAction('spotify_like')">
                        <span class="wa-symbol">♥</span>
                        <span class="wa-label">LIKE</span>
                    </div>
                </div>
            </div>

            <!-- Workspace Applications Grid -->
            <div class="card-box" style="flex: 1.2;">
                <div class="section-title">🖥️ Workspace Applications</div>
                <div class="grid grid-4col">
                    <div class="tile" onclick="triggerAction('app_chrome')">
                        <span class="tile-icon">🌐</span>
                        <span class="tile-label">Chrome</span>
                    </div>
                    <div class="tile" onclick="triggerAction('app_messages')">
                        <span class="tile-icon">💬</span>
                        <span class="tile-label">Messages</span>
                    </div>
                    <div class="tile" onclick="triggerAction('app_chatgpt')">
                        <span class="tile-icon">🤖</span>
                        <span class="tile-label">ChatGPT</span>
                    </div>
                    <div class="tile" onclick="triggerAction('app_teams')">
                        <span class="tile-icon">👥</span>
                        <span class="tile-label">Teams</span>
                    </div>
                    <div class="tile" onclick="triggerAction('app_slack')">
                        <span class="tile-icon">📢</span>
                        <span class="tile-label">Slack</span>
                    </div>
                    <div class="tile" onclick="triggerAction('app_outlook')">
                        <span class="tile-icon">✉️</span>
                        <span class="tile-label">Outlook</span>
                    </div>
                    <div class="tile" onclick="triggerAction('app_firefox')">
                        <span class="tile-icon">🦊</span>
                        <span class="tile-label">Firefox</span>
                    </div>
                    <div class="tile" onclick="triggerAction('window_next_screen')">
                        <span class="tile-icon">🖥️</span>
                        <span class="tile-label">Next Display</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- MODAL 1: GEEKAMP PLAYLIST PRESETS (Clint's Custom Playlists) -->
    <div id="playlistModal" class="retro-modal">
        <div class="modal-header">
            <span>*** GEEKAMP PLAYLIST PRESETS ***</span>
            <span class="modal-close" onclick="togglePlaylistModal()">[X]</span>
        </div>
        <div class="modal-body">
            <div class="modal-now-playing">CLINT'S SPOTIFY PLAYLISTS:</div>
            <div class="modal-item" onclick="playUri('spotify:track:1DCdIWCE5UFiObCsTSpKFv', 'spotify:playlist:0NyPLheWZbkk2wgwq7NIC8')">
                <span>01. 🌧️ Rust and Rain</span>
                <button class="load-btn" onclick="playUri('spotify:track:1DCdIWCE5UFiObCsTSpKFv', 'spotify:playlist:0NyPLheWZbkk2wgwq7NIC8'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:7zaZlzl0XhthNwH3GQcyZ0', 'spotify:playlist:7Eldq78AevyJ8vSnbGpu9d')">
                <span>02. ⛰️ Peak</span>
                <button class="load-btn" onclick="playUri('spotify:track:7zaZlzl0XhthNwH3GQcyZ0', 'spotify:playlist:7Eldq78AevyJ8vSnbGpu9d'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:5vYA1mW9g2Coh1HUFUSmlb', 'spotify:playlist:6PP4LnUwxEYitIC9Z0dOv1')">
                <span>03. 🚗 Windows Down Crusin'</span>
                <button class="load-btn" onclick="playUri('spotify:track:5vYA1mW9g2Coh1HUFUSmlb', 'spotify:playlist:6PP4LnUwxEYitIC9Z0dOv1'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:5eewTcv33R0w9DmyJU9R1W', 'spotify:playlist:37i9dQZF1DX2TRYkJECvfC')">
                <span>04. ☕ Deep House Relax</span>
                <button class="load-btn" onclick="playUri('spotify:track:5eewTcv33R0w9DmyJU9R1W', 'spotify:playlist:37i9dQZF1DX2TRYkJECvfC'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('spotify:track:3ckd4YA4LcD3j50rfIVwUe', 'spotify:playlist:0BsPYkpv2PWHCNiYzn2eTa')">
                <span>05. ⚡ Anger Management 101</span>
                <button class="load-btn" onclick="playUri('spotify:track:3ckd4YA4LcD3j50rfIVwUe', 'spotify:playlist:0BsPYkpv2PWHCNiYzn2eTa'); event.stopPropagation();">[LOAD]</button>
            </div>
            <div class="modal-item" onclick="playUri('', 'spotify:user:spotify:collection')">
                <span>06. ❤️ Your Liked Songs</span>
                <button class="load-btn" onclick="playUri('', 'spotify:user:spotify:collection'); event.stopPropagation();">[LOAD]</button>
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
        talkBtn.addEventListener('touchstart', (e) => {
            e.preventDefault();
            fetch('/api/action/talk_start', { method: 'POST' });
        });
        talkBtn.addEventListener('touchend', (e) => {
            e.preventDefault();
            fetch('/api/action/talk_stop', { method: 'POST' });
        });

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
                    if (data.micMuted) {
                        micBtn.className = 'tile tile-mic muted';
                        micLabel.innerText = 'MIC MUTED';
                    } else {
                        micBtn.className = 'tile tile-mic live';
                        micLabel.innerText = 'MIC LIVE';
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
</html>]]
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
            spotify = spotify.getStatus()
        }
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
            hs.timer.doAfter(0, mute.toggleMute)
        elseif action == "talk_start" then
            hs.timer.doAfter(0, mute.startTalk)
        elseif action == "talk_stop" then
            hs.timer.doAfter(0, mute.stopTalk)
        elseif action == "cam_toggle" then
            hs.timer.doAfter(0, meeting.toggleCamera)
        elseif action == "audio_cycle" then
            hs.timer.doAfter(0, audio.cycleOutput)
        elseif action == "audio_mute" then
            hs.timer.doAfter(0, audio.toggleMute)
        elseif action == "audio_volup" then
            hs.timer.doAfter(0, audio.volumeUp)
        elseif action == "audio_voldown" then
            hs.timer.doAfter(0, audio.volumeDown)
        elseif action == "snap_copy" then
            hs.timer.doAfter(0, screenshot.copyToClipboard)
        elseif action == "snap_file" then
            hs.timer.doAfter(0, screenshot.saveToFile)
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
        end

        return jsonResponse({status = "ok"})
    end

    return getHTML(), 200, corsHeaders("text/html; charset=utf-8")
end

function server.start()
    if httpServer then httpServer:stop() end
    if httpsServer then httpsServer:stop() end

    -- Start HTTP Server on 8080
    httpServer = hs.httpserver.new(false, true)
    httpServer:setName("Hammerspoon Stream Deck")
    httpServer:setPort(port)
    httpServer:setCallback(handleRequest)
    httpServer:start()
    print("Stream Deck HTTP Server running on port " .. port)

    -- Start HTTPS Server on 8443 with self-signed certificate
    local ok, err = pcall(function()
        httpsServer = hs.httpserver.new(true, true)
        httpsServer:setName("Hammerspoon Stream Deck HTTPS")
        httpsServer:setPort(httpsPort)
        httpsServer:setCallback(handleRequest)
        httpsServer:start()
        print("Stream Deck HTTPS Server running on port " .. httpsPort)
    end)
    if not ok then
        print("HTTPS Server note:", err)
    end
end

return server
