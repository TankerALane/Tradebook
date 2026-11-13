-- Core/Recipes.lua
-- PURE. Shared recipe cache plus the account-wide queries built on it:
-- "who can craft this?", recipe search, missing recipes, camp recipes.
--
-- db.recipes[recipeID] = {
--   s = skillLineID, n = name, c = categoryID, o = outputItemID, i = icon,
--   q1 = quantityMin, q2 = quantityMax, r = { itemID, count, itemID, count, ... },
--   camp = true|nil, x = true|nil (outside the profession's own categories, e.g. Season of Discovery),
--   t = maxTrivialLevel,
-- }

local _, ns = ...
local util = ns.util

local Recipes = {}
ns.Recipes = Recipes

-- Store or refresh one recipe in the cache.
function Recipes.Store(db, recipeID, data)
    local r = db.recipes[recipeID] or {}
    for k, v in pairs(data) do r[k] = v end
    db.recipes[recipeID] = r
    Recipes.Invalidate()
    return r
end

-- Reagents as a list of { itemID, count }.
function Recipes.Reagents(recipe)
    local out = {}
    local r = recipe and recipe.r
    if not r then return out end
    for i = 1, #r, 2 do out[#out + 1] = { itemID = r[i], count = r[i + 1] } end
    return out
end

function Recipes.PackReagents(list)
    local r = {}
    for _, item in ipairs(list) do
        r[#r + 1] = item.itemID
        r[#r + 1] = item.count
    end
    return r
end

-- Is this recipe shown by default? Excludes Season of Discovery style extras.
function Recipes.IsVisible(recipe, showExtras)
    return recipe ~= nil and (showExtras or not recipe.x)
end

---------------------------------------------------------------------------
-- indexes (rebuilt lazily when the cache or characters change)
---------------------------------------------------------------------------

local index -- { byName = { {id, lname} ... }, byOutput = { [itemID] = {recipeID...} }, knownBy = {[recipeID] = {keys}} }

function Recipes.Invalidate()
    index = nil
end

local function build(db)
    index = { byName = {}, byOutput = {}, knownBy = {} }
    for id, r in pairs(db.recipes) do
        if r.n then index.byName[#index.byName + 1] = { id = id, lname = r.n:lower() } end
        if r.o then
            index.byOutput[r.o] = index.byOutput[r.o] or {}
            table.insert(index.byOutput[r.o], id)
        end
    end
    table.sort(index.byName, function(a, b) return a.lname < b.lname end)
    for key, c in pairs(db.characters) do
        for _, p in pairs(c.professions or {}) do
            for id in pairs(p.recipes or {}) do
                index.knownBy[id] = index.knownBy[id] or {}
                table.insert(index.knownBy[id], key)
            end
        end
    end
    for _, keys in pairs(index.knownBy) do table.sort(keys) end
    return index
end

local function getIndex(db)
    return index or build(db)
end

-- Keys of every saved character that knows the recipe (hidden ones excluded unless asked).
function Recipes.KnownBy(db, recipeID, includeHidden)
    local out = {}
    for _, key in ipairs(getIndex(db).knownBy[recipeID] or {}) do
        local c = db.characters[key]
        if c and (includeHidden or not c.hidden) then out[#out + 1] = key end
    end
    return out
end

-- Recipes that produce an item (for the reagent tree).
function Recipes.ProducedBy(db, itemID)
    return getIndex(db).byOutput[itemID] or {}
end

-- "Who can craft this?": search recipe names across the whole cache.
-- Returns { { id, recipe, crafters = {keys} } ... }, crafters first, then by name.
-- opts: limit, onlyKnown, skillLineID, showExtras, nameOf(itemID) for reagent names (unused if nil)
function Recipes.Search(db, query, opts)
    opts = opts or {}
    local q = util.Query(query)
    if not q then return {} end
    local out = {}
    for _, entry in ipairs(getIndex(db).byName) do
        if entry.lname:find(q, 1, true) then
            local r = db.recipes[entry.id]
            if Recipes.IsVisible(r, opts.showExtras) and (not opts.skillLineID or r.s == opts.skillLineID) then
                local crafters = Recipes.KnownBy(db, entry.id)
                if #crafters > 0 or not opts.onlyKnown then
                    out[#out + 1] = { id = entry.id, recipe = r, crafters = crafters }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        local ka, kb = #a.crafters > 0, #b.crafters > 0
        if ka ~= kb then return ka end
        local sa, sb = a.recipe.n:lower():find(q, 1, true) == 1, b.recipe.n:lower():find(q, 1, true) == 1
        if sa ~= sb then return sa end
        return a.recipe.n < b.recipe.n
    end)
    if opts.limit and #out > opts.limit then
        for i = #out, opts.limit + 1, -1 do out[i] = nil end
    end
    return out
end

-- All cached recipe IDs of a profession, sorted by name.
function Recipes.ForProfession(db, skillLineID, showExtras)
    local out = {}
    for id, r in pairs(db.recipes) do
        if r.s == skillLineID and Recipes.IsVisible(r, showExtras) then out[#out + 1] = id end
    end
    table.sort(out, function(a, b)
        local na, nb = db.recipes[a].n or "", db.recipes[b].n or ""
        if na ~= nb then return na < nb end
        return a < b
    end)
    return out
end

-- Recipes of a profession the character hasn't learned (needs the profession scanned once).
function Recipes.Missing(db, character, skillLineID, showExtras)
    local p = character and character.professions and character.professions[skillLineID]
    if not p or not (p.scannedAt or p.quickAt) then return nil end
    local out = {}
    for _, id in ipairs(Recipes.ForProfession(db, skillLineID, showExtras)) do
        if not p.recipes[id] then out[#out + 1] = id end
    end
    return out
end

-- Every camp recipe in the cache, grouped by profession: { [skillLineID] = {recipeIDs} }.
function Recipes.Camp(db)
    local out = {}
    for id, r in pairs(db.recipes) do
        if r.camp and r.s then
            out[r.s] = out[r.s] or {}
            table.insert(out[r.s], id)
        end
    end
    for _, ids in pairs(out) do
        table.sort(ids, function(a, b) return (db.recipes[a].n or "") < (db.recipes[b].n or "") end)
    end
    return out
end
