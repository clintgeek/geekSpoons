-- providers/outlook-web.lua: Outlook Web/PWA attention provider.
--
-- Outlook Web renders the inbox folder as a treeitem with
-- data-folder-name="inbox" and a title attribute like:
--   "Inbox - 48 items (6 unread)"
-- We query that element and parse the unread count out of the title.
--
-- See providers/chrometab.lua for how the probe works and what it needs.

local chrometab = require("providers.chrometab")

local outlookweb = {}

outlookweb.getAttention = chrometab.new({
    urls = { "outlook.office.com", "outlook.office365.com", "outlook.cloud.microsoft" },
    js = [[var el=document.querySelector('[data-folder-name="inbox"]');if(el){var m=el.title.match(/\((\d+) unread\)/);m?m[1]:'0'}else{'NOTFOUND'}]],
    missingLabel = "no Outlook tab",
})

return outlookweb
