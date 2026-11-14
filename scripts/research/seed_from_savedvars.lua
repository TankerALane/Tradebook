-- Turn a Tradebook SavedVariables file into /tb share text: vendors and trainers (for importing
-- your own scans into the community database, including older scans that only recorded recipes).
--   luajit scripts/research/seed_from_savedvars.lua <Tradebook.lua SavedVariables> > shares.txt
-- Run from the repo root.
local sv = assert(arg[1], "usage: seed_from_savedvars.lua <SavedVariables file>")
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), Compat = {} }
local function load(p) assert(loadfile(p))("Tradebook", ns) end
for _, p in ipairs({ "Tradebook/Data/RecipeItems.lua", "Tradebook/Data/RecipeVendors.lua", "Tradebook/Core/Share.lua" }) do
    load(p)
end
local env = {}
assert(loadfile(sv, "t", env))()
local db = env.TradebookDB or {}
local FAVOR = 3402 -- Merchant's Favor currency

-- recipe -> its first recipe item
local itemOf = {}
for itemID, recipeID in pairs(ns.RecipeItems) do
    if not itemOf[recipeID] or itemID < itemOf[recipeID] then itemOf[recipeID] = itemID end
end

local vendors = {}
for npc, e in pairs(db.vendors or {}) do
    local items = {}
    for itemID, it in pairs(e.items or {}) do items[itemID] = it end
    -- older scans: recipes only
    for recipeID, stock in pairs(e.recipes or {}) do
        local itemID = itemOf[recipeID]
        if itemID and not items[itemID] then
            local o = ns.RecipeVendors[recipeID]
            items[itemID] = { p = e.prices and e.prices[recipeID], s = stock,
                c = o and o.fv and ("currency:%d:%d"):format(FAVOR, o.fv) or nil }
        end
    end
    vendors[npc] = { name = e.name, loc = e.loc, seenAt = e.seenAt, items = items }
end
local text = ns.Share.Encode(vendors, "1.60.1.70938", "seed", db.trainers)
io.write(text, "\n")
