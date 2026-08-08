# Hammerspoon Feature Roadmap & Ideas

This document outlines the selected Hammerspoon automation features to build for macOS desktop enhancement, ordered by implementation priority.

---

## 🎯 High-Priority Selected Tablet Stream Deck Features

1. **🦙 Classic Winamp-Themed Spotify Media Suite**
   * **Winamp Retro Visuals:** Dark brushed metal frame, fluorescent green LED digital timer (`02:45`), 8-band retro VU spectrum equalizer, and a scrolling LCD marquee ticker (`TRACK - ARTIST`).
   * **Winamp Touch Controls:** `PREV`, `PLAY/PAUSE`, `NEXT`, `SHUFFLE` (with green active LED), `REPEAT` (with green active LED), `LIKE TRACK`.

2. **📱 Smart Workspace App Launcher (7 Apps)**
   * **Target Apps:** Chrome, Messages, ChatGPT (Edge PWA), Teams (Edge PWA), Slack, Outlook, Firefox.
   * **Smart Launch Behavior:**
     * **If closed:** Launches the app and automatically **maximizes** its window once loaded.
     * **If already open:** Switches focus directly to the app **without changing/maximizing** its window size.

3. **🔊 Master macOS System Audio Controls (4 Buttons)**
   * **Switch Output:** Taps to cycle default output between AirPods, Speakers, and Headphones with live output device name display.
   * **System Mute:** Toggles master macOS speaker sound output mute with live state indicator.
   * **Vol + / Vol -:** Adjusts master system volume (+5% / -5%) with live volume level indicator.

4. **🔴 Global Mic Mute Toggle & Push-To-Talk**
   * Hardware microphone mute/unmute with live visual state sync on the tablet.
   * Hold-to-talk mode for quick voice replies in meetings.

5. **📸 Interactive Rectangle Screenshot Tools (2 Buttons)**
   * **Rectangle ➔ Clipboard:** One-tap triggers native macOS interactive selection cursor (draw rectangle) and copies screenshot directly to Clipboard.
   * **Rectangle ➔ File:** One-tap triggers interactive rectangle selection cursor and saves timestamped PNG directly to Desktop.
