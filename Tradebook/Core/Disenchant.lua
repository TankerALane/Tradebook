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
        if itemLevel >= row[1] and itemLevel <= row[2] then return row[3] end
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
-- differs = bool, band } or nil when it can't be disenchanted. records: TradebookDB.disenchants.
function Disenchant.Results(bands, classic, records, classID, quality, itemLevel)
    local band = Disenchant.Band(bands, classID, quality, itemLevel)
    if not band then return nil end
    local record = records and records[band[7]]
    local seen = record and record.n or 0
    local results = Disenchant.Classic(classic, classID, quality, itemLevel)
    local fits = Disenchant.Fits(results, record)
    if seen >= Disenchant.CONFIRM_AT then
        if results and fits then
            return { results = results, source = "confirmed", seen = seen, band = band }
        end
        return { results = Disenchant.Seen(record), source = "seen", seen = seen, band = band }
    end
    if not results then return nil end
    return { results = results, source = "classic", seen = seen, differs = not fits, band = band }
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

-- Class, quality and item level of an item (nil while the game hasn't loaded it).
local function itemFacts(item)
    local name, _, quality, itemLevel, _, _, _, _, _, _, _, classID = Compat.Call("C_Item.GetItemInfo", item)
    if not name then return nil end
    local detailed = type(item) == "string" and Compat.Call("C_Item.GetDetailedItemLevelInfo", item)
    return classID, quality, detailed or itemLevel
end

-- What an item disenchants into (see Disenchant.Results), or nil.
function Disenchant.ForItem(item)
    if not item then return nil end
    local classID, quality, itemLevel = itemFacts(item)
    if not classID then return nil end
    return Disenchant.Results(ns.DisenchantBands, ns.DisenchantClassic, ns.db and ns.db.disenchants,
        classID, quality, itemLevel)
end

-- Auction value of one disenchant after the auction house cut (needs Auctionator), or nil.
function Disenchant.ValueOf(item)
    if not ns.Prices.Available() then return nil end
    local de = Disenchant.ForItem(item)
    if not de then return nil end
    local value = Disenchant.Value(de.results, function(id) return ns.Prices.Get(id).auction end)
    return value and math.floor(value * (1 - ns.Prices.AH_CUT) + 0.5) or nil
end

-- Tooltip lines: { left, right } pairs and plain strings.
function Disenchant.TooltipLines(item)
    local de = Disenchant.ForItem(item)
    if not de then return nil end
    local lines = { ns.W.ColorText(ns.W.GOLD, L.DE_INTO) }
    for _, r in ipairs(de.results) do
        local name = Compat.ItemInfo(r[1]) or ("item:" .. r[1])
        local count = r[3] == r[4] and tostring(r[3]) or (r[3] .. "-" .. r[4])
        lines[#lines + 1] = { "    " .. name .. "  x" .. count, ("%d%%"):format(math.floor(r[2] * 100 + 0.5)) }
    end
    local value = Disenchant.ValueOf(item)
    if value then lines[#lines + 1] = { "    " .. L.DE_VALUE, ns.Prices.Money(value) } end
    lines[#lines + 1] = ns.W.ColorText(ns.W.GREY, "    " .. Disenchant.SourceText(de))
    return lines
end

-- Where a result comes from, for tooltips: confirmed / seen in Forever / classic.
function Disenchant.SourceText(de)
    if de.source == "confirmed" then return L.DE_CONFIRMED:format(de.seen) end
    if de.source == "seen" then return L.DE_SEEN:format(de.seen) end
    if de.differs then return L.DE_CLASSIC_DIFFERS:format(de.seen) end
    return de.seen > 0 and L.DE_CLASSIC_SEEN:format(de.seen) or L.DE_CLASSIC
end

local function addTooltip(tooltip, item)
    if not (ns.db and ns.db.settings.deTooltip ~= false) or not item then return end
    local lines = Disenchant.TooltipLines(item)
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
    local classID, quality, itemLevel = itemFacts(item)
    local band = Disenchant.Band(ns.DisenchantBands, classID, quality, itemLevel)
    if not band then
        ns.Debug("disenchant: no Forever band for", item, classID, quality, itemLevel)
        return
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
