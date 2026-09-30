// --- UI state helpers ---
function applyMicState(muted) {
    const micBtn = document.getElementById('micBtn');
    const micLabel = document.getElementById('micLabel');
    if (micBtn && micLabel) {
        micBtn.classList.remove('live', 'muted');
        micBtn.classList.add(muted ? 'muted' : 'live');
        micLabel.textContent = muted ? 'MIC MUTED' : 'MIC LIVE';
    }
}

function applyAudioMuteState(muted) {
    const audioMuteBtn = document.getElementById('audioMuteBtn');
    const audioMuteLabel = document.getElementById('audioMuteLabel');
    if (!audioMuteBtn || !audioMuteLabel) return;
    if (muted) {
        audioMuteBtn.classList.add('muted');
        audioMuteLabel.textContent = 'SOUND MUTED';
    } else {
        audioMuteBtn.classList.remove('muted');
        const vol = (window._lastAudioVol || 0);
        audioMuteLabel.textContent = 'MUTE SOUND (' + vol + '%)';
    }
}

// --- Actions ---
// Repaint the control immediately on tap, before the request goes out.
// The round trip over WiFi is only tens of ms, but a button that does
// nothing until the response lands reads as lag. The authoritative
// value from the response (and the refreshes below) reconciles it, so
// a guess that turns out wrong is corrected within a poll or two.
function applyOptimisticState(action) {
    const micBtn = document.getElementById('micBtn');
    if (action === 'mute_toggle' && micBtn) {
        applyMicState(!micBtn.classList.contains('muted'));
    } else if (action === 'audio_mute') {
        const b = document.getElementById('audioMuteBtn');
        if (b) applyAudioMuteState(!b.classList.contains('muted'));
    } else if (action === 'cam_toggle') {
        const camBtn = document.getElementById('camBtn');
        if (camBtn) updateCamera({ inUse: !camBtn.classList.contains('live') });
    }
}

function triggerAction(action) {
    applyOptimisticState(action);
    fetch('/api/action/' + action, { method: 'POST', body: '{}' })
        .then(r => r.json())
        .then(data => {
            if (data && data.micMuted !== undefined) applyMicState(data.micMuted);
            if (data && data.audioMuted !== undefined) applyAudioMuteState(data.audioMuted);
            if (data && data.camera !== undefined) updateCamera(data.camera);
        })
        .catch(e => console.log('Action failed:', e));
    setTimeout(() => updateStatus(false), 300);
    // macOS is slow to report a camera as in use, and the server
    // re-checks across a ~2s settle window, so keep refreshing to pick
    // up the real state as soon as it appears.
    if (action === 'cam_toggle') {
        [800, 1400, 2200].forEach(d => setTimeout(() => updateStatus(false), d));
    }
}

// --- Talk button touch handlers ---
const talkBtn = document.getElementById('talkBtn');
if (talkBtn) {
    const startTalk = () => {
        talkBtn.classList.add('pushed');
        applyMicState(false); // push-to-talk goes live immediately
        fetch('/api/action/talk_start', { method: 'POST', body: '{}' })
            .then(r => r.json())
            .then(data => { if (data && data.micMuted !== undefined) applyMicState(data.micMuted); })
            .catch(() => {});
    };
    const stopTalk = () => {
        if (!talkBtn.classList.contains('pushed')) return;
        talkBtn.classList.remove('pushed');
        applyMicState(true); // released -> back to muted
        fetch('/api/action/talk_stop', { method: 'POST', body: '{}' })
            .then(r => r.json())
            .then(data => { if (data && data.micMuted !== undefined) applyMicState(data.micMuted); })
            .catch(() => {});
    };
    talkBtn.addEventListener('mousedown', startTalk);
    talkBtn.addEventListener('mouseup', stopTalk);
    talkBtn.addEventListener('mouseleave', stopTalk);
    talkBtn.addEventListener('touchstart', (e) => { e.preventDefault(); startTalk(); });
    talkBtn.addEventListener('touchend', (e) => { e.preventDefault(); stopTalk(); });
}

// --- Formatting ---
// Calendar titles come from the subscribed ICS feed and weather strings
// from wttr.in. Both reach innerHTML below, so neither can go in raw --
// an event titled `<img src=x onerror=...>` would otherwise run here.
function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, c => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    })[c]);
}

function formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
}

let lastTrack = '';
let lastArtworkUrl = null;

