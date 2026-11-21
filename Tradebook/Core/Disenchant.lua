-- Core/Disenchant.lua
-- What an item disenchants into, its value at auction, item tooltips, and a recorder that
-- keeps what your own disenchants actually give in WoW Forever.
--
-- Which items can be disenchanted: Forever's own bands (Data/DisenchantBands.lua). What a band
-- gives: the classic table (Data/Disenchant.lua), shown as "classic, not confirmed in
-- Forever" until CONFIRM_AT recorded disenchants of that band. Then:
--   they fit the classic table (only its materials, counts in its ranges): "confirmed", and
--     the classic chances stay (10 disenchants can't measure a 5% shard or 80/20 better);
--   they don't: what was seen is shown instead (Forever differs for that band).
-- Before CONFIRM_AT, a band whose disenchants already don't fit is flagged (differs).
--
-- Recorder: a Disenchant cast (spell 13262) that succeeds, then the loot window it opens. The
-- item comes from the bag slot clicked while the spell was targeting (or the loot's source
-- GUID). Stored per band in TradebookDB.disenchants (no character data):
--   [bandID] = { n = casts, mats = { [itemID] = { t = times seen, q = total count, lo, hi } },
--                items = { [itemID] = item level read } }  (what was disenchanted, to check bands)
-- PURE parts take their inputs as arguments (tests/run.lua).

local _, ns = ...
local L = ns.L
local Compat = ns.Compat

local Disenchant = {}
ns.Disenchant = Disenchant

Disenchant.SPELL = 13262
Disenchant.CONFIRM_AT = 10 -- recorded disenchants of a band before it counts as checked

local QUALITY_KEY = { [3] = "rare", [4] = "epic" }

-- PURE. Forever's band for an item: { class, quality, min, max, subclass, skill, id } or nil
-- (can't be disenchanted). bands: ns.DisenchantBands.
function Disenchant.Band(bands, classID, quality, itemLevel)
    if not (classID and quality and itemLevel) then return nil end
    for _, b in ipairs(bands or {}) do
        if b[1] == classID and b[2] == quality and itemLevel >= b[3] and itemLevel <= b[4] then return b end
    end
    return nil
end

-- PURE. The classic table's results for an item: { { itemID, chance, min, max } } or nil.
function Disenchant.Classic(classic, classID, quality, itemLevel)
    local rows
    if quality == 2 then
        rows = classID == 2 and classic.weapon or classic.armor
    else
        rows = classic[QUALITY_KEY[quality] or ""]
    end
    for _, row in ipairs(rows or {}) do
        if itemLevel >= row[1] and itemLevel <= row[2] then return row[3], row[4] end
    end
    return nil
end

-- PURE. What was seen for a band as results: { { itemID, chance, min, max } }, most likely first.
function Disenchant.Seen(record)
    local out = {}
    if not (record and record.n and record.n > 0) then return out end
    for itemID, m in pairs(record.mats or {}) do
        out[#out + 1] = { itemID, m.t / record.n, m.lo, m.hi }
    end
    table.sort(out, function(a, b)
        if a[2] ~= b[2] then return a[2] > b[2] end
        return a[1] < b[1]
    end)
    return out
end

-- PURE. Do the recorded disenchants fit these results: only their materials, and counts
-- within their ranges? (A rare material not seen yet is fine.)
function Disenchant.Fits(results, record)
    if not (results and record) then return true end
    local byID = {}
    for _, r in ipairs(results) do byID[r[1]] = r end
    for matID, m in pairs(record.mats or {}) do
        local r = byID[matID]
        if not r or m.lo < r[3] or m.hi > r[4] then return false end
    end
    return true
end

-- PURE. Results for an item: { results, source = "classic" | "confirmed" | "seen", seen = n,
-- players = n, differs = bool, outside = source name (seen in Forever elsewhere), disputed =
-- bool, band } or nil when it can't be disenchanted. records: combined records (Combine).
-- outsideSeen: ns.DisenchantForeverSeen.
function Disenchant.Results(bands, classic, records, classID, quality, itemLevel, outsideSeen)
    local band = Disenchant.Band(bands, classID, quality, itemLevel)
    if not band then return nil end
    local record = records and records[band[7]]
    local seen = record and record.n or 0
    local players = record and record.players or (seen > 0 and 1 or 0)
    local results, note = Disenchant.Classic(classic, classID, quality, itemLevel)
    local fits = Disenchant.Fits(results, record)
    local outside = outsideSeen and outsideSeen[band[7]] or nil
    local out = { seen = seen, players = players, band = band, outside = outside, disputed = note == "disputed" }
    if seen >= Disenchant.CONFIRM_AT and not (results and fits) then
        out.results, out.source, out.outside, out.disputed = Disenchant.Seen(record), "seen", nil, false
        return out
    end
    if not results then return nil end
    out.results = results
    out.source = (seen >= Disenchant.CONFIRM_AT) and "confirmed" or "classic"
    out.differs = not fits
    return out
end

-- PURE. Which bands give a material: { { quality, class, min, max, chance } } from the classic
-- rows of every Forever band (what the tooltips show), most likely first.
function Disenchant.Sources(bands, classic, materialID)
    local out = {}
    for _, b in ipairs(bands or {}) do
        local results = Disenchant.Classic(classic, b[1], b[2], b[3])
        for _, r in ipairs(results or {}) do
            if r[1] == materialID then out[#out + 1] = { b[2], b[1], b[3], b[4], r[2] } end
        end
    end
    table.sort(out, function(a, b)
        if a[1] ~= b[1] then return a[1] < b[1] end
        if a[2] ~= b[2] then return a[2] > b[2] end -- armor (4) before weapons (2)
        return a[3] < b[3]
    end)
    return out
end

-- PURE. "Disenchant", "Vendor" or "Auction" (the most money), and whether the best two are
-- within 10% ("roughly equal"); nil without a disenchant value. Each value: copper or nil.
function Disenchant.Best(de, vendor, auction)
    if not de then return nil end
    local options = { { "disenchant", de } }
    if vendor and vendor > 0 then options[#options + 1] = { "vendor", vendor } end
    if auction and auction > 0 then options[#options + 1] = { "auction", auction } end
    table.sort(options, function(a, b) return a[2] > b[2] end)
    local close = options[2] ~= nil and options[1][2] > 0 and (options[1][2] - options[2][2]) / options[1][2] < 0.10
    return options[1][1], close, options[2] and options[2][1]
end

-- PURE. Expected copper from one disenchant: each result's chance x average count x price.
-- price(itemID) -> copper or nil. nil when any result has no price (a part would mislead).
function Disenchant.Value(results, price)
    if not results or #results == 0 then return nil end
    local total = 0
    for _, r in ipairs(results) do
        local p = price(r[1])
        if not p then return nil end
        total = total + r[2] * (r[3] + r[4]) / 2 * p
    end
    return math.floor(total + 0.5)
end

-- PURE. One player's totals as text, the same for the same totals (to spot copies).
function Disenchant.Fingerprint(bands)
    local parts = {}
    for band, rec in pairs(bands or {}) do
        local mats = {}
        for id, m in pairs(rec.mats or {}) do
            mats[#mats + 1] = table.concat({ id, m.t or 0, m.q or 0, m.lo or 0, m.hi or 0 }, ",")
        end
        table.sort(mats)
        parts[#parts + 1] = band .. ":" .. (rec.n or 0) .. ":" .. table.concat(mats, ";")
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

-- PURE. Your records plus other players' (heard: { [who] = { at, bands } }), per band. Other
-- players count for a band only once 2+ players (you included) have reported it, so one
-- player's report never decides on its own. Returns { [bandID] = { n, mats, players } }.
-- Disenchants are saved for the whole account, so every character of one player sends the
-- same totals: identical totals from several senders count once (seen 2026-11-21: one
-- player's four characters counted as four players).
function Disenchant.Combine(own, heard)
    local unique, seen = {}, {}
    for _, h in pairs(heard or {}) do
        local fp = Disenchant.Fingerprint(h.bands)
        if fp ~= "" and not seen[fp] then
            seen[fp] = true
            unique[#unique + 1] = h
        end
    end
    heard = unique
    local reporters = {}
    local function addReporter(band) reporters[band] = (reporters[band] or 0) + 1 end
    for band, rec in pairs(own or {}) do if (rec.n or 0) > 0 then addReporter(band) end end
    for _, h in pairs(heard) do
        for band in pairs(h.bands or {}) do addReporter(band) end
    end
    local out = {}
    local function add(band, rec)
        local c = out[band]
        if not c then
            c = { n = 0, mats = {}, players = 0 }
            out[band] = c
        end
        c.n, c.players = c.n + rec.n, c.players + 1
        for id, m in pairs(rec.mats or {}) do
            local cm = c.mats[id]
            if not cm then
                cm = { t = 0, q = 0, lo = m.lo, hi = m.hi }
                c.mats[id] = cm
            end
            cm.t, cm.q = cm.t + m.t, cm.q + m.q
            cm.lo, cm.hi = math.min(cm.lo, m.lo), math.max(cm.hi, m.hi)
        end
    end
    for band, rec in pairs(own or {}) do if (rec.n or 0) > 0 then add(band, rec) end end
    for _, h in pairs(heard) do
        for band, rec in pairs(h.bands or {}) do
            if reporters[band] >= 2 then add(band, rec) end
        end
    end
    return out
end

-- PURE. Add one disenchant to the records: band ID, { [itemID] = count }, and (optional) the
-- item disenchanted with the item level it was read at.
function Disenchant.Record(records, bandID, loot, itemID, itemLevel)
    local rec = records[bandID]
    if not rec then
        rec = { n = 0, mats = {} }
        records[bandID] = rec
    end
    rec.n = rec.n + 1
    if itemID then
        rec.items = rec.items or {}
        rec.items[itemID] = itemLevel or true
    end
    for matID, count in pairs(loot) do
        local m = rec.mats[matID]
        if not m then
            m = { t = 0, q = 0, lo = count, hi = count }
            rec.mats[matID] = m
        end
        m.t, m.q = m.t + 1, m.q + count
        m.lo, m.hi = math.min(m.lo, count), math.max(m.hi, count)
    end
    return rec
end

---------------------------------------------------------------------------
-- in game
---------------------------------------------------------------------------

-- Class, quality and base item level of an item (nil while the game hasn't loaded it), and
-- the "detailed" item level the game reports for it when that differs. Forever's disenchant
-- bands (and the classic server tables) go by the base item level.
local function itemFacts(item)
    local name, _, quality, itemLevel, _, _, _, _, _, _, _, classID = Compat.Call("C_Item.GetItemInfo", item)
    if not name then return nil end
    local detailed = type(item) == "string" and Compat.Call("C_Item.GetDetailedItemLevelInfo", item)
    return classID, quality, itemLevel, (detailed and detailed ~= itemLevel) and detailed or nil
end

-- Your disenchants plus other players' (Disenchant.Combine), cached until either changes.
local combined
function Disenchant.Invalidate() combined = nil end

-- PURE. Per band, whichever has more disenchants: what you recorded and heard (live) or the
-- shipped community totals (Data/CommunityDisenchants.lua, made from the same kind of data, so
-- they're never added together: your own results would count twice).
function Disenchant.WithCommunity(live, community)
    local out = {}
    for band, rec in pairs(live or {}) do out[band] = rec end
    for band, rec in pairs(community or {}) do
        if not out[band] or (rec.n or 0) > (out[band].n or 0) then out[band] = rec end
    end
    return out
end

function Disenchant.Records()
    if not combined then
        combined = Disenchant.WithCommunity(
            Disenchant.Combine(ns.db and ns.db.disenchants, ns.Net and ns.Net.HeardDisenchants() or {}),
            ns.CommunityDisenchants)
    end
    return combined
end

-- What an item disenchants into (see Disenchant.Results), or nil.
function Disenchant.ForItem(item)
    if not item then return nil end
    local classID, quality, itemLevel = itemFacts(item)
    if not classID then return nil end
    return Disenchant.Results(ns.DisenchantBands, ns.DisenchantClassic, Disenchant.Records(),
        classID, quality, itemLevel, ns.DisenchantForeverSeen)
end

-- Weapons and armor of green, blue or purple quality that have no band can't be disenchanted.
function Disenchant.CantDisenchant(item)
    local classID, quality, itemLevel = itemFacts(item)
    if not classID or (classID ~= 2 and classID ~= 4) or not quality or quality < 2 or quality > 4 then return false end
    return Disenchant.Band(ns.DisenchantBands, classID, quality, itemLevel) == nil
end

-- Auction value of one disenchant after the auction house cut (needs Auctionator), or nil.
function Disenchant.ValueOf(item)
    if not ns.Prices.Available() then return nil end
    local de = Disenchant.ForItem(item)
    if not de then return nil end
    local value = Disenchant.Value(de.results, function(id) return ns.Prices.Get(id).auction end)
    return value and math.floor(value * (1 - ns.Prices.AH_CUT) + 0.5) or nil
end

local function icon(itemID)
    local tex = Compat.Call("C_Item.GetItemIconByID", itemID)
    return tex and ("|T" .. tex .. ":0|t ") or ""
end

local function itemIDOf(item)
    return type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
end

-- Disenchant or sell? A line naming the option that pays most (needs Auctionator).
local BEST_TEXT = { disenchant = "DE_BEST_DISENCHANT", vendor = "DE_BEST_VENDOR", auction = "DE_BEST_AUCTION" }
local function verdictLine(item, value)
    local vendor = ns.Prices.SellPrice(itemIDOf(item))
    local auction = ns.Prices.Get(itemIDOf(item)).auction
    auction = auction and math.floor(auction * (1 - ns.Prices.AH_CUT) + 0.5) or nil
    local best, close, second = Disenchant.Best(value, vendor, auction)
    if not best or not second then return nil end
    if close then return { "    " .. L.DE_BEST, ns.W.ColorText(ns.W.GOLD, L.DE_ROUGHLY_EQUAL) } end
    return { "    " .. L.DE_BEST, ns.W.ColorText(ns.W.GREEN, L[BEST_TEXT[best]]) }
end

-- Tooltip lines: { left, right } pairs and plain strings. Compact (one line) unless `full`.
function Disenchant.TooltipLines(item, full)
    local de = Disenchant.ForItem(item)
    if not de then
        if Disenchant.CantDisenchant(item) then return { ns.W.ColorText(ns.W.GREY, L.DE_CANT) } end
        return nil
    end
    local value = Disenchant.ValueOf(item)
    local W = ns.W
    if not full then
        local names = {}
        for i, r in ipairs(de.results) do
            if i <= 2 then names[#names + 1] = Compat.ItemInfo(r[1]) or ("item:" .. r[1]) end
        end
        local left = W.ColorText(W.GOLD, L.DE_SHORT) .. " " .. table.concat(names, ", ") .. (#de.results > 2 and ", ..." or "")
        local lines = { { left, value and ns.Prices.Money(value) or "" } }
        local verdict = value and verdictLine(item, value)
        if verdict then lines[#lines + 1] = verdict end
        lines[#lines + 1] = W.ColorText(W.GREY, "    " .. L.DE_SHIFT)
        return lines
    end
    local lines = { W.ColorText(W.GOLD, L.DE_INTO) }
    local priced = ns.Prices.Available()
    for _, r in ipairs(de.results) do
        local name = Compat.ItemInfo(r[1]) or ("item:" .. r[1])
        local count = r[3] == r[4] and tostring(r[3]) or (r[3] .. "-" .. r[4])
        local right = ("%s%%"):format(r[2] < 0.01 and ("%.1f"):format(r[2] * 100) or math.floor(r[2] * 100 + 0.5))
        if priced then
            local p = ns.Prices.Get(r[1]).auction
            right = right .. "  " .. (p and ns.Prices.Money(p) or "?")
        end
        lines[#lines + 1] = { "    " .. icon(r[1]) .. name .. "  x" .. count, right }
    end
    if value then lines[#lines + 1] = { "    " .. L.DE_VALUE, ns.Prices.Money(value) } end
    local verdict = value and verdictLine(item, value)
    if verdict then lines[#lines + 1] = verdict end
    lines[#lines + 1] = W.ColorText(W.GREY, "    " .. Disenchant.SourceText(de))
    if de.disputed then lines[#lines + 1] = W.ColorText(W.GREY, "    " .. L.DE_DISPUTED) end
    return lines
end

-- Where a result comes from, for tooltips: confirmed / seen in Forever / classic.
function Disenchant.SourceText(de)
    local who = (de.players or 0) > 1 and L.DE_PLAYERS:format(de.seen, de.players) or L.DE_COUNT:format(de.seen)
    if de.source == "confirmed" then return L.DE_CONFIRMED:format(who) end
    if de.source == "seen" then return L.DE_SEEN:format(who) end
    if de.differs then return L.DE_CLASSIC_DIFFERS:format(who) end
    if de.outside then
        return de.seen > 0 and L.DE_OUTSIDE_SEEN:format(de.outside, who) or L.DE_OUTSIDE:format(de.outside)
    end
    return de.seen > 0 and L.DE_CLASSIC_SEEN:format(who) or L.DE_CLASSIC
end

-- Material tooltips: which items disenchant into it ("Green armor 16-20 (20%), ...").
local QUALITY_NAME = { [2] = "DE_GREEN", [3] = "DE_BLUE", [4] = "DE_PURPLE" }
local sourceCache = {} -- [itemID] = lines or false (every item tooltip asks)
function Disenchant.SourceLines(itemID)
    if sourceCache[itemID] == nil then sourceCache[itemID] = Disenchant.BuildSourceLines(itemID) or false end
    return sourceCache[itemID] or nil
end

function Disenchant.BuildSourceLines(itemID)
    local list = Disenchant.Sources(ns.DisenchantBands, ns.DisenchantClassic, itemID)
    if #list == 0 then return nil end
    local groups, order = {}, {}
    for _, s in ipairs(list) do
        local key = s[1] * 10 + s[2]
        if not groups[key] then
            groups[key] = { label = L[QUALITY_NAME[s[1]]] .. " " .. (s[2] == 2 and L.DE_WEAPON or L.DE_ARMOR), parts = {} }
            order[#order + 1] = key
        end
        local pct = s[5] < 0.01 and ("%.1f"):format(s[5] * 100) or tostring(math.floor(s[5] * 100 + 0.5))
        groups[key].parts[#groups[key].parts + 1] = ("%d-%d (%s%%)"):format(s[3], s[4], pct)
    end
    local lines = { ns.W.ColorText(ns.W.GOLD, L.DE_FROM) }
    for _, key in ipairs(order) do
        local g = groups[key]
        lines[#lines + 1] = "    " .. g.label .. ": " .. table.concat(g.parts, ", ")
    end
    return lines
end

-- Whether to show disenchant information at all (the Settings switch). Off hides the
-- tooltips, the recipe details' disenchant profit and the "Disenchanting it" profit column;
-- your disenchants are still recorded and shared.
function Disenchant.Shown()
    return not (ns.db and ns.db.settings.deShow == false)
end

local function addTooltip(tooltip, item)
    if not (Disenchant.Shown() and ns.db.settings.deTooltip ~= false) or not item then return end
    local full = ns.db.settings.deCompact == false or IsShiftKeyDown()
    local lines = Disenchant.TooltipLines(item, full)
    if not lines then
        local id = itemIDOf(item)
        lines = id and Disenchant.SourceLines(id)
    end
    if not lines then return end
    for _, line in ipairs(lines) do
        if type(line) == "table" then
            tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1)
        else
            tooltip:AddLine(line)
        end
    end
end

local function hookTooltips()
    local processor = _G.TooltipDataProcessor
    if processor and processor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        processor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if tooltip ~= GameTooltip and tooltip ~= _G.ItemRefTooltip then return end
            local link = data and data.hyperlink
            if not link and tooltip.GetItem then _, link = tooltip:GetItem() end
            addTooltip(tooltip, link or (data and data.id))
        end)
        return
    end
    for _, tt in ipairs({ GameTooltip, _G.ItemRefTooltip }) do
        if tt and tt.HookScript then
            tt:HookScript("OnTooltipSetItem", function(self)
                local _, link = self:GetItem()
                addTooltip(self, link)
            end)
        end
    end
end

-- Recorder ------------------------------------------------------------------

local pending = { item = nil, itemAt = 0, castAt = nil }

-- The item clicked while Disenchant was waiting for a target.
local function onUseContainerItem(bag, slot)
    if not Compat.Call("SpellIsTargeting") then return end
    local link = Compat.Call("C_Container.GetContainerItemLink", bag, slot)
    if link then pending.item, pending.itemAt = link, GetTime() end
end

local function onCastSucceeded(_, unit, _, spellID)
    if unit ~= "player" or spellID ~= Disenchant.SPELL then return end
    pending.castAt = GetTime()
end

local function itemFromLootSource()
    local n = Compat.Call("GetNumLootItems") or 0
    for slot = 1, n do
        local guid = Compat.Call("GetLootSourceInfo", slot)
        if type(guid) == "string" and guid:find("^Item") then
            local link = Compat.Call("C_Item.GetItemLinkByGUID", guid)
            if link then return link end
        end
    end
    return nil
end

local function onLootOpened()
    if not pending.castAt or GetTime() - pending.castAt > 5 then return end
    pending.castAt = nil
    local item = (pending.item and GetTime() - pending.itemAt < 30) and pending.item or itemFromLootSource()
    pending.item = nil
    if not item then
        ns.Debug("disenchant: couldn't tell which item was disenchanted")
        return
    end
    local classID, quality, itemLevel, detailed = itemFacts(item)
    local band = Disenchant.Band(ns.DisenchantBands, classID, quality, itemLevel)
    if not band then
        ns.Debug("disenchant: no Forever band for", item, classID, quality, itemLevel)
        return
    end
    if detailed then
        ns.db.disenchantLevels = ns.db.disenchantLevels or {}
        ns.db.disenchantLevels[itemIDOf(item) or 0] = { base = itemLevel, detailed = detailed }
    end
    local loot = {}
    for slot = 1, Compat.Call("GetNumLootItems") or 0 do
        local link = Compat.Call("GetLootSlotLink", slot)
        local id = link and tonumber(link:match("item:(%d+)"))
        local _, _, count = Compat.Call("GetLootSlotInfo", slot)
        if id then loot[id] = (loot[id] or 0) + (tonumber(count) or 1) end
    end
    if not next(loot) then return end
    Disenchant.Record(ns.db.disenchants, band[7], loot, tonumber(tostring(item):match("item:(%d+)")) or tonumber(item), itemLevel)
    Disenchant.Invalidate()
    if ns.Net and ns.Net.Disenchanted then ns.Net.Disenchanted() end
    ns.Debug("disenchant recorded: band", band[7], item, "ilvl", itemLevel)
end

function Disenchant.Start()
    hookTooltips()
    if C_Container and C_Container.UseContainerItem then
        hooksecurefunc(C_Container, "UseContainerItem", onUseContainerItem)
    end
    ns.On("UNIT_SPELLCAST_SUCCEEDED", onCastSucceeded)
    ns.On("LOOT_OPENED", onLootOpened)
end

-- "/tb de": what was recorded, per band.
function Disenchant.PrintSummary()
    local records = ns.db.disenchants or {}
    local quality = { [2] = L.DE_GREEN, [3] = L.DE_BLUE, [4] = L.DE_PURPLE }
    local any = false
    for _, b in ipairs(ns.DisenchantBands or {}) do
        local rec = records[b[7]]
        if rec and rec.n > 0 then
            any = true
            local parts = {}
            for _, r in ipairs(Disenchant.Seen(rec)) do
                parts[#parts + 1] = ("%s x%s %d%%"):format(Compat.ItemInfo(r[1]) or r[1],
                    r[3] == r[4] and r[3] or (r[3] .. "-" .. r[4]), math.floor(r[2] * 100 + 0.5))
            end
            ns.Print(L.DE_SUMMARY_LINE:format(quality[b[2]] or b[2], b[1] == 2 and L.DE_WEAPON or L.DE_ARMOR,
                b[3], b[4], rec.n, table.concat(parts, ", ")))
        end
    end
    if not any then ns.Print(L.DE_SUMMARY_NONE) end
end
