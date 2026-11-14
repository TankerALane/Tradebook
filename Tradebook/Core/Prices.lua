-- Core/Prices.lua
-- Material prices and craft cost from Auctionator when it is installed (optional dependency).
-- Only Auctionator's public, stable API (Auctionator.API.v1) is used:
--   GetAuctionPriceByItemID / GetAuctionAgeByItemID: last scanned auction price, its age in days
--   GetVendorPriceByItemID: price at a merchant with unlimited stock (recorded when the
--     player visits one), per item
--   ConvertToSearchString / CreateShoppingList: send a shopping list to Auctionator
-- Everything is wrapped in pcall: a missing or changed API never breaks Tradebook.
--
-- The pure parts (Cheapest, CraftCost, Profit, MoneyText) are tested in tests/run.lua.

local _, ns = ...
local L = ns.L

local Prices = {}
ns.Prices = Prices

local CALLER = "Tradebook" -- Auctionator's callerID: the add-on name

local function api()
    local a = _G.Auctionator
    local v1 = type(a) == "table" and type(a.API) == "table" and a.API.v1
    if type(v1) == "table" and type(v1.GetAuctionPriceByItemID) == "function" then return v1 end
    return nil
end

function Prices.Available()
    return api() ~= nil
end

local function call(name, ...)
    local v1 = api()
    local fn = v1 and v1[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, CALLER, ...)
    if ok then return result end
    ns.Debug("Auctionator", name, "failed:", result)
    return nil
end

-- PURE. The vendor price from Forever's item data (Data/VendorPrices.lua), when a vendor sells
-- the item. soldByVendor(itemID) -> bool decides (every item has a buy price in the data).
function Prices.GameVendorPrice(itemID, soldByVendor)
    local p = ns.VendorPrices and ns.VendorPrices[itemID]
    if p and soldByVendor(itemID) then return p end
    return nil
end

-- { auction = copper or nil, vendor = copper or nil, age = days or nil } for one item.
-- vendor: what Auctionator saw at a merchant, else the game's own vendor price for items a
-- vendor sells (QuestieDB), so thread, dyes, vials and spices have a price without a visit.
function Prices.Get(itemID)
    if not itemID then return {} end
    local auction = api() and call("GetAuctionPriceByItemID", itemID)
    local vendor = api() and call("GetVendorPriceByItemID", itemID)
    auction = type(auction) == "number" and auction > 0 and auction or nil
    vendor = type(vendor) == "number" and vendor > 0 and vendor or nil
    if not vendor then vendor = Prices.GameVendorPrice(itemID, ns.Questie.SoldByVendor) end
    return { auction = auction, vendor = vendor, age = auction and call("GetAuctionAgeByItemID", itemID) or nil }
end

-- PURE. The cheaper way to buy one: copper, "vendor" | "auction"; nil when neither is known.
function Prices.Cheapest(p)
    if not p then return nil end
    if p.vendor and (not p.auction or p.vendor <= p.auction) then return p.vendor, "vendor" end
    if p.auction then return p.auction, "auction" end
    return nil
end

-- PURE. Cost of a list of materials { { itemID, need } } at the cheapest known price.
-- lookup(itemID) -> { auction, vendor }. Returns total copper (of the priced ones) and how
-- many materials have no price.
function Prices.CraftCost(materials, lookup)
    local total, unpriced = 0, 0
    for _, m in ipairs(materials) do
        local unit = Prices.Cheapest(lookup(m.itemID))
        if unit then total = total + math.floor(unit * m.need + 0.5) else unpriced = unpriced + 1 end
    end
    return total, unpriced
end

-- PURE. What the made items sell for at auction and the profit after cost.
-- Auctionator's price is the buyout; the auction house cut (5%) is taken off.
Prices.AH_CUT = 0.05
function Prices.Profit(cost, auctionUnit, count)
    if not auctionUnit then return nil end
    local value = math.floor(auctionUnit * (count or 1) * (1 - Prices.AH_CUT) + 0.5)
    return value, value - cost
