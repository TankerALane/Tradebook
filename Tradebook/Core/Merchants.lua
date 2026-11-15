-- Core/Merchants.lua
-- Learns which vendor sells which recipe, from the vendor's window itself. Vendor stock lives
-- on the server, so what you see when you open a vendor is the best evidence there is: it
-- confirms (or questions) the bundled data in Data/RecipeVendors.lua, and shows which recipes
-- are limited supply (the game reports how many are left; unlimited items report -1).
-- Saved account-wide in TradebookDB.vendors[npcID]:
--   { name, seenAt, recipes = { [recipeID] = stock } (last visit; -1 unlimited),
--     ever = { [recipeID] = true } (seen selling it on any visit),
--     limited = { [recipeID] = true } (seen with limited stock on any visit),
--     prices = { [recipeID] = copper } (gold price on the last visit it was listed, with your
--       reputation discount; not for recipes bought with Merchant's Favor or other tokens),
--     items = { [itemID] = { n = name, p = gold price, s = stock (-1 unlimited),
--       c = "currency:3402:60;item:1234:2" token / currency cost } } (everything it sells, last visit),
--     loc = { m = uiMapID, x, y (0-100), z = zone name, c = continent, wx, wy (world yards) } }
-- Every vendor you open is saved, so the search can find any item a scanned vendor sells.
-- A limited recipe that's sold out may be missing from the window until it restocks, so a
-- missing recipe never removes a vendor: it's shown as "not in stock when you visited".

local _, ns = ...
local Compat = ns.Compat

local Merchants = {}
ns.Merchants = Merchants

local function npcID()
    local guid = Compat.Call("UnitGUID", "npc")
    if not guid or Compat.IsSecret(guid) then return nil end
    local id = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    return tonumber(id)
end

-- PURE. Merge one visit into a saved vendor entry (or a new one). seen = { [recipeID] = stock },
-- prices = { [recipeID] = copper } (optional).
function Merchants.Merge(entry, name, seen, now, prices)
    entry = entry or { ever = {}, limited = {} }
    entry.name = name or entry.name
    entry.seenAt = now
    entry.recipes = seen
    entry.ever = entry.ever or {}
    entry.limited = entry.limited or {}
    entry.prices = entry.prices or {}
    for recipeID, copper in pairs(prices or {}) do entry.prices[recipeID] = copper end
    for recipeID, stock in pairs(seen) do
        entry.ever[recipeID] = true
        if stock >= 0 then entry.limited[recipeID] = true end
    end
    return entry
end

-- One item's stock (numAvailable, -1 unlimited), gold price (nil when it costs only tokens or
-- currency such as Merchant's Favor) and name, from the modern or the classic API.
local function stockOf(i)
    local info = Compat.Call("C_MerchantFrame.GetItemInfo", i)
    if type(info) == "table" then
        local gold = info.price and info.price > 0 and info.price or nil
        return info.numAvailable, (not info.hasExtendedCost) and gold or nil, info.name, gold
    end
    local name, _, price, _, numAvailable, _, _, extendedCost = Compat.Call("GetMerchantItemInfo", i)
    local gold = price and price > 0 and price or nil
    return numAvailable, (not extendedCost) and gold or nil, name, gold
end

-- Token / currency cost of an item ("currency:3402:60;item:1234:2"), or nil.
local function costOf(i)
    local n = Compat.Call("GetMerchantItemCostInfo", i) or 0
    local parts = {}
    for j = 1, n do
        local _, value, link, currencyName = Compat.Call("GetMerchantItemCostItem", i, j)
        local kind, cid = (link or ""):match("(%a+):(%d+)")
        if kind and cid and value then
            parts[#parts + 1] = kind .. ":" .. cid .. ":" .. value
        elseif currencyName and value then
            parts[#parts + 1] = "name:" .. currencyName .. ":" .. value
        end
    end
    return #parts > 0 and table.concat(parts, ";") or nil
end

-- Where you're standing (at the vendor): { m, x, y, z, c, wx, wy }, or nil.
local function here()
    local map = Compat.Call("C_Map.GetBestMapForUnit", "player")
    if not map or Compat.IsSecret(map) then return nil end
    local pos = Compat.Call("C_Map.GetPlayerMapPosition", map, "player")
    if not pos then return nil end
    local px, py = pos:GetXY()
    local loc = { m = map, x = math.floor(px * 1000 + 0.5) / 10, y = math.floor(py * 1000 + 0.5) / 10 }
    local info = Compat.Call("C_Map.GetMapInfo", map)
    loc.z = info and info.name
    local continent, world = Compat.Call("C_Map.GetWorldPosFromMapPos", map, pos)
    if continent and world then
        loc.c = continent
        loc.wx, loc.wy = world:GetXY()
    end
    return loc
end
Merchants.Here = here

local function itemIDOf(i)
    local id = Compat.Call("GetMerchantItemID", i)
    if id then return id end
    local link = Compat.Call("GetMerchantItemLink", i)
    return link and tonumber(link:match("item:(%d+)"))
end

local index -- [recipeID] = { [npcID] = entry }, rebuilt after each read

local function read()
    if ns.fake or not ns.db then return end
    local id = npcID()
    if not id then return end
    local count = Compat.Call("GetMerchantNumItems") or 0
    if count == 0 then return end -- not loaded yet; MERCHANT_UPDATE reads again
    local seen, prices, items = {}, {}, {}
    for i = 1, count do
        local itemID = itemIDOf(i)
        if itemID then
            local stock, price, name, anyGold = stockOf(i)
            local cost = costOf(i)
            items[itemID] = { n = name, p = anyGold, s = tonumber(stock) or -1, c = cost }
            local recipeID = ns.RecipeItems and ns.RecipeItems[itemID]
            if recipeID then
                seen[recipeID] = tonumber(stock) or -1
                prices[recipeID] = price
            end
        end
    end
    ns.db.vendors = ns.db.vendors or {}
    local entry = Merchants.Merge(ns.db.vendors[id], Compat.Call("UnitName", "npc"), seen, GetServerTime(), prices)
    entry.items = items
    entry.loc = here() or entry.loc
    ns.db.vendors[id] = entry
    index = nil
    if ns.Net then ns.Net.Scanned("vendor", id) end
    ns.Debug("vendor", id, ns.db.vendors[id].name, "recipes", ns.util.Count(seen))
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

-- What you've seen in vendor windows for a recipe: { [npcID] = { sells = true (on the last
-- visit) | false (missing on the last visit), ever, limited, stock, seenAt, name } }, or nil.
function Merchants.ForRecipe(recipeID)
    if not (ns.db and ns.db.vendors) then return nil end
    if not index then
        index = {}
        for npc, e in pairs(ns.db.vendors) do
            for r in pairs(e.ever or {}) do
                index[r] = index[r] or {}
                index[r][npc] = e
            end
        end
    end
    local out
    for npc, e in pairs(index[recipeID] or {}) do
        out = out or {}
        local stock = e.recipes and e.recipes[recipeID]
        out[npc] = { sells = stock ~= nil, ever = true, limited = e.limited and e.limited[recipeID] == true,
            stock = stock, seenAt = e.seenAt, name = e.name }
    end
    return out
