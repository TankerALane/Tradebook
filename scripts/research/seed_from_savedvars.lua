-- Turn a Tradebook SavedVariables file into /tb share text: vendors and trainers (for importing
-- your own scans into the community database, including older scans that only recorded recipes),
-- plus NPC data heard from other players in game (Core/Net.lua).
--   luajit scripts/research/seed_from_savedvars.lua <Tradebook.lua SavedVariables> [--all] > shares.txt
-- Run from the repo root.
-- Heard NPCs: only those at least two players agree on are included, unless --all (then
-- one-player reports too). Your own scan of an NPC always wins. A summary goes to stderr.
-- Players are only known by a hash inside the SavedVariables; nothing about them is written.
local sv = assert(arg[1], "usage: seed_from_savedvars.lua <SavedVariables file> [--all]")
local includeAll = arg[2] == "--all"
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), Compat = {} }
local function load(p) assert(loadfile(p))("Tradebook", ns) end
for _, p in ipairs({ "Tradebook/Data/RecipeItems.lua", "Tradebook/Data/RecipeVendors.lua", "Tradebook/Core/Share.lua",
    "Tradebook/Core/Net.lua" }) do
    load(p)
end
local env = {}
assert(loadfile(sv, "t", env))()
local db = env.TradebookDB or {}
-- Your own characters' scans passed back to you don't count as another player.
ns.Net.ForgetMine(db.heard, db.characters)
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
local trainers = {}
for npc, t in pairs(db.trainers or {}) do trainers[npc] = t end

-- Heard from other players.
local counts = { vendors = { agreed = 0, one = 0, own = 0 }, trainers = { agreed = 0, one = 0, own = 0 } }
local single = {}
local function addHeard(kind, into)
    for npc, e in pairs(ns.Net.BestAll(db.heard, kind)) do
        local c = counts[kind]
        if into[npc] then
            c.own = c.own + 1
        elseif e.agree >= 2 or includeAll then
            into[npc] = e
            if e.agree >= 2 then c.agreed = c.agreed + 1 else c.one = c.one + 1 end
        else
            c.one = c.one + 1
            single[#single + 1] = ("%s %d %s"):format(kind == "vendors" and "vendor" or "trainer", npc, e.name or "?")
        end
    end
end
addHeard("vendors", vendors)
addHeard("trainers", trainers)

local text = ns.Share.Encode(vendors, "1.60.1.70938", "seed", trainers)
-- Other players' "still matches" confirmations of shipped NPCs (one line per NPC, newest date).
local confirms = {}
for kind, list in pairs(db.heard and db.heard.confirms or {}) do
    for npc, by in pairs(list) do
        local newest, n = 0, 0
        for _, at in pairs(by) do
            n = n + 1
            if at > newest then newest = at end
        end
        if n > 0 then confirms[#confirms + 1] = ("%s~%d~%d"):format(kind == "vendor" and "C" or "CT", npc, newest) end
    end
end
table.sort(confirms)
if #confirms > 0 then text = text .. "\n" .. table.concat(confirms, "\n") end
io.write(text, "\n")

local function line(kind)
    local c = counts[kind]
    return ("%s: %d that 2+ players agree on, %d from one player%s, %d you scanned yourself"):format(kind, c.agreed,
        c.one, includeAll and " (included)" or " (left out; --all to include)", c.own)
end
io.stderr:write("Heard in game: ", line("vendors"), "; ", line("trainers"), "; ", #confirms, " confirmations\n")
for _, s in ipairs(single) do io.stderr:write("  one player only: ", s, "\n") end
