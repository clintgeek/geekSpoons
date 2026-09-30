-- providers/messages.lua: Google Messages attention provider.
-- Counts sidebar conversations carrying an unread marker.
-- See providers/chrometab.lua for how the probe works and what it needs.

local chrometab = require("providers.chrometab")

local messages = {}

messages.getAttention = chrometab.new({
    urls = { "messages.google.com" },
    js = "var items=document.querySelectorAll('a.list-item');var n=0;for(var i=0;i<items.length;i++){if(items[i].querySelector('.unread'))n++}String(n)",
    missingLabel = "no Messages tab",
})

return messages