end

-- Has vendor `npc` been visited, and did its last visit list this recipe? nil when never
-- visited; otherwise { sells, ever, limited, seenAt }.
function Merchants.Visit(npc, recipeID)
    local e = ns.db and ns.db.vendors and ns.db.vendors[npc]
    if not e then return nil end
    return { sells = e.recipes and e.recipes[recipeID] ~= nil, ever = e.ever and e.ever[recipeID] == true,
        limited = e.limited and e.limited[recipeID] == true, seenAt = e.seenAt }
end

-- Cheapest gold price you've seen a vendor ask for a recipe (with your reputation discount),
-- and that vendor's name; nil when never seen with a gold price.
function Merchants.Price(recipeID)
    local best, who
    for _, e in pairs(ns.db and ns.db.vendors or {}) do
        local p = e.prices and e.prices[recipeID]
        if p and (not best or p < best) then best, who = p, e.name end
    end
    return best, who
end

-- PURE. Distance in yards between a saved vendor location and a position { c, wx, wy }, or nil
-- (different continent or unknown).
function Merchants.Distance(loc, pos)
    if not (loc and pos and loc.c and pos.c and loc.c == pos.c and loc.wx and pos.wx) then return nil end
    local dx, dy = loc.wx - pos.wx, loc.wy - pos.wy
    return math.sqrt(dx * dx + dy * dy)
