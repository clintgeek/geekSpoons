#!/usr/bin/env node

const https = require('https');
const ical = require('node-ical');

const url = process.argv[2];
const MAX_REDIRECTS = 5;

// Recurrence expansion is the expensive part of this script, and it runs once a
// minute against every VEVENT in the feed. The schedule modal shows all of
// today's events plus the next few upcoming, so start with a short horizon and
// widen only if that didn't fill the list -- a calendar with a sparse next few
// weeks still resolves.
const HORIZON_DAYS = [45, 365];
const WANTED = 5; // upcoming events beyond today kept for the schedule modal

function fetchIcs(u, redirectsLeft = MAX_REDIRECTS) {
    return new Promise((resolve, reject) => {
        https.get(u, { timeout: 15000 }, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                // Bounded: a feed that redirects to itself would otherwise
                // recurse until the process ran out of stack.
                if (redirectsLeft <= 0) {
                    reject(new Error('too many redirects'));
                    return;
                }
                res.resume();
                return fetchIcs(res.headers.location, redirectsLeft - 1).then(resolve, reject);
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

function isUpcoming(c, now) {
    const s = new Date(c.start);
    const e = new Date(c.end);
    return (s <= now && now < e) || s >= now;
}

function collect(parsed, now, horizonDays) {
    const candidates = [];
    const horizon = new Date(now.getTime() + horizonDays * 24 * 60 * 60 * 1000);

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
                allDay: !!inst.isFullDay,
                source: 'Work',
                meeting: !!joinURL,
                meetingType: meetingType(joinURL),
                joinURL
            });
        }
    }

    candidates.sort((a, b) => new Date(a.start) - new Date(b.start));
    return candidates;
}

async function main() {
    try {
        const ics = await fetchIcs(url);
        const parsed = ical.parseICS(ics);
        const now = new Date();

        let candidates = [];
        for (const days of HORIZON_DAYS) {
            candidates = collect(parsed, now, days);
            if (candidates.filter(c => isUpcoming(c, now)).length >= WANTED) break;
        }

        // Build the schedule: everything on today's calendar (all-day events
        // and meetings that already ended included, plus anything still
        // running from earlier), then the next WANTED events after today so
        // the modal still shows what's coming.
        const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const startOfTomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        const isOngoing = (c) => new Date(c.start) <= now && now < new Date(c.end);

        const todays = candidates.filter(c => {
            const s = new Date(c.start);
            return (s >= startOfToday && s < startOfTomorrow) || isOngoing(c);
        });
        const future = candidates.filter(c => new Date(c.start) >= startOfTomorrow).slice(0, WANTED);

        const schedule = todays.concat(future).map(c => ({
            title: c.title,
            start: c.start,
            end: c.end,
            allDay: c.allDay,
            meeting: c.meeting,
            meetingType: c.meetingType,
            joinURL: c.joinURL
        }));

        // Find current meeting (in progress) or next upcoming. All-day events
        // are skipped -- one would read as "NOW" for 24 hours straight and
        // mask the meetings that actually matter.
        let selected = null;
        for (const c of candidates) {
            if (c.allDay) continue;
            const s = new Date(c.start);
            const e = new Date(c.end);
            if (s <= now && now < e) {
                selected = c;
                break;
            }
        }
        if (!selected) {
            selected = candidates.find(c => !c.allDay && new Date(c.start) >= now) || null;
        }

        if (!selected) {
            console.log(JSON.stringify({ available: false, title: 'No upcoming events', schedule }));
            return;
        }

        selected.available = true;
        selected.schedule = schedule;
        console.log(JSON.stringify(selected));
    } catch (err) {
        console.log(JSON.stringify({ available: false, error: err.message }));
    }
}

main();