end

-- PURE. Split a shopping list { { itemID, missing, ... } } by where to buy each item, at its
-- cheapest known price: vendor or auction house (no price: auction house, unpriced).
-- lookup(itemID) -> { auction, vendor }. Returns
-- { vendor = { items, total }, auction = { items, total, unpriced } }, each item with
-- unit (copper or nil) and cost (unit * missing, or nil).
function Prices.SplitShopping(list, lookup)
    local out = { vendor = { items = {}, total = 0 }, auction = { items = {}, total = 0, unpriced = 0 } }
    for _, item in ipairs(list) do
        local unit, source = Prices.Cheapest(lookup(item.itemID))
        local group = source == "vendor" and out.vendor or out.auction
        local entry = {}
        for k, v in pairs(item) do entry[k] = v end
        entry.unit = unit
        entry.cost = unit and math.floor(unit * item.missing + 0.5) or nil
        group.items[#group.items + 1] = entry
        if entry.cost then group.total = group.total + entry.cost else out.auction.unpriced = out.auction.unpriced + 1 end
    end
    return out
end

-- PURE fallback money text ("1g 20s 5c"); the game's GetMoneyString is used when present.
function Prices.MoneyText(copper)
    copper = math.floor((copper or 0) + 0.5)
    local negative = copper < 0
    copper = math.abs(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return (negative and "-" or "") .. table.concat(parts, " ")
end

-- Money with coin icons. Negative amounts get a minus sign (GetMoneyString can't show them).
function Prices.Money(copper)
    if not copper then return "" end
    if type(_G.GetMoneyString) ~= "function" then return Prices.MoneyText(copper) end
    local text = _G.GetMoneyString(math.abs(math.floor(copper + 0.5)), true)
    return (copper < 0 and "-" or "") .. text
end

-- Tooltip lines for one material: a "Purchase from:" header with the auction price (and its
-- age) and vendor price indented under it, so they read as buying prices (the item's own
-- tooltip shows what it sells to a vendor for).
local INDENT = "    "
function Prices.TooltipLines(itemID)
    local p = Prices.Get(itemID)
    local lines = {}
    if p.auction then
        local age = p.age and p.age > 0 and (" " .. L.PRICE_AGE:format(p.age)) or ""
        lines[#lines + 1] = { INDENT .. L.PRICE_AUCTION, Prices.Money(p.auction) .. age }
    end
    if p.vendor then lines[#lines + 1] = { INDENT .. L.PRICE_VENDOR, Prices.Money(p.vendor) } end
    if #lines == 0 then return { L.PRICE_NONE } end
    table.insert(lines, 1, ns.W.ColorText(ns.W.GOLD, L.PRICE_PURCHASE_FROM))
    return lines
end

-- Send a shopping list { { itemID, missing } } to Auctionator as a list named `name`
-- (replacing any list with that name). Items whose names haven't loaded are skipped.
-- Returns the number of items sent, or nil when Auctionator's API isn't there.
function Prices.ExportShoppingList(list, name)
    local v1 = api()
    if not (v1 and v1.CreateShoppingList and v1.ConvertToSearchString) then return nil end
    local strings = {}
    for _, item in ipairs(list) do
        local itemName = ns.Compat.ItemInfo(item.itemID)
        if itemName and (item.missing or 0) > 0 then
            local s = call("ConvertToSearchString", { searchString = itemName, isExact = true, quantity = item.missing })
            if s then strings[#strings + 1] = s end
        end
    end
    if #strings == 0 then return 0 end
    local ok, err = pcall(v1.CreateShoppingList, CALLER, name, strings)
    if not ok then
        ns.Debug("Auctionator CreateShoppingList failed:", err)
        return nil
    end
    return #strings
end

function Prices.DebugState()
    return api() and "Auctionator API v1 found" or "Auctionator not loaded"
end