// Spotify reports the cover art for the playing track directly
// (`artwork url of current track`), so there is nothing to look up.
// This used to search the iTunes API by "artist album" against
// entity=album, which returns no results for most records -- the miss
// was silent and the panel kept the previous track's cover.
function updateAlbumArtwork(url) {
    url = url || null;
    if (url === lastArtworkUrl) return;
    // Don't blank artwork if url is momentarily missing unless track is also cleared
    if (!url && lastArtworkUrl && lastTrack && lastTrack !== 'Spotify Not Running' && lastTrack !== 'No Track') {
        return;
    }
    lastArtworkUrl = url;

    const panel = document.querySelector('.spotify-panel');
    if (url) {
        panel.style.setProperty('--album-art', 'url("' + url + '")');
    } else {
        panel.style.removeProperty('--album-art');
    }
}

function updateMarquee(track) {
    const el = document.getElementById('trackName');
    if (track === lastTrack) return;
    lastTrack = track;
    el.textContent = track;
    el.classList.remove('marquee-scroll');
    // Force reflow
    void el.offsetWidth;
    // Only scroll if text overflows
    if (el.scrollWidth > el.parentElement.clientWidth) {
        // Duplicate content for seamless loop
        el.textContent = track + '\u00A0\u00A0\u00A0\u00A0' + track;
        el.classList.add('marquee-scroll');
    }
}

// --- Weather rendering ---
function renderWeather(w) {
    const tile = document.getElementById('weatherTile');
    const temp = document.getElementById('weatherTemp');
    const cond = document.getElementById('weatherCondition');
    const meta = document.getElementById('weatherMeta');

    if (!w || !w.available) {
        temp.textContent = '—';
        cond.textContent = '';
        meta.textContent = '';
        tile.style.backgroundImage = '';
        tile.className = 'info-tile weather-tile';
        return;
    }

    temp.textContent = (w.temp || '') + '°';
    cond.textContent = w.condition || '';

    if (w.backgroundUrl) {
        tile.style.backgroundImage = 'url(' + w.backgroundUrl + ')';
    }

    const parts = [];
    if (w.feelsLike) parts.push('Feels ' + w.feelsLike + '°');
    if (w.humidity) parts.push(w.humidity + '% humid');
    if (w.rainChance !== undefined && w.rainChance !== '') parts.push(w.rainChance + '% rain');
    meta.textContent = parts.join(' · ');

    tile.className = 'info-tile weather-tile';
}

// --- Next Up rendering ---
function renderNextUp(up) {
    const header = document.getElementById('nextUpHeader');
    const title = document.getElementById('nextUpTitle');
    const meta = document.getElementById('nextUpMeta');
    const remaining = document.getElementById('nextUpRemaining');

    if (!up || !up.available) {
        header.textContent = 'NEXT UP';
        title.textContent = up && up.title ? up.title : '—';
        meta.textContent = '';
        remaining.textContent = '';
        return;
    }

    const now = new Date();
    const start = new Date(up.start);
    const end = new Date(up.end);

    const isNow = start <= now && now < end;
    header.textContent = isNow ? 'NOW' : 'NEXT UP';

    title.textContent = up.title;

    const timeFmt = (d) => d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
    if (isNow) {
        meta.textContent = timeFmt(start) + ' – ' + timeFmt(end);
        const minsLeft = Math.max(0, Math.round((end - now) / 60000));
        remaining.textContent = minsLeft + ' min remaining';
        remaining.className = 'info-tile-remaining urgent';
    } else {
        meta.textContent = timeFmt(start) + ' · ' + (up.duration || Math.round((end - start) / 60000)) + ' min';
        const minsUntil = Math.max(0, Math.round((start - now) / 60000));
        if (minsUntil >= 1440) {
            // > 24 hours: grey, days
            const days = Math.round(minsUntil / 1440);
            remaining.textContent = 'in ' + days + ' day' + (days !== 1 ? 's' : '');
            remaining.className = 'info-tile-remaining';
        } else if (minsUntil >= 120) {
            // 2-24 hours: yellow, hours
            const hours = Math.round(minsUntil / 60);
            remaining.textContent = 'in ' + hours + ' hour' + (hours !== 1 ? 's' : '');
            remaining.className = 'info-tile-remaining soon';
        } else if (minsUntil >= 60) {
            // 1-2 hours: yellow, hours + minutes
            const hours = Math.floor(minsUntil / 60);
            const mins = minsUntil % 60;
            remaining.textContent = 'in ' + hours + ' hr ' + mins + ' min';
            remaining.className = 'info-tile-remaining soon';
        } else {
            // < 1 hour: red, minutes
            remaining.textContent = 'in ' + minsUntil + ' min';
            remaining.className = 'info-tile-remaining urgent';
        }
    }
}

