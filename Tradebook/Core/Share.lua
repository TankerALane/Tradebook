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
--   T~<npcID>~<name>~<skillLineID>~<uiMapID>~<x>~<y>~<seenAt>   (a trainer)
--   S~<name>~<subText>~<type>~<level>~<skill req>~<cost>~<prof>  (its services, as read)
--   C~<npcID>~<seenAt>      a vendor you scanned that still matches the community data
--   CT~<npcID>~<seenAt>     a trainer that still matches
--   D~<bandID>~<casts>~<itemID>:<times>:<total>:<min>:<max>;...   what your disenchants of one
--                           Forever disenchant band gave (Core/Disenchant.lua). Older copies
--                           of Tradebook skip these lines.
-- "~" and line breaks are removed from names.
-- NPCs that still match what Tradebook already ships (Data/CommunityVendors.lua /
-- CommunityTrainers.lua) are sent as one C / CT line ("confirmed again") instead of in full.
-- Lower gold prices than the community's (by up to 25%) still match: that's a reputation
-- discount, not a change.

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

local DISCOUNT = 0.75 -- a price this much lower than the community's is still the same price

-- PURE. Does a vendor scan still match the community's entry? (Same items and costs, gold
-- prices equal or a reputation discount lower; nothing the scan would add, like a location.)
-- Limited-stock items the community has may be missing (sold out).
function Share.VendorMatches(e, c)
    if not c or not c.items then return false end
    if e.loc and not c.loc then return false end
    for itemID, it in pairs(e.items or {}) do
        local ci = c.items[itemID]
        if not ci then return false end
        if (it.c or "") ~= (ci.c or "") then return false end
        if it.p and not ci.p then return false end
        if it.p and ci.p and (it.p > ci.p or it.p < ci.p * DISCOUNT) then return false end
    end
    for itemID, ci in pairs(c.items) do
        if not (e.items and e.items[itemID]) and (ci.s or -1) < 0 then return false end
    end
    return true
end

-- PURE. Does a trainer read still match the community's? (Same services; costs equal or a
-- reputation discount lower.)
function Share.TrainerMatches(t, c)
    if not c or not c.services then return false end
    if t.loc and not c.loc then return false end
    local function index(services)
        local out, n = {}, 0
        for _, line in ipairs(services or {}) do
            local name, sub, _, _, _, cost = line:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
            if name then
                out[name .. "|" .. sub] = tonumber(cost) or false
                n = n + 1
            end
        end
        return out, n
    end
    local mine, n1 = index(t.services)
    local theirs, n2 = index(c.services)
    if n1 ~= n2 then return false end
    for key, cost in pairs(mine) do
        local tc = theirs[key]
        if tc == nil then return false end -- a service they don't have
        if cost and tc and (cost > tc or cost < tc * DISCOUNT) then return false end
    end
    return true
end

