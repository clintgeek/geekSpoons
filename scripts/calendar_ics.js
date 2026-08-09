#!/usr/bin/env node

const https = require('https');
const { DateTime } = require('luxon');

const url = process.argv[2];
const LOCAL_TZ = 'America/Chicago';

const TZ_MAP = {
    'Pacific Standard Time': 'America/Los_Angeles',
    'Central Standard Time': 'America/Chicago',
    'Eastern Standard Time': 'America/New_York',
    'Mountain Standard Time': 'America/Denver',
    'Mountain Daylight Time': 'America/Denver',
    'Central Daylight Time': 'America/Chicago',
    'Eastern Daylight Time': 'America/New_York',
    'Pacific Daylight Time': 'America/Los_Angeles',
    'UTC': 'UTC'
};

function fetchIcs(u) {
    return new Promise((resolve, reject) => {
        https.get(u, { timeout: 15000 }, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                return fetchIcs(res.headers.location).then(resolve, reject);
            }
            if (res.statusCode < 200 || res.statusCode >= 400) {
                reject(new Error('HTTP ' + res.statusCode));
                return;
            }
            let data = '';
            res.setEncoding('utf8');
            res.on('data', (c) => { data += c; });
            res.on('end', () => resolve(data));
        }).on('error', reject);
    });
}

function parseICS(text) {
    const lines = text.split(/\r?\n/);
    const events = [];
    let current = null;
    let inEvent = false;

    for (let i = 0; i < lines.length; i++) {
        let line = lines[i];
        
        while (i + 1 < lines.length && (lines[i + 1].startsWith(' ') || lines[i + 1].startsWith('\t'))) {
            line += lines[++i].substring(1);
        }

        if (line === 'BEGIN:VEVENT') {
            inEvent = true;
            current = { properties: {} };
        } else if (line === 'END:VEVENT' && inEvent) {
            if (current) events.push(current);
            current = null;
            inEvent = false;
        } else if (inEvent && current) {
            const colonIdx = line.indexOf(':');
            if (colonIdx > 0) {
                const fullKey = line.substring(0, colonIdx);
                const value = line.substring(colonIdx + 1);
                
                const [key, ...params] = fullKey.split(';');
                const paramObj = {};
                params.forEach(p => {
                    const [pk, pv] = p.split('=');
                    if (pk && pv) paramObj[pk] = pv;
                });

                current.properties[key] = { value, params: paramObj };
            }
        }
    }
    return events;
}

function parseDateTime(dtStr, tzid) {
    if (!dtStr) return null;
    
    const isUTC = dtStr.endsWith('Z');
    const clean = dtStr.replace('Z', '');
    
    const year = parseInt(clean.substring(0, 4), 10);
    const month = parseInt(clean.substring(4, 6), 10);
    const day = parseInt(clean.substring(6, 8), 10);
    const hour = parseInt(clean.substring(9, 11), 10) || 0;
    const minute = parseInt(clean.substring(11, 13), 10) || 0;
    const second = parseInt(clean.substring(13, 15), 10) || 0;

    if (isUTC) {
        return DateTime.fromObject({ year, month, day, hour, minute, second }, { zone: 'UTC' });
    }

    const zone = TZ_MAP[tzid] || tzid || LOCAL_TZ;
    return DateTime.fromObject({ year, month, day, hour, minute, second }, { zone });
}

function findMeetingUrl(desc, loc) {
    const text = (desc || '') + '\n' + (loc || '');
    const m = text.match(/(https?:\/\/[^\s<>\)\]\n\r]+)/);
    if (!m) return null;
    return m[1].replace(/[<>\)\]].*$/, '');
}

function meetingType(u) {
    if (!u) return null;
    if (u.includes('teams.microsoft.com')) return 'Teams';
    if (u.includes('meet.google') || u.includes('hangouts.google')) return 'Meet';
    if (u.includes('zoom.us')) return 'Zoom';
    if (u.includes('webex.')) return 'Webex';
    return 'Meeting';
}

function parseRRule(rruleStr) {
    if (!rruleStr) return null;
    const parts = {};
    rruleStr.split(';').forEach(p => {
        const [k, v] = p.split('=');
        if (k && v) parts[k] = v;
    });
    return parts;
}

function expandRecurrence(dtStart, rrule, limit = 50) {
    const freq = rrule.FREQ;
    if (!freq) return [dtStart];

    const interval = parseInt(rrule.INTERVAL || '1', 10);
    const count = parseInt(rrule.COUNT || '100', 10);
    const until = rrule.UNTIL ? parseDateTime(rrule.UNTIL) : null;

    const occurrences = [dtStart];
    let current = dtStart;

    for (let i = 1; i < Math.min(count, limit); i++) {
        if (freq === 'DAILY') {
            current = current.plus({ days: interval });
        } else if (freq === 'WEEKLY') {
            current = current.plus({ weeks: interval });
        } else if (freq === 'MONTHLY') {
            current = current.plus({ months: interval });
        } else if (freq === 'YEARLY') {
            current = current.plus({ years: interval });
        } else {
            break;
        }

        if (until && current > until) break;
        occurrences.push(current);
    }

    return occurrences;
}

async function main() {
    try {
        const ics = await fetchIcs(url);
        const events = parseICS(ics);
        const now = DateTime.now().setZone(LOCAL_TZ);
        const candidates = [];

        for (const ev of events) {
            const summary = ev.properties.SUMMARY?.value || 'Untitled';
            const dtStartProp = ev.properties.DTSTART;
            const dtEndProp = ev.properties.DTEND;
            const rruleProp = ev.properties.RRULE;
            const desc = ev.properties.DESCRIPTION?.value || '';
            const loc = ev.properties.LOCATION?.value || '';

            if (!dtStartProp) continue;

            const tzid = dtStartProp.params.TZID;
            const baseStart = parseDateTime(dtStartProp.value, tzid);
            const baseEnd = dtEndProp ? parseDateTime(dtEndProp.value, dtEndProp.params.TZID || tzid) : baseStart.plus({ hours: 1 });

            if (!baseStart || !baseEnd) continue;

            const duration = baseEnd.diff(baseStart);
            const rrule = rruleProp ? parseRRule(rruleProp.value) : null;

            let occurrences = [baseStart];
            if (rrule) {
                occurrences = expandRecurrence(baseStart, rrule);
            }

            for (const occ of occurrences) {
                const start = occ.setZone(LOCAL_TZ);
                const end = start.plus(duration);

                if (end < now) continue;

                const joinURL = findMeetingUrl(desc, loc);
                candidates.push({
                    title: summary,
                    start: start.toISO(),
                    end: end.toISO(),
                    duration: Math.round(duration.as('minutes')),
                    source: 'Work',
                    meeting: !!joinURL,
                    meetingType: meetingType(joinURL),
                    joinURL
                });
            }
        }

        candidates.sort((a, b) => new Date(a.start) - new Date(b.start));

        let selected = null;
        for (const c of candidates) {
            const s = DateTime.fromISO(c.start);
            const e = DateTime.fromISO(c.end);
            if (s <= now && now < e) {
                selected = c;
                break;
            }
        }
        if (!selected) {
            selected = candidates.find(c => DateTime.fromISO(c.start) >= now) || null;
        }

        if (!selected) {
            console.log(JSON.stringify({ available: false, title: 'No upcoming events' }));
            return;
        }

        selected.available = true;
        console.log(JSON.stringify(selected));
    } catch (err) {
        console.log(JSON.stringify({ available: false, error: err.message }));
    }
}

main();
