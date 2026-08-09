#!/usr/bin/env node
// slack_unread.js: Reads unread count from Slack's sidebar via Chrome DevTools Protocol
// Requires Slack to be running with --remote-debugging-port=9222
const WebSocket = require(require('path').join(__dirname, 'node_modules', 'ws'));

const DEBUG_PORT = 9222;
const TIMEOUT_MS = 3000;  // give up if Slack doesn't respond in 3 seconds

async function getUnreadCount() {
    // Get the list of debug targets
    const resp = await fetch(`http://127.0.0.1:${DEBUG_PORT}/json`);
    const tabs = await resp.json();
    
    // Find the Slack client tab
    const tab = tabs.find(t => t.url && t.url.includes('app.slack.com/client'));
    if (!tab) {
        console.log(JSON.stringify({error: 'no slack tab', channels: 0, dms: 0, badges: 0}));
        return;
    }
    
    const ws = new WebSocket(tab.webSocketDebuggerUrl);
    let msgId = 1;
    
    ws.on('open', () => {
        const js = `
            var unreadItems = document.querySelectorAll('.p-channel_sidebar__channel--unread');
            var channels = 0;
            var dms = 0;
            var badges = 0;
            
            unreadItems.forEach(function(item) {
                // Skip non-channel items like "Invite people"
                if (item.classList.contains('p-channel_sidebar__link--add-more-items')) return;
                
                // Distinguish DMs from channels:
                // DMs have a child with data-qa="channel-prefix-im-avatar"
                var isDM = item.querySelector('[data-qa="channel-prefix-im-avatar"]') !== null;
                
                if (isDM) {
                    dms++;
                } else {
                    channels++;
                }
                
                // Count badge values
                var badgeEl = item.querySelector('[data-qa="badge"], [class*="badge"]');
                if (badgeEl) {
                    var badgeText = badgeEl.textContent.trim();
                    var badgeNum = parseInt(badgeText);
                    if (!isNaN(badgeNum)) badges += badgeNum;
                }
            });
            
            JSON.stringify({channels: channels, dms: dms, badges: badges});
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
        console.log(JSON.stringify({error: err.message, channels: 0, dms: 0, badges: 0}));
    });
    
    setTimeout(() => { ws.close(); process.exit(0); }, TIMEOUT_MS);
}

getUnreadCount().catch(e => console.log(JSON.stringify({error: e.message, channels: 0, dms: 0, badges: 0})));