-- PURE. The share text for saved vendors and trainers. Only vendors seen with items and
-- trainers with services are included. opts (optional):
--   community, communityTrainers   what Tradebook ships: matching NPCs become C / CT lines
--   since                          only NPCs scanned after this time (your last share)
-- Returns text, vendors, trainers (counted with confirmations) and
-- { vendors, trainers, confirmed } (full entries and confirmations).
function Share.Encode(vendors, build, version, trainers, opts)
    opts = opts or {}
    local since = opts.since or 0
    local ids, confirm = {}, {}
    for npc, e in pairs(vendors or {}) do
        if e.items and next(e.items) and (e.seenAt or 0) > since then
            if Share.VendorMatches(e, opts.community and opts.community[npc]) then
                confirm[#confirm + 1] = { "C", npc, e.seenAt or "" }
            else
                ids[#ids + 1] = npc
            end
        end
    end
    table.sort(ids)
    local tids = {}
    for npc, t in pairs(trainers or {}) do
        if t.services and #t.services > 0 and (t.seenAt or 0) > since then
            if Share.TrainerMatches(t, opts.communityTrainers and opts.communityTrainers[npc]) then
                confirm[#confirm + 1] = { "CT", npc, t.seenAt or "" }
            else
                tids[#tids + 1] = npc
            end
        end
    end
    table.sort(tids)
    table.sort(confirm, function(a, b) return a[1] .. a[2] < b[1] .. b[2] end)
    local nv, nt = #ids, #tids
    for _, c in ipairs(confirm) do
        if c[1] == "C" then nv = nv + 1 else nt = nt + 1 end
    end
    local out = { table.concat({ "TBV1", clean(build), clean(version), nv, nt }, "~") }
    for _, c in ipairs(confirm) do out[#out + 1] = table.concat(c, "~") end
    for _, line in ipairs(Share.DisenchantLines(opts.disenchants)) do out[#out + 1] = line end
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
    for _, npc in ipairs(tids) do
        local t = trainers[npc]
        local loc = t.loc or {}
        out[#out + 1] = table.concat({ "T", npc, clean(t.name), t.skill or "", loc.m or "", loc.x or "", loc.y or "",
            t.seenAt or "" }, "~")
        for _, line in ipairs(t.services) do
            local f = {}
            for field in (line .. "|"):gmatch("([^|]*)|") do f[#f + 1] = clean(field) end
            out[#out + 1] = "S~" .. table.concat(f, "~")
        end
    end
    return table.concat(out, "\n"), nv, nt, { vendors = #ids, trainers = #tids, confirmed = #confirm }
end

-- PURE. D lines for disenchant records ({ [bandID] = { n, mats = { [itemID] = { t, q, lo, hi } } } }),
-- bands in order.
function Share.DisenchantLines(records)
    local bands = {}
    for band, rec in pairs(records or {}) do
        if type(band) == "number" and rec.n and rec.n > 0 then bands[#bands + 1] = band end
    end
    table.sort(bands)
    local out = {}
    for _, band in ipairs(bands) do
        local rec = records[band]
        local mats = {}
        for id in pairs(rec.mats or {}) do mats[#mats + 1] = id end
        table.sort(mats)
        local parts = {}
        for _, id in ipairs(mats) do
            local m = rec.mats[id]
            parts[#parts + 1] = table.concat({ id, m.t, m.q, m.lo, m.hi }, ":")
        end
        out[#out + 1] = table.concat({ "D", band, rec.n, table.concat(parts, ";") }, "~")
    end
    return out
end

-- PURE. Parse share text back: vendors { [npcID] = { name, loc = { m, x, y }, seenAt, items } },
-- trainers { [npcID] = { name, skill, loc, seenAt, services } }, confirmations and disenchant
-- records { [bandID] = { n, mats } } (unchecked: see Net.CleanDisenchant), or nil plus an error.
function Share.Decode(text)
    local vendors, current = {}, nil
    local trainers, trainer = {}, nil
    local confirmed = {}
    local disenchants = {}
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
        elseif f[1] == "T" and tonumber(f[2]) then
            trainer = { name = f[3], skill = tonumber(f[4]), seenAt = tonumber(f[8]), services = {},
                loc = tonumber(f[5]) and { m = tonumber(f[5]), x = tonumber(f[6]), y = tonumber(f[7]) } or nil }
            trainers[tonumber(f[2])] = trainer
            current = nil
        elseif (f[1] == "C" or f[1] == "CT") and tonumber(f[2]) then
            confirmed[#confirmed + 1] = { kind = f[1] == "C" and "vendor" or "trainer", npc = tonumber(f[2]),
                seenAt = tonumber(f[3]) }
            current, trainer = nil, nil
        elseif f[1] == "S" and trainer then
            table.remove(f, 1)
            trainer.services[#trainer.services + 1] = table.concat(f, "|")
        elseif f[1] == "D" and tonumber(f[2]) and tonumber(f[3]) then
            local rec = { n = tonumber(f[3]), mats = {} }
            for part in (f[4] or ""):gmatch("[^;]+") do
                local id, t, q, lo, hi = part:match("^(%d+):(%d+):(%d+):(%d+):(%d+)$")
                if id then
                    rec.mats[tonumber(id)] = { t = tonumber(t), q = tonumber(q), lo = tonumber(lo), hi = tonumber(hi) }
                end
            end
            disenchants[tonumber(f[2])] = rec
            current, trainer = nil, nil
        end
    end
    if not header then return nil, "missing TBV1 header" end
    return vendors, trainers, confirmed, disenchants
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
    -- Copying counts as sharing: the next share only holds what you scan after this.
    popup.select:HookScript("OnClick", function() ns.db.settings.lastShareAt = GetServerTime() end)
    popup.all = W.Check(popup, L.SHARE_ALL, function(checked)
        ns.db.settings.shareAll = checked or nil
        Share.Show(true)
    end)
    popup.all:SetPoint("BOTTOMRIGHT", -150, 10)
    popup.count = W.Text(popup, "GameFontDisableSmall")
    popup.count:SetPoint("LEFT", popup.select, "RIGHT", 10, 0)
    popup.count:SetPoint("RIGHT", popup.all, "LEFT", -6, 0)
    tinsert(UISpecialFrames, "TradebookShareFrame")
    popup:Hide()
    sharePopup = popup
    return popup
end

function Share.Show()
    local p = ensure()
    local version = Compat.Call("C_AddOns.GetAddOnMetadata", "Tradebook", "Version") or "?"
    local build = Compat.Call("GetBuildInfo") or "?"
    local s = ns.db.settings
    p.all:SetChecked(s.shareAll == true)
    local text, nv, nt, stats = Share.Encode(ns.db.vendors, build, version, ns.db.trainers, {
        community = ns.CommunityVendors, communityTrainers = ns.CommunityTrainers,
        since = not s.shareAll and s.lastShareAt or nil })
    p.text = text
    p.box:SetText(text)
    p.url:SetText(ISSUE_URL)
    local count = nv + nt
    p.help:SetText(count > 0 and L.SHARE_HELP or (s.lastShareAt and not s.shareAll and L.SHARE_NOTHING_NEW or L.SHARE_NOTHING))
    p.count:SetText(L.SHARE_COUNT:format(stats.vendors, stats.trainers, stats.confirmed))
    p:Show()
    if count > 0 then
        p.box:SetFocus()
        p.box:HighlightText()
    end
end
