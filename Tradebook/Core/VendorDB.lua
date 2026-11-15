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
local cache, cacheKey
local questieIndex
function VendorDB.Items()
    local scanned = ns.db and ns.db.vendors or {}
    local key = tostring(ns.util.Count(scanned)) .. ":" .. tostring(questieIndex ~= nil) .. ":"
        .. tostring(ns.Net and ns.Net.Version() or 0)
    for _, e in pairs(scanned) do key = key .. ":" .. tostring(e.seenAt) end
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

-- Item type (class) of an item: classID, or nil while unknown.
local function classOf(itemID)
    local _, _, _, _, _, classID = Compat.Call("C_Item.GetItemInfoInstant", itemID)
    return classID
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

-- Search: { { itemID, name, classID, vendors = { rows nearest first }, best } }, items sorted
-- by their nearest vendor, then name. opts = { text, zone, friendlyOnly, thisContinent,
-- payment, source, class (classID), limit }. An empty text lists everything that passes the
-- filters only when a zone is chosen (otherwise nothing: the list would be huge).
function VendorDB.Search(opts)
    local needle = (opts.text or ""):lower()
    if needle == "" and not opts.zone then return {}, {} end
    local pos = ns.Merchants.Here()
    local out, zones = {}, {}
    for itemID, rec in pairs(VendorDB.Items()) do
        local name = rec.name or Compat.ItemInfo(itemID)
        if name and (needle == "" or name:lower():find(needle, 1, true))
            and (not opts.class or classOf(itemID) == opts.class) then
            local rows = {}
            for _, row in pairs(rec.vendors) do
                locate(row, pos)
                if row.zone then zones[row.zone] = true end
                if VendorDB.RowPasses(row, opts) then rows[#rows + 1] = row end
            end
            if #rows > 0 then
                table.sort(rows, function(a, b)
                    if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
                    if a.distance and b.distance and a.distance ~= b.distance then return a.distance < b.distance end
                    return tostring(a.name) < tostring(b.name)
                end)
                out[#out + 1] = { itemID = itemID, name = name, vendors = rows, best = rows[1] }
            end
        end
    end
    table.sort(out, function(a, b)
        local da, db = a.best.distance, b.best.distance
        if (da ~= nil) ~= (db ~= nil) then return da ~= nil end
        if da and db and da ~= db then return da < db end
        return a.name < b.name
    end)
    if opts.limit then for i = #out, opts.limit + 1, -1 do out[i] = nil end end
    local zoneList = {}
    for z in pairs(zones) do zoneList[#zoneList + 1] = z end
    table.sort(zoneList)
    return out, zoneList
end

-- Counts for the tab's status line.
function VendorDB.Stats()
    return ns.util.Count(ns.db and ns.db.vendors or {}), ns.util.Count(ns.CommunityVendors or {}),
        questieIndex and #questieIndex or nil, ns.util.Count(ns.Net and ns.Net.HeardVendors() or {})
end
