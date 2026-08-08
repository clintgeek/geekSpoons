-- server.lua: Embedded HTTP server for Android Tablet Stream Deck (Strict Fixed-Width GEEKAMP Marquee)
local server = {}

local spotify = require("spotify")
local mute = require("mute")
local winManager = require("window")
local browser = require("browser")
local audio = require("audio")
local screenshot = require("screenshot")
local apps = require("apps")

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

local function getHTML()
    return [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
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
            height: 100vh;
            width: 100vw;
            overflow: hidden;
            padding: 14px 18px;
            display: flex;
            flex-direction: column;
            position: relative;
        }

        .main-deck {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 14px;
            flex: 1;
            min-height: 0;
            min-width: 0;
        }

        .col {
            display: flex;
            flex-direction: column;
            gap: 12px;
            height: 100%;
            min-width: 0;
            overflow: hidden;
        }

        .card-box {
            background: var(--bg-card);
            border: 1px solid var(--border-card);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border-radius: 18px;
            padding: 14px;
            display: flex;
            flex-direction: column;
            gap: 10px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35);
            flex: 1;
            min-width: 0;
        }

        .section-title {
            font-family: 'Outfit', sans-serif;
            font-size: 0.8rem;
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
            gap: 10px;
            flex: 1;
        }

        .grid-2col { grid-template-columns: repeat(2, 1fr); }
        .grid-3col { grid-template-columns: repeat(3, 1fr); }
        .grid-4col { grid-template-columns: repeat(4, 1fr); }

        .tile {
            background: rgba(255, 255, 255, 0.04);
            border: 1px solid var(--border-card);
            border-radius: 14px;
            padding: 10px 8px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 6px;
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
            font-size: 1.8rem;
            filter: drop-shadow(0 3px 6px rgba(0,0,0,0.35));
        }

        .tile-label {
            font-size: 0.78rem;
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
            padding: 12px;
            display: flex;
            flex-direction: column;
            gap: 10px;
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
            padding: 10px;
            display: flex;
            flex-direction: column;
            gap: 8px;
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
            font-size: 2.2rem;
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
            padding: 6px 10px;
            height: 34px;
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
            font-size: 1.3rem;
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
            height: 28px;
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
            gap: 4px;
            padding: 8px 4px;
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
            font-size: 1.4rem;
            font-weight: 700;
            line-height: 1;
            text-shadow: 1px 1px 0 #000;
            color: #00ff41;
        }

        .wa-label {
            font-family: 'Share Tech Mono', monospace;
            font-size: 0.75rem;
            font-weight: 700;
            color: #b0c0d8;
            letter-spacing: 0.5px;
        }

        .wa-led {
            width: 7px;
            height: 7px;
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

        .retro-modal {
            position: absolute;
            top: 25px;
            right: 20px;
            width: 560px;
            background: #1e222b;
            border: 2px solid #3b4150;
            border-radius: 12px;
            box-shadow: 0 15px 40px rgba(0,0,0,0.8), 0 0 20px rgba(0,255,65,0.2);
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
            gap: 8px;
            max-height: 360px;
            overflow-y: auto;
            font-family: 'VT323', monospace;
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
    </style>
</head>
<body>

    <div class="main-deck">
        <!-- Left Column -->
        <div class="col">
            <div class="card-box" style="flex: 0.8;">
                <div class="section-title">🎙️ Microphone Controls</div>
                <div class="grid grid-2col">
                    <div id="micBtn" class="tile tile-mic muted" onclick="triggerAction('mute_toggle')">
                        <span class="tile-icon">🎙️</span>
                        <span id="micLabel" class="tile-label">MIC MUTED</span>
                    </div>
                    <div class="tile" id="talkBtn">
                        <span class="tile-icon">🗣️</span>
                        <span class="tile-label">Push to Talk</span>
                    </div>
                </div>
            </div>

            <div class="card-box" style="flex: 1.1;">
                <div class="section-title">🔊 macOS Master Audio</div>
                <div class="grid grid-2col">
                    <div class="tile" onclick="triggerAction('audio_cycle')">
                        <span class="tile-icon">🎧</span>
                        <span id="outputDevLabel" class="tile-label">Switch Output</span>
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
                    <span>[PLAYLIST]</span>
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
                    <div class="tile" onclick="triggerAction('window_split')">
                        <span class="tile-icon">⚖️</span>
                        <span class="tile-label">50/50 Split</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- MODAL 1: GEEKAMP PLAYLIST PRESETS (Triggered by Titlebar Click) -->
    <div id="playlistModal" class="retro-modal">
        <div class="modal-header">
            <span>*** GEEKAMP PLAYLIST PRESETS ***</span>
            <span class="modal-close" onclick="togglePlaylistModal()">[X]</span>
        </div>
        <div class="modal-body">
            <div class="modal-now-playing">CHOOSE A SPOTIFY PLAYLIST:</div>
            <div class="modal-item" onclick="playUri('spotify:playlist:37i9dQZF1DX8Ueb1gM3p1r')">
                <span>01. 🎧 Deep Work / Lofi Beats</span>
                <span>[LOAD]</span>
            </div>
            <div class="modal-item" onclick="playUri('spotify:playlist:37i9dQZF1DX10zPhmP7SuP')">
                <span>02. ⚡ High Energy / Electronic & Rock</span>
                <span>[LOAD]</span>
            </div>
            <div class="modal-item" onclick="playUri('spotify:playlist:37i9dQZF1DX4WYpdE2TsF6')">
                <span>03. ☕ Chill Out / Jazz Beats</span>
                <span>[LOAD]</span>
            </div>
            <div class="modal-item" onclick="playUri('spotify:user:spotify:collection')">
                <span>04. ❤️ Your Liked Songs</span>
                <span>[LOAD]</span>
            </div>
        </div>
    </div>

    <script>
        function triggerAction(action) {
            fetch('/api/action/' + action, { method: 'POST' });
            setTimeout(updateStatus, 150);
        }

        function playUri(uri) {
            fetch('/api/action/play_uri?uri=' + encodeURIComponent(uri), { method: 'POST' });
            togglePlaylistModal();
            setTimeout(updateStatus, 300);
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
                        document.getElementById('outputDevLabel').innerText = data.audio.name || 'Switch Output';
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

function server.start()
    if httpServer then httpServer:stop() end

    httpServer = hs.httpserver.new(false, true)
    httpServer:setName("Hammerspoon Stream Deck")
    httpServer:setPort(port)
    httpServer:setCallback(function(method, path, headers, body)
        if method == "OPTIONS" then
            return "", 200, corsHeaders()
        end

        if path == "/api/status" then
            local data = {
                micMuted = mute.isMuted(),
                audio = audio.getStatus(),
                spotify = spotify.getStatus()
            }
            return jsonResponse(data)
        elseif path:sub(1, 12) == "/api/action/" then
            local action = path:sub(13)

            if action == "mute_toggle" then
                mute.toggleMute()
            elseif action == "talk_start" then
                mute.startTalk()
            elseif action == "talk_stop" then
                mute.stopTalk()
            elseif action == "audio_cycle" then
                audio.cycleOutput()
            elseif action == "audio_mute" then
                audio.toggleMute()
            elseif action == "audio_volup" then
                audio.volumeUp()
            elseif action == "audio_voldown" then
                audio.volumeDown()
            elseif action == "snap_copy" then
                screenshot.copyToClipboard()
            elseif action == "snap_file" then
                screenshot.saveToFile()
            elseif action == "app_chrome" then
                apps.smartLaunch("chrome")
            elseif action == "app_messages" then
                apps.smartLaunch("messages")
            elseif action == "app_chatgpt" then
                apps.smartLaunch("chatgpt")
            elseif action == "app_teams" then
                apps.smartLaunch("teams")
            elseif action == "app_slack" then
                apps.smartLaunch("slack")
            elseif action == "app_outlook" then
                apps.smartLaunch("outlook")
            elseif action == "app_firefox" then
                apps.smartLaunch("firefox")
            elseif action == "spotify_playpause" then
                spotify.playPause()
            elseif action == "spotify_next" then
                spotify.nextTrack()
            elseif action == "spotify_prev" then
                spotify.previousTrack()
            elseif action == "spotify_shuffle" then
                spotify.toggleShuffle()
            elseif action == "spotify_repeat" then
                spotify.toggleRepeat()
            elseif action == "spotify_like" then
                spotify.likeCurrentTrack()
            elseif action:sub(1, 8) == "play_uri" then
                local uri = path:match("uri=([^&]+)")
                if uri then
                    uri = hs.http.urlPartDecode(uri)
                    spotify.playURI(uri)
                end
            elseif action == "window_split" then
                winManager.split5050()
            end

            return jsonResponse({status = "ok"})
        end

        return getHTML(), 200, corsHeaders("text/html; charset=utf-8")
    end)

    httpServer:start()
    print("Stream Deck HTTP Server running on port " .. port)
end

return server
