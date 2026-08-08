The architecture I'd use
                 ┌─────────────────┐
                 │   Hammerspoon   │
                 │                 │
                 │  State Manager  │
                 └────────┬────────┘
                          │
             ┌────────────┼────────────┐
             │            │            │
        SlackProvider  TeamsProvider  MailProvider
             │            │            │
        Slack API     Graph API     macOS/API
             │            │            │
             └────────────┼────────────┘
                          │
                    Normalized State
                          │
                    ┌─────▼─────┐
                    │ Dashboard │
                    └───────────┘

The important part is that the dashboard doesn't know anything about Slack or Teams.

It receives something like:

{
    id = "slack",
    state = "attention",
    count = 7,
    mentions = 2,
    label = "Slack"
}

Then the UI decides how to represent that.

Information acquisition: use the least shitty source available

I'd establish a hierarchy.

Tier 1 — Official API

Best option.

If an application has an authenticated API that exposes exactly what you want, use it.

For example, Slack has a proper unread concept in its client, and its APIs can give you the underlying conversation/message information.

For Teams, Microsoft Graph is the more durable integration point than poking around inside the Teams desktop application's UI. Microsoft's own guidance recommends retrieving data once, caching it, and using change notifications rather than repeatedly rereading everything.

This is the correct engineering solution, even though authentication and permissions make it considerably more work.

Tier 2 — macOS application state

If all you need is:

"Does this application currently have something waiting for me?"

then don't overengineer it.

Hammerspoon can identify running applications, their bundle IDs, activation state, windows, menus, etc.

That's enough for things like:

Slack
●

Teams
●

Outlook

where the dot means something is happening, without pretending you know exactly how many things.

Tier 3 — Accessibility API

This is the fallback when the application doesn't expose a useful API.

You inspect the application's accessibility tree and extract the information the UI itself exposes.

Useful, but brittle.

I'd treat it as an adapter:

Slack
 └── API provider

Teams
 └── Graph provider

Messages
 └── Accessibility provider

RandomApp
 └── Dock/application-state provider

Not:

Everything
 └── Accessibility scraping

That distinction will save you pain later.

Then normalize everything

This is the part I'd be quite opinionated about.

Don't make your dashboard understand:

Slack has unread messages, Teams has chats, Outlook has unread mail, Messages has conversations...

Instead define a common attention model.

Something like:

Attention = {
    count = 0,
    severity = "none",
    categories = {},
    lastUpdated = nil
}

Where categories might be:

mention
direct_message
unread
meeting
call
urgent

So Slack might report:

count = 7
categories = {
    mention = 2,
    direct_message = 1,
    unread = 7
}

Teams:

count = 3
categories = {
    mention = 1,
    direct_message = 2
}

Outlook:

count = 4
categories = {
    unread = 4
}

Now your UI doesn't care where the information came from.

And I wouldn't display the raw counts by default

This is where I think your current dashboard could get really good.

The primary question isn't:

"How many unread things exist?"

It's:

"Does anything here require my attention?"

So I'd use three levels.

Normal
┌──────────────┐
│      S       │
│    Slack     │
└──────────────┘

Nothing happening.

Attention
┌──────────────┐
│      S    7  │
│    Slack     │
└──────────────┘

Something is waiting.

Important
┌──────────────┐
│      S   ●   │
│    Slack     │
│   2 mentions │
└──────────────┘

Something deserves more immediate attention.

I would not make the whole tile bright red because Slack has 47 unread messages. That's how you end up with a dashboard that looks like a nuclear reactor control panel.

A little badge is enough.

I'd make the badge semantic

For example:

Slack

7 → seven unread

@2 → two mentions

DM → direct message waiting

Teams

3 → three notifications

● → active meeting/call

Outlook

12 → unread mail

Maybe a tiny envelope icon if there are unread messages.

The number tells you volume.

The indicator tells you why you should care.

And there's one really important distinction

I'd separate unread from attention.

Those are not the same thing.

You can have:

Slack: 147 unread

and not give a shit.

Meanwhile:

Teams: 1 unread

could be your boss saying:

"Can you jump on a call?"

Those should not have equal visual weight.

So I'd have something conceptually like:

{
    unread = 147,
    attention = 0,
    urgent = 0
}

And display based primarily on attention, with unread as secondary information.

That's much closer to how a human actually prioritizes information.

The dashboard itself

Looking at what you've already built, I'd keep the large tiles.

I wouldn't turn this into a tiny notification-monitoring Bloomberg terminal.

I'd make each app tile something like:

┌───────────────────────────┐
│                           │
│             S          7  │
│                           │
│           Slack           │
│                           │
│       2 mentions          │
│                           │
└───────────────────────────┘

Click:

launch/focus Slack

Right-click:

Open
Open Unreads
Open Mentions
Mark all read

That gives the tile action + state.

And that's much more useful than a passive status display.

Then I'd add one global indicator

Something at the top of the dashboard:

● 3 things need your attention

Click it:

ATTENTION

Slack       2 mentions
Teams       1 direct message
Outlook     0

Now the dashboard answers the question:

"What do I need to deal with?"

without forcing you to inspect eight applications.

That's the real value.

And I'd make the refresh model event-driven where possible

Don't do:

every 1 second:
    ask Slack
    ask Teams
    ask Outlook
    ask everything

That's garbage.

Instead:

API/event says something changed
            ↓
      update provider
            ↓
      update state
            ↓
       refresh UI

For things where you can't get events, use modest polling—say 15–60 seconds depending on the source.

Hammerspoon's application watcher gives you a nice local event mechanism for application lifecycle/focus changes.

And here's where I'd draw the line

I'd build the abstraction first, even if the first providers are embarrassingly simple.

providers/
    slack.lua
    teams.lua
    outlook.lua
    messages.lua

core/
    state.lua
    attention.lua
    events.lua

ui/
    dashboard.lua
    app_tile.lua

Then you can start with:

Slack → Accessibility
Teams → Accessibility
Outlook → Accessibility
Messages → Accessibility

and replace individual providers with proper APIs later.

The UI doesn't change.

The state model doesn't change.

Only the provider changes.

That's the bit that keeps this from becoming a giant init.lua full of:

if app == "Slack" then
    -- please God let this still work after the next update
end

That is the architecture I'd use. The dashboard you've already built is good enough to be the presentation layer; the next step is making the information feeding it clean, normalized, and boring. That's the good kind of boring.