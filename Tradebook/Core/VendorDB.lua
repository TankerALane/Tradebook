-- Core/VendorDB.lua
-- The vendor database behind the Vendors tab: which vendors sell an item, where they are, and
-- what they ask. Four sources, best first:
--   scanned    vendors you opened (TradebookDB.vendors, Core/Merchants.lua): real prices (with
--              your reputation discount), Merchant's Favor / token costs, stock, location;
--   community  vendors other players scanned and shared with /tb share, merged into
--              Data/CommunityVendors.lua for each release (same fields);
--   players    vendors other Tradebook users shared in game (Core/Net.lua): the report most
--              of them agree with; row.agree = how many players agree (1 = unconfirmed);
--   questie    QuestieDB's vendor lists, read at runtime when Questie is installed (nothing of
--              it is copied); price from the game's own item data (Data/ItemPrices.lua, before
--              reputation discounts).
-- PURE parts take their inputs as arguments so they can be tested outside the game.

local _, ns = ...
local Compat = ns.Compat

local VendorDB = {}
ns.VendorDB = VendorDB

VendorDB.SOURCES = { "scanned", "community", "players", "questie" }

-- PURE. Add the vendors of one saved-vendors table ({ [npcID] = { name, loc, items, seenAt } })
-- to `items` ({ [itemID] = { itemID, name, vendors = { [npcID] = row } } }), as `source`.
-- A vendor already there from a better source is kept.
function VendorDB.AddSaved(items, vendors, source)
    for npc, e in pairs(vendors or {}) do
        for itemID, it in pairs(e.items or {}) do
            local rec = items[itemID]
            if not rec then
                rec = { itemID = itemID, name = it.n, vendors = {} }
                items[itemID] = rec
            end
            rec.name = rec.name or it.n
            if not rec.vendors[npc] then
                rec.vendors[npc] = { npcID = npc, name = e.name, source = source, price = it.p, cost = it.c,
                    stock = it.s, loc = e.loc, seenAt = e.seenAt, priceSeen = it.p ~= nil, agree = e.agree }
            end
        end
    end
    return items
end

-- PURE. Add QuestieDB's vendor lists ({ { itemID, name, vendors = { npcID } } }) with the
-- game's buy price (prices[itemID]).
function VendorDB.AddQuestie(items, index, prices)
    for _, q in ipairs(index or {}) do
        local rec = items[q.itemID]
        if not rec then
            rec = { itemID = q.itemID, name = q.name, vendors = {} }
            items[q.itemID] = rec
        end
        rec.name = rec.name or q.name
        for _, npc in ipairs(q.vendors) do
            if not rec.vendors[npc] and not (ns.NotInForever and ns.NotInForever[npc]) then
                rec.vendors[npc] = { npcID = npc, source = "questie", price = prices and prices[q.itemID],
                    priceSeen = false }
            end
        end
    end
    return items
end

-- Every item with its vendors, from all sources (rebuilt when the data changes).
local cache, cacheKey, cacheAt
local questieIndex
function VendorDB.Items()
    -- Within one frame nothing changes: skip the key check (the recipe list asks per material).
    local now = GetTime and GetTime()
    if cache and now and cacheAt == now then return cache end
    cacheAt = now
    local scanned = ns.db and ns.db.vendors or {}
    -- Scanning a vendor adds one or changes its seenAt: count and sum of seenAt catch both
    -- (numbers, not a string built from every vendor).
    local count, sum = 0, 0
    for _, e in pairs(scanned) do
        count = count + 1
        sum = sum + (tonumber(e.seenAt) or 0)
    end
    local key = count .. ":" .. sum .. ":" .. tostring(questieIndex ~= nil) .. ":"
        .. tostring(ns.Net and ns.Net.Version() or 0)
    if cache and cacheKey == key then return cache end
    local items = {}
    VendorDB.AddSaved(items, scanned, "scanned")
    VendorDB.AddSaved(items, ns.CommunityVendors, "community")
    VendorDB.AddSaved(items, ns.Net and ns.Net.HeardVendors() or {}, "players")
    VendorDB.AddQuestie(items, questieIndex, ns.ItemBuyPrice)
    cache, cacheKey = items, key
    return items
end

-- Load QuestieDB's vendor lists (a batch per frame), then call done(). Safe to call often.
function VendorDB.Load(done)
    if questieIndex or not ns.Questie.Available() then
        if done then done() end
        return
    end
    ns.Questie.VendorItems(function(index)
        questieIndex = index or {}
        cache = nil
        if done then done() end
    end)
end

function VendorDB.QuestieLoaded()
    return questieIndex ~= nil
