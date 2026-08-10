#!/usr/bin/env node
// teams_unread.js: Reads unread counts from Teams sidebar via Chrome DevTools Protocol
// Requires Teams to be running with WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--remote-debugging-port=9223
const WebSocket = require(require('path').join(__dirname, 'node_modules', 'ws'));

const DEBUG_PORT = 9223;
const TIMEOUT_MS = 5000;       // give up if Teams doesn't respond in 5 seconds
const PROBE_TIMEOUT_MS = 3000; // per-tab probe timeout for tree item count

function checkTreeItemCount(wsUrl) {
    return new Promise((resolve, reject) => {
        const ws = new WebSocket(wsUrl);
        ws.on('open', () => {
            ws.send(JSON.stringify({
                id: 1,
                method: 'Runtime.evaluate',
                params: { expression: 'document.querySelectorAll("[role=treeitem]").length', returnByValue: true }
            }));
        });
        ws.on('message', (data) => {
            const msg = JSON.parse(data);
            if (msg.id === 1) {
                resolve(msg.result && msg.result.result && msg.result.result.value || 0);
                ws.close();
            }
        });
        ws.on('error', reject);
        setTimeout(() => { ws.close(); reject(new Error('timeout')); }, PROBE_TIMEOUT_MS);
    });
}

async function getUnreadCount() {
    const resp = await fetch(`http://127.0.0.1:${DEBUG_PORT}/json`);
    const tabs = await resp.json();

    // Find the Teams page tab that has the chat tree (most tree items)
    const pageTabs = tabs.filter(t => t.type === 'page' && t.url && t.url.includes('teams.microsoft.com'));
    if (pageTabs.length === 0) {
        console.log(JSON.stringify({error: 'no teams tab', people: 0, meetings: 0, channels: 0}));
        return;
    }

    // Try each page tab to find the one with tree items
    let bestTab = null;
    let bestCount = 0;
    for (const tab of pageTabs) {
        try {
            const count = await checkTreeItemCount(tab.webSocketDebuggerUrl);
            if (count > bestCount) {
                bestCount = count;
                bestTab = tab;
            }
        } catch(e) {}
    }

    if (!bestTab || bestCount === 0) {
        console.log(JSON.stringify({error: 'no tree items', people: 0, meetings: 0, channels: 0}));
        return;
    }

    const ws = new WebSocket(bestTab.webSocketDebuggerUrl);
    let msgId = 1;

    ws.on('open', () => {
        const js = `
            var items = document.querySelectorAll('[role=treeitem]');
            var people = 0;
            var meetings = 0;
            var channels = 0;
            var currentSection = 'other';

            for (var i = 0; i < items.length; i++) {
                var item = items[i];
                var level = item.getAttribute('aria-level') || '1';
                var text = item.textContent.trim();

                // Track section by L1 headers
                if (level === '1') {
                    if (text.toLowerCase().includes('chat')) currentSection = 'chat';
                    else if (text.toLowerCase().includes('team') && text.toLowerCase().includes('channel')) currentSection = 'channel';
                    else if (text.toLowerCase().includes('communit')) currentSection = 'community';
                    else currentSection = 'other';
                    continue;
                }

                // Check for unread: fui-Badge class or aria-labelledby containing 'chat_list_unread_text'
                var hasBadge = item.querySelector('.fui-Badge');
                var ariaLabelledBy = item.getAttribute('aria-labelledby') || '';
                var isUnread = !!hasBadge || ariaLabelledBy.includes('chat_list_unread_text');

                if (!isUnread) continue;

                // Determine chat type from aria-labelledby
                var isOneOnOne = ariaLabelledBy.includes('one-on-one-chat-support-text');
                var isGroup = ariaLabelledBy.includes('chat-group-support-text');
                var isMeeting = ariaLabelledBy.includes('chat-meeting-support-text');

                if (currentSection === 'channel' || currentSection === 'community') {
                    channels++;
                } else if (isMeeting) {
                    meetings++;
                } else {
                    // one-on-one, group, or fallback — all people chats
                    people++;
                }
            }

            JSON.stringify({people: people, meetings: meetings, channels: channels});
        `;

        ws.send(JSON.stringify({
            id: msgId,
            method: 'Runtime.evaluate',
            params: { expression: js, returnByValue: true }
        }));
    });

    ws.on('message', (data) => {
        const msg = JSON.parse(data);
        if (msg.id === msgId) {
            const val = msg.result && msg.result.result && msg.result.result.value;
            console.log(val);
            ws.close();
        }
    });

    ws.on('error', (err) => {
        console.log(JSON.stringify({error: err.message, people: 0, meetings: 0, channels: 0}));
    });

    setTimeout(() => { ws.close(); process.exit(0); }, TIMEOUT_MS);
}

getUnreadCount().catch(e => console.log(JSON.stringify({error: e.message, people: 0, meetings: 0, channels: 0})));