end

-- PURE. Search vendor items by name: { { itemID, name, npcID, vendor, price, cost, stock, loc,
-- distance } }, one row per item at its nearest vendor (sorted: nearest first, then name), with
-- the other vendors as `others`. vendors = TradebookDB.vendors; pos = your position or nil.
function Merchants.Search(vendors, text, pos, limit)
    local needle = (text or ""):lower()
    if needle == "" then return {} end
    local byItem = {}
    for npc, e in pairs(vendors or {}) do
        for itemID, it in pairs(e.items or {}) do
            local name = it.n
            if name and name:lower():find(needle, 1, true) then
                local row = { itemID = itemID, name = name, npcID = npc, vendor = e.name, price = it.p,
                    cost = it.c, stock = it.s, loc = e.loc, distance = Merchants.Distance(e.loc, pos), seenAt = e.seenAt }
                local cur = byItem[itemID]
                if not cur then
                    row.others = 0
                    byItem[itemID] = row
                else
                    local better = row.distance and (not cur.distance or row.distance < cur.distance)
                    if better then
                        row.others = cur.others + 1
                        byItem[itemID] = row
                    else
                        cur.others = cur.others + 1
                    end
                end
            end
        end
    end
    local out = {}
    for _, row in pairs(byItem) do out[#out + 1] = row end
    table.sort(out, function(a, b)
        if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
        if a.distance and b.distance and a.distance ~= b.distance then return a.distance < b.distance end
        return a.name < b.name
    end)
    if limit then for i = #out, limit + 1, -1 do out[i] = nil end end
    return out
end

-- "2s 50c" / "60 Merchant's Favor" / both, for a search row { price, cost }.
function Merchants.PriceText(row)
    local parts = {}
    if row.price then parts[#parts + 1] = ns.Prices.Money(row.price) end
    for kind, id, value in (row.cost or ""):gmatch("(%a+):([^:;]+):(%d+)") do
        local name
        if kind == "currency" then
            local info = Compat.Call("C_CurrencyInfo.GetCurrencyInfo", tonumber(id))
            name = info and info.name
        elseif kind == "item" then
            name = Compat.ItemInfo(tonumber(id))
        else
            name = id
        end
        parts[#parts + 1] = value .. " " .. (name or (kind .. " " .. id))
    end
    return table.concat(parts, " + ")
end

function Merchants.Name(npc)
    local e = ns.db and ns.db.vendors and ns.db.vendors[npc]
    return e and e.name
end

-- Vendor reads, for /tb debug: how many vendors, and where they disagree with the bundled data.
function Merchants.DebugLines()
    local lines, vendors = {}, 0
    for npc, e in pairs(ns.db and ns.db.vendors or {}) do
        vendors = vendors + 1
        for recipeID in pairs(e.ever or {}) do
            local conf, unconf = ns.Sources.Vendors(recipeID, true)
            local listed = false
            for _, list in ipairs({ conf, unconf }) do
                for _, v in ipairs(list) do if v == npc then listed = true end end
            end
            if not listed then
                lines[#lines + 1] = ("  %s (%d) sells %d, not in the data"):format(e.name or "?", npc, recipeID)
            end
        end
    end
    table.insert(lines, 1, ("Vendors read: %d"):format(vendors))
    return lines
end

function Merchants.Start()
    ns.On("MERCHANT_SHOW", function() ns.Throttle("merchant", 0.3, read) end)
    ns.On("MERCHANT_UPDATE", function() ns.Throttle("merchant", 0.3, read) end)
end
