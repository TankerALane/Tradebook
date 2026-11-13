-- Core/Reagents.lua
-- PURE. Reagent counts, shortages, shopping lists and the reagent tree.
-- Forever has the CraftFromBankRestricted rule: only bag items can be used to craft,
-- so "usable" counts bags only; bank counts are shown as "fetch first".

local _, ns = ...

local Reagents = {}
ns.Reagents = Reagents

-- Counts for one item for a character (bags, bank; account is always 0 in Forever).
function Reagents.Have(db, character, itemID)
    local bags = character and character.bags and character.bags[itemID] or 0
    local bank = character and character.bank and character.bank[itemID] or 0
    local account = db and db.account and db.account.bank and db.account.bank[itemID] or 0
    return { bags = bags, bank = bank, account = account, total = bags + bank + account }
end

-- How many of an item each OTHER saved character has (bags + bank), from their last
-- login / bank visit. Only characters that have some; hidden characters left out.
-- Returns { { key, name, bags, bank, total } }, most first.
function Reagents.OnOtherCharacters(db, itemID, excludeKey)
    local out = {}
    for key, c in pairs(db.characters) do
        if key ~= excludeKey and not c.hidden then
            local bags = c.bags and c.bags[itemID] or 0
            local bank = c.bank and c.bank[itemID] or 0
            if bags + bank > 0 then
                out[#out + 1] = { key = key, name = c.name or key, class = c.class,
                    bags = bags, bank = bank, total = bags + bank }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.name < b.name
    end)
    return out
end

-- Per-reagent need/have for crafting `times` of a recipe.
-- Returns list of { itemID, need, bags, bank, account, missing, fetch }, and the
-- number of crafts possible from bags alone.
function Reagents.Shortage(db, character, recipe, times)
    times = math.max(1, times or 1)
    local out, possible = {}, nil
    for _, reagent in ipairs(ns.Recipes.Reagents(recipe)) do
        local have = Reagents.Have(db, character, reagent.itemID)
        local need = reagent.count * times
        out[#out + 1] = {
            itemID = reagent.itemID,
            per = reagent.count,
            need = need,
            bags = have.bags,
            bank = have.bank,
            account = have.account,
            missing = math.max(0, need - have.bags),
            -- missing from bags but available in a bank
            fetch = math.min(math.max(0, need - have.bags), have.bank + have.account),
        }
        local can = reagent.count > 0 and math.floor(have.bags / reagent.count) or math.huge
        possible = possible and math.min(possible, can) or can
    end
    if possible == math.huge then possible = nil end
    return out, possible or 0
end

-- Combined shopping list for several recipes.
-- entries: { { recipeID, times } ... }. Returns sorted list of
-- { itemID, need, bags, bank, account, missing } for items still missing from bags.
function Reagents.ShoppingList(db, character, entries)
    local need = {}
    for _, e in ipairs(entries) do
        local recipe = db.recipes[e.recipeID]
        for _, reagent in ipairs(ns.Recipes.Reagents(recipe)) do
            need[reagent.itemID] = (need[reagent.itemID] or 0) + reagent.count * math.max(1, e.times or 1)
        end
    end
    local out = {}
    for itemID, n in pairs(need) do
        local have = Reagents.Have(db, character, itemID)
        local missing = math.max(0, n - have.bags)
        if missing > 0 then
            out[#out + 1] = { itemID = itemID, need = n, bags = have.bags, bank = have.bank,
                account = have.account, missing = missing }
        end
    end
    table.sort(out, function(a, b)
        if a.missing ~= b.missing then return a.missing > b.missing end
        return a.itemID < b.itemID
    end)
    return out
end

-- Reagent tree: each reagent with the recipes (from any profession) that make it.
-- Returns { { itemID, count, makers = { { recipeID, skillLineID, children = {...} } } } }.
-- Depth-limited and cycle-safe.
function Reagents.Tree(db, recipeID, maxDepth, seen)
    maxDepth = maxDepth or 3
    seen = seen or {}
    if maxDepth <= 0 or seen[recipeID] then return {} end
    seen[recipeID] = true
    local out = {}
    for _, reagent in ipairs(ns.Recipes.Reagents(db.recipes[recipeID])) do
        local node = { itemID = reagent.itemID, count = reagent.count, makers = {} }
        for _, makerID in ipairs(ns.Recipes.ProducedBy(db, reagent.itemID)) do
            local maker = db.recipes[makerID]
            if not seen[makerID] and maker and not maker.x then
                node.makers[#node.makers + 1] = {
                    recipeID = makerID,
                    skillLineID = maker.s,
                    children = Reagents.Tree(db, makerID, maxDepth - 1, seen),
                }
            end
        end
        out[#out + 1] = node
    end
    seen[recipeID] = nil
    return out
end