end

-- Where a vendor row is: fills row.zone, row.distance, row.friendly and a waypoint target.
-- Scanned / community vendors: the saved map position; Questie: its nearest spawn.
local function locate(row, pos)
    if row.loc then
        -- Shared locations only have the map position: work out the world position once.
        if row.loc.m and not row.loc.c and CreateVector2D then
            local c, world = Compat.Call("C_Map.GetWorldPosFromMapPos", row.loc.m, CreateVector2D(row.loc.x / 100, row.loc.y / 100))
            if c and world then row.loc.c, row.loc.wx, row.loc.wy = c, world:GetXY() end
            if not row.loc.z then
                local info = Compat.Call("C_Map.GetMapInfo", row.loc.m)
                row.loc.z = info and info.name
            end
        end
        row.zone = row.loc.z
        row.distance = ns.Merchants.Distance(row.loc, pos)
        row.friendly = true -- someone opened it
        row.waypoint = row.loc.m and { map = row.loc.m, x = row.loc.x, y = row.loc.y } or nil
        return
    end
    local place = ns.Questie.VendorPlace(row.npcID)
    if place then
        row.name = row.name or place.name
        row.zone = place.zone
        row.distance = place.distance
        row.friendly = place.friendly
        row.waypoint = { areaID = place.areaID, x = place.x, y = place.y }
    end
end

