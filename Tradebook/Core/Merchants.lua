-- Core/Merchants.lua
-- Learns which vendor sells which recipe, from the vendor's window itself. Vendor stock lives
-- on the server, so what you see when you open a vendor is the best evidence there is: it
-- confirms (or questions) the bundled data in Data/RecipeVendors.lua, and shows which recipes
-- are limited supply (the game reports how many are left; unlimited items report -1).
-- Saved account-wide in TradebookDB.vendors[npcID]:
--   { name, seenAt, recipes = { [recipeID] = stock } (last visit; -1 unlimited),
--     ever = { [recipeID] = true } (seen selling it on any visit),
--     limited = { [recipeID] = true } (seen with limited stock on any visit) }
-- Only vendors that sell a recipe item, or that the bundled data says sell one, are saved.
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

-- NPCs the bundled data names as a vendor of some recipe: { [npcID] = true } (built once).
local dataVendors
local function isDataVendor(id)
    if not dataVendors then
        dataVendors = {}
        for _, o in pairs(ns.RecipeVendors or {}) do
            for _, list in ipairs({ o.v or {}, o.u or {} }) do
                for _, v in ipairs(list) do dataVendors[v] = true end
            end
        end
        for recipeID, s in pairs(ns.SourceData or {}) do
            if s.v and not (ns.RecipeVendors and ns.RecipeVendors[recipeID]) then
                for _, v in ipairs(s.v) do dataVendors[v] = true end
            end
        end
    end
    return dataVendors[id] == true
end

-- PURE. Merge one visit into a saved vendor entry (or a new one). seen = { [recipeID] = stock }.
function Merchants.Merge(entry, name, seen, now)
    entry = entry or { ever = {}, limited = {} }
    entry.name = name or entry.name
    entry.seenAt = now
    entry.recipes = seen
    entry.ever = entry.ever or {}
    entry.limited = entry.limited or {}
    for recipeID, stock in pairs(seen) do
        entry.ever[recipeID] = true
        if stock >= 0 then entry.limited[recipeID] = true end
    end
    return entry
end

-- One item's stock: numAvailable (-1 unlimited), from the modern or the classic API.
local function stockOf(i)
    local info = Compat.Call("C_MerchantFrame.GetItemInfo", i)
    if type(info) == "table" then return info.numAvailable end
    local _, _, _, _, numAvailable = Compat.Call("GetMerchantItemInfo", i)
    return numAvailable
end

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
    local seen, any = {}, false
    for i = 1, count do
        local itemID = itemIDOf(i)
        local recipeID = itemID and ns.RecipeItems and ns.RecipeItems[itemID]
        if recipeID then
            seen[recipeID] = tonumber(stockOf(i)) or -1
            any = true
        end
    end
    ns.db.vendors = ns.db.vendors or {}
    if not any and not ns.db.vendors[id] and not isDataVendor(id) then return end
    ns.db.vendors[id] = Merchants.Merge(ns.db.vendors[id], Compat.Call("UnitName", "npc"), seen, GetServerTime())
    index = nil
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
