#!/usr/bin/env node

const https = require('https');
const ical = require('node-ical');
const { DateTime } = require('luxon');

const url = process.argv[2];
const LOCAL_TZ = DateTime.local().zoneName || 'America/Chicago';

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

function findMeetingUrl(ev) {
    const text = (ev.description || '') + '\n' + (ev.location || '');
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

async function main() {
    try {
        const ics = await fetchIcs(url);
        const parsed = ical.parseICS(ics);
        const now = new Date();
        const candidates = [];
        const horizon = new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000);

        for (const [key, ev] of Object.entries(parsed)) {
            if (ev.type !== 'VEVENT' || !ev.start || ev.recurrenceid) continue;

            const instances = ical.expandRecurringEvent(ev, {
                from: now,
                to: horizon,
                expandOngoing: true,
                includeOverrides: true,
                excludeExdates: true
            });
            if (!instances || instances.length === 0) continue;

            for (const inst of instances) {
                const start = inst.start;
                const end = inst.end || new Date(start.getTime() + 60 * 60 * 1000);
                const evData = inst.event || ev;

                const joinURL = findMeetingUrl(evData);
                candidates.push({
                    title: evData.summary || 'Untitled',
                    start: start.toISOString(),
                    end: end.toISOString(),
                    duration: Math.round((end - start) / 60000),
                    source: 'Work',
                    meeting: !!joinURL,
                    meetingType: meetingType(joinURL),
                    joinURL
                });
            }
        }

        candidates.sort((a, b) => new Date(a.start) - new Date(b.start));

        // Build upcoming schedule (next 5 events, including currently in progress)
        const upcoming = candidates.filter(c => {
            const s = new Date(c.start);
            const e = new Date(c.end);
            return (s <= now && now < e) || s >= now;
        }).slice(0, 5).map(c => ({
            title: c.title,
            start: c.start,
            end: c.end,
            meeting: c.meeting,
            meetingType: c.meetingType,
            joinURL: c.joinURL
        }));

        // Find current meeting (in progress) or next upcoming
        let selected = null;
        for (const c of candidates) {
            const s = new Date(c.start);
            const e = new Date(c.end);
            if (s <= now && now < e) {
                selected = c;
                break;
            }
        }
        if (!selected) {
            selected = candidates.find(c => new Date(c.start) >= now) || null;
        }

        if (!selected) {
            console.log(JSON.stringify({ available: false, title: 'No upcoming events', schedule: upcoming }));
            return;
        }

        selected.available = true;
        selected.schedule = upcoming;
        console.log(JSON.stringify(selected));
    } catch (err) {
        console.log(JSON.stringify({ available: false, error: err.message }));
    }
}

main();