// --- Per-component status updaters ---
function updateCamera(cam) {
    const camBtn = document.getElementById('camBtn');
    const camLabel = document.getElementById('camLabel');
    camBtn.classList.remove('live', 'muted', 'blocked');
    if (cam && cam.inUse) {
        camBtn.classList.add('live');
        camLabel.textContent = 'CAM ACTIVE';
    } else {
        camLabel.textContent = 'CAMERA';
    }
}

function updateAudio(audio) {
    if (!audio) return;
    const vol = audio.volume || 0;
    window._lastAudioVol = vol;
    document.getElementById('audioOutputName').textContent = audio.name || 'Unknown Output';
    applyAudioMuteState(audio.isMuted);
}

function updateSpotify(sp) {
    if (!sp) return;
    const track = sp.track || 'No Track';
    const artist = sp.artist || '';
    const album = sp.album || '';

    updateMarquee(track);
    const artistEl = document.getElementById('artistName');
    if (artistEl && artistEl.textContent !== artist) artistEl.textContent = artist;
    const albumEl = document.getElementById('albumName');
    if (albumEl && albumEl.textContent !== album) albumEl.textContent = album;
    updateAlbumArtwork(sp.artworkUrl);

    const conn = document.getElementById('spConnection');
    if (sp.isRunning) {
        conn.innerHTML = '<span class="status-dot"></span> SPOTIFY CONNECTED';
        conn.style.color = 'var(--green)';
    } else {
        conn.innerHTML = '<span class="status-dot idle"></span> SPOTIFY IDLE';
        conn.style.color = 'var(--text-secondary)';
    }

    const pos = sp.position || 0;
    const dur = sp.duration || 1;
    const pct = dur ? (pos / dur * 100) : 0;
    document.getElementById('posTime').textContent = formatTime(pos);
    document.getElementById('durTime').textContent = formatTime(dur);
    document.getElementById('progressFill').style.width = pct + '%';

    document.getElementById('playIcon').style.display = sp.isPlaying ? 'none' : 'block';
    document.getElementById('pauseIcon').style.display = sp.isPlaying ? 'block' : 'none';
    document.getElementById('shufBtn').classList.toggle('active', sp.shuffle);
    document.getElementById('repBtn').classList.toggle('active', sp.repeatState);
}

// --- Status polling ---
// Fast poll (1s): mic, camera, audio, spotify, attention — values that
// change in real time or need immediate UI updates (e.g. loading state
// when an app launches).
// Slow poll (10s): calendar, weather — values that change slowly and
// involve more expensive server-side computation.
let statusFailCount = 0;
let slowData = { nextUp: null, weather: null };
let statusInFlight = false;
let statusPending = false;
let statusPendingSlow = false;
const STATUS_TIMEOUT_MS = 4000;

function updateStatus(includeSlow) {
    // Guard against overlapping polls. If the server is slow, a 1s
    // interval stacks requests faster than they complete and each
    // queued one delays the next, so a brief stall snowballs into
    // the "connection lost" banner.
    // A poll that arrives while one is in flight isn't dropped -- it's
    // remembered and re-run on completion. Dropping it would swallow
    // the confirming refresh that follows a button press, leaving the
    // button showing stale state until the next tick.
    if (statusInFlight) {
        statusPending = true;
        if (includeSlow) statusPendingSlow = true;
        return;
    }
    statusInFlight = true;

    // Abort a hung request rather than waiting out the browser's
    // default timeout, so one stall can't wedge the poll loop.
    const ctl = new AbortController();
    const abortTimer = setTimeout(() => ctl.abort(), STATUS_TIMEOUT_MS);

    fetch('/api/status', { signal: ctl.signal })
        .then(r => {
            if (!r.ok) throw new Error('HTTP ' + r.status);
            return r.json();
        })
        .then(data => {
            statusFailCount = 0;
            document.getElementById('connBanner').style.display = 'none';
            applyMicState(data.micMuted);
            updateCamera(data.camera);
            updateAudio(data.audio);
            updateSpotify(data.spotify);

            // Attention: always apply from fresh response (loading states
            // need real-time updates when apps launch/quit)
            if (data.attention) mergeAttention(data.attention);

            if (includeSlow) {
                if (data.nextUp) { slowData.nextUp = data.nextUp; renderNextUp(data.nextUp); }
                if (data.weather) { slowData.weather = data.weather; renderWeather(data.weather); }
            }
        })
        .catch(err => {
            statusFailCount++;
            if (statusFailCount >= 3) {
                document.getElementById('connBanner').style.display = 'block';
            }
            console.log('Status error:', err);
        })
        .finally(() => {
            clearTimeout(abortTimer);
            statusInFlight = false;
            if (statusPending) {
                const slow = statusPendingSlow;
                statusPending = false;
                statusPendingSlow = false;
                updateStatus(slow);
            }
        });
}