-- PURE. Entries of `pool` whose lower-case name (lowerOf(e)) contains needle; entries whose
-- name isn't known yet are kept too (it may load), so a longer needle can start from this.
function VendorDB.NameMatches(pool, needle, lowerOf)
    if needle == "" then return pool end
    local out = {}
    for _, e in ipairs(pool) do
        local lower = lowerOf(e)
        if not lower or lower:find(needle, 1, true) then out[#out + 1] = e end
    end
    return out
end

-- Typing narrows: "copp" searches only what "cop" matched (any name with "copp" has "cop"),
-- as long as the data is the same. kind = "vendor" | "all".
local lastMatch = {}
local function matches(kind, src, pool, needle, lowerOf)
    local last = lastMatch[kind]
    if needle ~= "" and last and last.src == src and last.needle ~= "" and needle:find(last.needle, 1, true) then
        pool = last.list
    end
    local list = VendorDB.NameMatches(pool, needle, lowerOf)
    lastMatch[kind] = { src = src, needle = needle, list = list }
    return list
end

-- The vendor items as a list (rebuilt with the Items() cache), with lower-case names.
local itemList, itemListOf
local function vendorList(items)
    if itemListOf ~= items then
        itemList, itemListOf = {}, items
        for _, rec in pairs(items) do itemList[#itemList + 1] = rec end
    end
    return itemList
end
local function recLower(rec)
    if not rec.lower then
        local name = rec.name or Compat.ItemInfo(rec.itemID)
        if not name then return nil end
        rec.name, rec.lower = name, name:lower()
    end
    return rec.lower
end
local function entryLower(e)
    e.lower = e.lower or (e.name and e.name:lower())
    return e.lower
end

-- Item type (class) of an item: classID, or nil while unknown.
local function classOf(itemID)
    local _, _, _, _, _, classID = Compat.Call("C_Item.GetItemInfoInstant", itemID)
    return classID
end

-- PURE. Does an item pass the item filters (like the auction house's)?
-- info = { class, quality, level (required level), usable (true/false/nil = unknown yet) };
-- f = { class, quality (at least), minLevel, maxLevel, usable }. Unknown facts don't pass.
function VendorDB.ItemPasses(info, f)
    if f.class and info.class ~= f.class then return false end
    if f.quality and not (info.quality and info.quality >= f.quality) then return false end
    if f.minLevel or f.maxLevel then
        if not info.level then return false end
        if f.minLevel and info.level < f.minLevel then return false end
        if f.maxLevel and info.level > f.maxLevel then return false end
    end
    if f.usable and info.usable ~= true then return false end
    return true
end

-- Can the current character use an item? Like the game's own tooltip: any red line (level,
-- class, armor or weapon skill, profession skill, already known) means no. nil while the item
-- isn't loaded yet (asked for; the list refreshes when it arrives). Without tooltip data,
-- only the required level counts.
local usableCache = {}
local function isRed(c)
    return c and c.r and c.r > 0.9 and c.g < 0.2 and c.b < 0.2
end
function VendorDB.Usable(itemID)
    if usableCache[itemID] ~= nil then return usableCache[itemID] end
    local name, _, _, _, level = Compat.Call("C_Item.GetItemInfo", itemID)
    if not name then
        Compat.Call("C_Item.RequestLoadItemDataByID", itemID)
        return nil
    end
    local usable = true
    if Compat.Has("C_TooltipInfo.GetItemByID") then
        local data = Compat.Call("C_TooltipInfo.GetItemByID", itemID)
        if not (data and data.lines) then return nil end
        for _, line in ipairs(data.lines) do
            if line.args and _G.TooltipUtil and _G.TooltipUtil.SurfaceArgs then _G.TooltipUtil.SurfaceArgs(line) end
            if isRed(line.leftColor) or isRed(line.rightColor) then
                usable = false
                break
            end
        end
    else
        usable = (level or 0) <= (UnitLevel("player") or 0)
    end
    usableCache[itemID] = usable
    return usable
end

-- Forget what was usable (level up, new skill or recipe).
function VendorDB.ForgetUsable() usableCache = {} end

-- The item filter for Search, or nil when no item filter is chosen: passes(itemID).
local function itemFilter(opts)
    if not (opts.class or opts.quality or opts.minLevel or opts.maxLevel or opts.usable) then return nil end
    return function(itemID)
        local info = { class = opts.class and classOf(itemID) }
        if opts.quality or opts.minLevel or opts.maxLevel then
            local name, _, quality, _, level = Compat.Call("C_Item.GetItemInfo", itemID)
            if not name then Compat.Call("C_Item.RequestLoadItemDataByID", itemID) end
            info.quality, info.level = quality, level
        end
        if opts.usable then info.usable = VendorDB.Usable(itemID) end
        return VendorDB.ItemPasses(info, opts)
    end
end

-- PURE. Does a vendor row pass the vendor-level filters?
-- f = { zone, friendlyOnly, thisContinent, payment = "gold"|"tokens", source }
function VendorDB.RowPasses(row, f)
    if f.zone and row.zone ~= f.zone then return false end
    if f.friendlyOnly and row.friendly == false then return false end
    if f.thisContinent and row.distance == nil then return false end
    if f.payment == "gold" and not row.price then return false end
    if f.payment == "tokens" and not row.cost then return false end
    if f.source and row.source ~= f.source then return false end
    return true
end

-- PURE. What one item costs at a vendor row (copper), or nil (tokens only, or unknown).
-- A vendor's window shows the price of one purchase, which for some items is several (stack:
-- 200 arrows, 5 water; Data/ItemPrices.lua VendorStack); Questie rows carry the game's price
-- per item already.
function VendorDB.UnitPrice(row, stack)
    if not row.price then return nil end
    if row.source == "questie" then return row.price end
    return row.price / (stack or 1)
end

-- PURE. The vendor rows that sell an item for less than the auction house (per item, gold
-- only). Empty without an auction price.
function VendorDB.CheaperThanAuction(rows, auction, stack)
    local out = {}
    if not auction then return out end
    for _, row in ipairs(rows) do
        local unit = VendorDB.UnitPrice(row, stack)
        if unit and unit < auction then out[#out + 1] = row end
    end
    return out
end

-- PURE. Items found by name that no vendor (passing the filters) sells, for the auction price:
-- { { itemID, name, vendors = {}, noVendor = "filtered" | "none" } }, by name.
-- all: { { itemID, name } } (every item, Questie.AllItems); vendorItems: VendorDB.Items();
-- filtered: { [itemID] = name } items with vendors that the filters left out;
-- passes(itemID): the item filters (nil = none).
function VendorDB.WithoutVendors(all, vendorItems, filtered, needle, passes)
    local out, seen = {}, {}
    for itemID, name in pairs(filtered or {}) do
        out[#out + 1] = { itemID = itemID, name = name, vendors = {}, noVendor = "filtered" }
        seen[itemID] = true
    end
    for _, e in ipairs(all or {}) do
        if not seen[e.itemID] and not (vendorItems and vendorItems[e.itemID]) then
            e.lower = e.lower or e.name:lower()
            if e.lower:find(needle, 1, true) and (not passes or passes(e.itemID)) then
                out[#out + 1] = { itemID = e.itemID, name = e.name, vendors = {}, noVendor = "none" }
                seen[e.itemID] = true
            end
        end
    end
    table.sort(out, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.itemID < b.itemID
    end)
    return out
end

-- Search: { { itemID, name, classID, vendors = { rows nearest first }, best } }, items sorted
-- by their nearest vendor, then name. opts = { text, zone, friendlyOnly, thisContinent,
-- payment, source, class (classID), quality, minLevel, maxLevel, usable, cheaperVendor, limit }.
-- An empty text lists the vendor items that pass the filters only when a zone, item type,
-- rarity, level or "cheaper at the auction house" is chosen (otherwise nothing: the list would
-- be huge). cheaperVendor: only items a vendor sells for less than the auction price
-- (Auctionator), per item, and only those vendors; results carry auction (per item) and stack.
-- A name search also finds items no vendor sells (Questie's item names; best = nil,
-- noVendor set), after the vendor items, for their auction price. Not with opts.vendorOnly, nor
-- when a zone, payment or source filter is chosen: those ask about vendors.
function VendorDB.Search(opts)
    local needle = (opts.text or ""):lower()
    if needle == "" and not (opts.zone or opts.class or opts.quality or opts.minLevel or opts.maxLevel
        or opts.cheaperVendor) then
        return {}, {}
    end
    local passes = itemFilter(opts)
    local pos = ns.Merchants.Here()
    local out, zones, filtered = {}, {}, {}
    local vendorItems = VendorDB.Items()
    for _, rec in ipairs(matches("vendor", vendorItems, vendorList(vendorItems), needle, recLower)) do
        local itemID, name = rec.itemID, rec.name
        local auction = opts.cheaperVendor and ns.Prices.Auction(itemID)
        if name and recLower(rec) and (not passes or passes(itemID)) and (auction or not opts.cheaperVendor) then
            local rows = {}
            for _, row in pairs(rec.vendors) do
                locate(row, pos)
                if row.zone then zones[row.zone] = true end
                if VendorDB.RowPasses(row, opts) then rows[#rows + 1] = row end
            end
            local stack = ns.VendorStack and ns.VendorStack[itemID]
            -- Only the vendors cheaper than the auction house (none: the item is left out, not
            -- listed as "no vendor passes the filters").
            if opts.cheaperVendor then rows = VendorDB.CheaperThanAuction(rows, auction, stack) end
            if #rows > 0 then
                table.sort(rows, function(a, b)
                    if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
                    if a.distance and b.distance and a.distance ~= b.distance then return a.distance < b.distance end
                    return tostring(a.name) < tostring(b.name)
                end)
                out[#out + 1] = { itemID = itemID, name = name, vendors = rows, best = rows[1],
                    auction = auction or nil, stack = stack }
            elseif needle ~= "" and not opts.cheaperVendor then
                filtered[itemID] = name
            end
        end
    end
    table.sort(out, function(a, b)
        local da, db = a.best.distance, b.best.distance
        if (da ~= nil) ~= (db ~= nil) then return da ~= nil end
        if da and db and da ~= db then return da < db end
        return a.name < b.name
    end)
    if needle ~= "" and not (opts.vendorOnly or opts.zone or opts.payment or opts.source or opts.cheaperVendor) then
        local all = ns.Questie.AllItems()
        local pool = all and matches("all", all, all, needle, entryLower)
        for _, e in ipairs(VendorDB.WithoutVendors(pool, vendorItems, filtered, needle, passes)) do
            out[#out + 1] = e
        end
    end
    if opts.limit then for i = #out, opts.limit + 1, -1 do out[i] = nil end end
    local zoneList = {}
    for z in pairs(zones) do zoneList[#zoneList + 1] = z end
    table.sort(zoneList)
    return out, zoneList
end

-- Does any source know a vendor for this item? (cheap: no positions)
function VendorDB.HasVendors(itemID)
    local rec = itemID and VendorDB.Items()[itemID]
    return rec ~= nil and next(rec.vendors) ~= nil
end

-- The vendors of one item that aren't hostile to you, nearest first (vendors with no known
-- position last): rows as in Search, at most `limit`, and how many there are in all.
function VendorDB.ItemVendors(itemID, limit)
    local rec = itemID and VendorDB.Items()[itemID]
    if not rec then return {}, 0 end
    local pos = ns.Merchants.Here()
    local rows = {}
    for _, row in pairs(rec.vendors) do
        locate(row, pos)
        if row.friendly ~= false then rows[#rows + 1] = row end
    end
    table.sort(rows, function(a, b)
        if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
        if a.distance and b.distance and a.distance ~= b.distance then return a.distance < b.distance end
        return tostring(a.name) < tostring(b.name)
    end)
    local total = #rows
    if limit then for i = #rows, limit + 1, -1 do rows[i] = nil end end
    return rows, total
end

-- Counts for the tab's status line.
function VendorDB.Stats()
    return ns.util.Count(ns.db and ns.db.vendors or {}), ns.util.Count(ns.CommunityVendors or {}),
        questieIndex and #questieIndex or nil, ns.util.Count(ns.Net and ns.Net.HeardVendors() or {})
end
