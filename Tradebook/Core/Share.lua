-- Core/Share.lua
-- /tb share: your vendor scans as text to paste into a GitHub issue ("Vendor data" form), so
-- they can be merged into the community database (Data/CommunityVendors.lua) for everyone.
-- Only vendor data is shared: vendor names, IDs, where they stand, what they sell and for how
-- much. Nothing about your characters or account.
--
-- Format (one record per line, fields separated by "~"):
--   TBV1~<game build>~<Tradebook version>~<vendors>
--   V~<npcID>~<name>~<uiMapID>~<x>~<y>~<seenAt>
--   I~<itemID>~<gold price or "">~<stock>~<cost or "">      (items of the V line above)
-- "~" and line breaks are removed from names.

local _, ns = ...
local L, Compat = ns.L, ns.Compat
-- ns.W (UI/Widgets.lua) loads after the core files: looked up when the window is built.

local Share = {}
ns.Share = Share

local ISSUE_URL = "https://github.com/TankerALane/Tradebook/issues/new?template=vendor-data.yml"
Share.ISSUE_URL = ISSUE_URL

local function clean(s)
    return (tostring(s or ""):gsub("[~\r\n|]", " "))
end

-- PURE. The share text for a saved-vendors table. Only vendors seen with items are included.
function Share.Encode(vendors, build, version)
    local ids = {}
    for npc, e in pairs(vendors or {}) do
        if e.items and next(e.items) then ids[#ids + 1] = npc end
    end
    table.sort(ids)
    local out = { table.concat({ "TBV1", clean(build), clean(version), #ids }, "~") }
    for _, npc in ipairs(ids) do
        local e = vendors[npc]
        local loc = e.loc or {}
        out[#out + 1] = table.concat({ "V", npc, clean(e.name), loc.m or "", loc.x or "", loc.y or "", e.seenAt or "" }, "~")
        local items = {}
        for itemID in pairs(e.items) do items[#items + 1] = itemID end
        table.sort(items)
        for _, itemID in ipairs(items) do
            local it = e.items[itemID]
            out[#out + 1] = table.concat({ "I", itemID, it.p or "", it.s or -1, clean(it.c or "") }, "~")
        end
    end
    return table.concat(out, "\n"), #ids
end

-- PURE. Parse share text back: { [npcID] = { name, loc = { m, x, y }, seenAt, items } }, or nil
-- plus an error.
function Share.Decode(text)
    local vendors, current = {}, nil
    local header = false
    for line in (text or ""):gmatch("[^\r\n]+") do
        local f = {}
        for field in (line .. "~"):gmatch("([^~]*)~") do f[#f + 1] = field end
        if f[1] == "TBV1" then
            header = true
        elseif f[1] == "V" and tonumber(f[2]) then
            current = { name = f[3], seenAt = tonumber(f[7]), items = {},
                loc = tonumber(f[4]) and { m = tonumber(f[4]), x = tonumber(f[5]), y = tonumber(f[6]) } or nil }
            vendors[tonumber(f[2])] = current
        elseif f[1] == "I" and current and tonumber(f[2]) then
            current.items[tonumber(f[2])] = { p = tonumber(f[3]), s = tonumber(f[4]) or -1, c = f[5] ~= "" and f[5] or nil }
        end
    end
    if not header then return nil, "missing TBV1 header" end
    return vendors
end

local sharePopup
local function ensure()
    if sharePopup then return sharePopup end
    local W = ns.W
    local popup = _G.TradebookShareFrame or CreateFrame("Frame", "TradebookShareFrame", UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(520, 380)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetToplevel(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup.title = W.Text(popup, "GameFontHighlight", "CENTER")
    popup.title:SetPoint("TOP", 0, -5)
    popup.title:SetText(L.SHARE_TITLE)
    popup.help = W.Text(popup, "GameFontHighlightSmall")
    popup.help:SetPoint("TOPLEFT", 14, -32)
    popup.help:SetPoint("RIGHT", -14, 0)
    popup.help:SetJustifyV("TOP")
    -- Step 2: the issue form address, selectable.
    popup.url = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    popup.url:SetSize(480, 20)
    popup.url:SetPoint("TOPLEFT", popup.help, "BOTTOMLEFT", 6, -8)
    popup.url:SetAutoFocus(false)
    popup.url:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    popup.url:SetScript("OnTextChanged", function(self) self:SetText(ISSUE_URL) end)
    -- The share text, selected for copying.
    local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", popup.url, "BOTTOMLEFT", -4, -12)
    scroll:SetPoint("BOTTOMRIGHT", -32, 40)
    popup.box = CreateFrame("EditBox", nil, scroll)
    popup.box:SetMultiLine(true)
    popup.box:SetFontObject("ChatFontSmall")
    popup.box:SetWidth(440)
    popup.box:SetAutoFocus(false)
    popup.box:SetScript("OnEscapePressed", function() popup:Hide() end)
    popup.box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    popup.box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(popup.text or "") self:HighlightText() end end)
    scroll:SetScrollChild(popup.box)
    popup.select = W.Button(popup, L.SHARE_SELECT, 140, 22)
    popup.select:SetPoint("BOTTOMLEFT", 12, 10)
    popup.select:SetScript("OnClick", function()
        popup.box:SetFocus()
        popup.box:HighlightText()
    end)
    popup.count = W.Text(popup, "GameFontDisableSmall")
    popup.count:SetPoint("LEFT", popup.select, "RIGHT", 10, 0)
    tinsert(UISpecialFrames, "TradebookShareFrame")
    popup:Hide()
    sharePopup = popup
    return popup
end

function Share.Show()
    local p = ensure()
    local version = Compat.Call("C_AddOns.GetAddOnMetadata", "Tradebook", "Version") or "?"
    local build = Compat.Call("GetBuildInfo") or "?"
    local text, count = Share.Encode(ns.db.vendors, build, version)
    p.text = text
    p.box:SetText(text)
    p.url:SetText(ISSUE_URL)
    p.help:SetText(count > 0 and L.SHARE_HELP or L.SHARE_NOTHING)
    p.count:SetText(L.SHARE_COUNT:format(count, #text))
    p:Show()
    if count > 0 then
        p.box:SetFocus()
        p.box:HighlightText()
    end
end