// --- Playlist modal ---
function playUri(trackUri, contextUri) {
    fetch('/api/action/play_uri?track=' + encodeURIComponent(trackUri) + '&context=' + encodeURIComponent(contextUri), { method: 'POST', body: '{}' });
    togglePlaylistModal();
    setTimeout(updateStatus, 500);
}

function togglePlaylistModal() {
    document.getElementById('playlistModal').classList.toggle('active');
}

// --- Schedule modal ---
function toggleScheduleModal() {
    const modal = document.getElementById('scheduleModal');
    if (!modal.classList.contains('active')) {
        // Opening — render the current schedule from cached data
        const nextUp = slowData.nextUp;
        if (nextUp && nextUp.schedule) {
            renderSchedule(nextUp.schedule);
        } else {
            renderSchedule([]);
        }
    }
    modal.classList.toggle('active');
}

function renderSchedule(schedule) {
    const body = document.getElementById('scheduleModalBody');
    if (!schedule || schedule.length === 0) {
        body.innerHTML = '<div class="schedule-empty">No upcoming events</div>';
        return;
    }
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const sameDay = (a, b) => a.toDateString() === b.toDateString();
    const dayLabel = (d) => {
        if (sameDay(d, now)) return 'Today';
        if (sameDay(d, tomorrow)) return 'Tomorrow';
        return d.toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' });
    };
    const timeFmt = (d) => d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
    const dateFmt = (d) => d.toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' });

    let html = '';
    let currentDay = null;
    for (const ev of schedule) {
        const start = new Date(ev.start);
        const end = new Date(ev.end);
        const day = dayLabel(start);
        if (day !== currentDay) {
            html += '<div class="schedule-day">' + day + '</div>';
            currentDay = day;
        }

        const isNow = start <= now && now < end;
        const isPast = end < now;
        let timeStr;
        if (ev.allDay) {
            timeStr = 'All day';
        } else {
            timeStr = timeFmt(start);
            if (end.toDateString() !== start.toDateString()) {
                timeStr += '–' + dateFmt(end) + ' ' + timeFmt(end);
            } else {
                timeStr += '–' + timeFmt(end);
            }
        }
        const cls = 'schedule-item' + (isNow ? ' now' : isPast ? ' past' : '');
        const badge = ev.meeting ? '<span class="schedule-badge">' + esc(ev.meetingType || 'MTG') + '</span>' : '';
        html += '<div class="' + cls + '">' +
            '<span class="schedule-time">' + esc(timeStr) + '</span>' +
            '<span class="schedule-title">' + esc(ev.title || 'Untitled') + '</span>' +
            badge + '</div>';
    }
    body.innerHTML = html;
}

// --- Weather modal ---
function toggleWeatherModal() {
    const modal = document.getElementById('weatherModal');
    if (!modal.classList.contains('active')) {
        const w = slowData.weather;
        if (w && w.available) {
            renderDetailedWeather(w);
        } else {
            document.getElementById('weatherModalBody').innerHTML =
                '<div class="schedule-empty">No weather data</div>';
        }
    }
    modal.classList.toggle('active');
}

function renderDetailedWeather(w) {
    const body = document.getElementById('weatherModalBody');
    let html = '';

    html += '<div class="weather-detail-current">';
    const stats = [
        ['Feels Like', (w.feelsLike || '—') + '°F'],
        ['Humidity', (w.humidity || '—') + '%'],
        ['Wind', (w.windMph || '—') + ' mph ' + (w.windDir || '')],
        ['UV Index', w.uvIndex || '—'],
        ['Visibility', w.visibility ? w.visibility + ' km' : '—'],
        ['Rain Chance', (w.rainChance || '—') + '%']
    ];
    for (const [label, value] of stats) {
        html += '<div class="weather-detail-stat">' +
            '<span class="weather-detail-label">' + esc(label) + '</span>' +
            '<span class="weather-detail-value">' + esc(value) + '</span></div>';
    }
    html += '</div>';

    if (w.forecast && w.forecast.length > 0) {
        html += '<div class="weather-forecast-header">FORECAST</div>';
        for (const day of w.forecast) {
            const d = new Date(day.date + 'T12:00:00');
            const label = d.toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' });
            html += '<div class="weather-forecast-day">' +
                '<span class="weather-forecast-date">' + esc(label) + '</span>' +
                '<span>' + esc(day.condition || '—') + '</span>' +
                '<span class="weather-forecast-temps">' +
                esc(day.maxTemp || '—') + '° / ' + esc(day.minTemp || '—') + '°</span></div>';
        }
    }

    body.innerHTML = html;
}

function refreshWeatherWithSpinner() {
    const btn = document.getElementById('weatherRefreshBtn');
    const icon = document.getElementById('weatherRefreshIcon');
    btn.classList.add('spinning');
    triggerAction('weather_refresh');
    setTimeout(function() {
        updateStatus(true);
        setTimeout(function() {
            btn.classList.remove('spinning');
            const w = slowData.weather;
            if (w && w.available) renderDetailedWeather(w);
        }, 600);
    }, 800);
}

// --- Attention state ---
// Default empty state; real data comes from /api/status via providers
const defaultAttention = {
    slack:      { severity: 'none', count: 0, label: '' },
    teams:      { severity: 'none', count: 0, label: '' },
    outlook:    { severity: 'none', count: 0, label: '' },
    outlookweb: { severity: 'none', count: 0, label: '' },
    messages:   { severity: 'none', count: 0, label: '' },
};

function updateAttention(state) {
    const tiles = document.querySelectorAll('.app-launcher[data-app-id]');

    tiles.forEach(tile => {
        const appId = tile.dataset.appId;
        const info = state[appId];
        const badge = tile.querySelector('.app-badge');
        const sublabel = tile.querySelector('.app-sublabel');

        tile.classList.remove('attention', 'urgent', 'unreadable', 'loading');

        if (!badge || !sublabel) return;

        if (info && info.severity === 'loading') {
            tile.classList.add('loading');
            badge.textContent = '';
            sublabel.textContent = info.label || 'Loading...';
            return;
        }

        if (!info || info.severity === 'none' || info.count === 0) {
            if (info && info.severity === 'unreadable') {
                tile.classList.add('unreadable');
                badge.textContent = '?';
                sublabel.textContent = info.label || 'offline';
            } else {
                badge.textContent = '';
                sublabel.textContent = '';
            }
            return;
        }

        if (info.severity === 'urgent') {
            tile.classList.add('urgent');
        } else {
            tile.classList.add('attention');
        }

        badge.textContent = info.count > 99 ? '99+' : info.count;
        // Render sublabel with optional colored segments
        if (info.segments && info.segments.length > 0) {
            sublabel.innerHTML = info.segments.map(s => {
                const cls = s.color === 'red' ? 'seg-red' : s.color === 'amber' ? 'seg-amber' : '';
                return '<span class="' + cls + '">' + esc(s.text) + '</span>';
            }).join(' ');
        } else {
            sublabel.textContent = info.label || '';
        }
    });
}

// Apply default attention state on load; real data comes from status polling
updateAttention(defaultAttention);

// Merge real attention data from /api/status providers
function mergeAttention(realState) {
    if (!realState) return;
    const merged = {};
    for (const appId in defaultAttention) {
        merged[appId] = realState[appId] || defaultAttention[appId];
    }
    // Include any apps from real state not in defaults
    for (const appId in realState) {
        if (!merged[appId]) merged[appId] = realState[appId];
    }
    updateAttention(merged);
}

// One poll loop on a tick counter. Two separate intervals (1s and 10s)
// collided every tenth second and fired two simultaneous requests for
// the same endpoint; a single loop can't overlap with itself.
// Fast tick: mic, camera, audio, spotify. Every 10th tick also pulls
// the slow data (calendar, weather).
let statusTick = 0;
setInterval(() => {
    // A hidden page (tablet asleep, tab in the background) can't show
    // anything, and browsers throttle its timers anyway -- so skip the
    // request rather than queueing work that lands stale.
    if (document.hidden) return;
    statusTick++;
    updateStatus(statusTick % 10 === 0);
}, 1000);

// Coming back into view, refresh immediately instead of waiting out
// the rest of the tick.
document.addEventListener('visibilitychange', () => {
    if (!document.hidden) updateStatus(true);
});

// Initial fetch includes everything
updateStatus(true);

// Service worker disabled to prevent stale HTML caching
// if ('serviceWorker' in navigator) {
//     navigator.serviceWorker.register('/sw.js').catch(() => {});
// }
