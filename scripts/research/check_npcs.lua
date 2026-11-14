-- Cross-check every NPC visited (vendors and trainers in a Tradebook SavedVariables file)
-- against the bundled data, for "import npc data".
--   luajit scripts/research/check_npcs.lua <SavedVariables/Tradebook.lua>   (from the repo root)
-- Vendors: recipes in their window vs Data/RecipeVendors.lua (confirmed / new / not in window).
-- Trainers: the highest rank taught vs Data/RankTrainers.lua, and the recipes taught vs the
-- recipe data (trainer recipes, skill needed).
local sv = assert(arg[1], "usage: check_npcs.lua <SavedVariables file>")
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), Compat = {} }
local function load(p) assert(loadfile(p))("Tradebook", ns) end
for _, p in ipairs({ "Tradebook/Data/SourceData.lua", "Tradebook/Data/SkillLevels.lua", "Tradebook/Data/RecipeVendors.lua",
    "Tradebook/Data/RecipeItems.lua", "Tradebook/Data/RankTrainers.lua", "Tradebook/Data/Sources.lua" }) do
    load(p)
end
local env = {}
assert(loadfile(sv, "t", env))()
local db = env.TradebookDB or {}
local RANKS = { "Apprentice", "Journeyman", "Expert", "Artisan" }
local PROF = { [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy", [182] = "Herbalism",
    [185] = "Cooking", [186] = "Mining", [197] = "Tailoring", [202] = "Engineering", [333] = "Enchanting",
    [356] = "Fishing", [393] = "Skinning", [129] = "First Aid" }

local function sorted(t)
    local k = {}
    for key in pairs(t) do k[#k + 1] = key end
    table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
    return k
end

local function recipeName(id)
    local r = db.recipes and db.recipes[id]
    return r and r.n or ("recipe " .. id)
end

-- ---- vendors
local totals = { vendors = 0, vendorRecipes = 0, confirmed = 0, nowConfirmed = 0, new = 0, missing = 0 }
print("VENDORS")
for _, npc in ipairs(sorted(db.vendors or {})) do
    local e = db.vendors[npc]
    totals.vendors = totals.vendors + 1
    local notes = {}
    local seen = 0
    for recipeID in pairs(e.recipes or {}) do
        seen = seen + 1
        local conf, unconf = ns.Sources.Vendors(recipeID, true)
        local isConf, isUnconf = false, false
        for _, v in ipairs(conf) do if v == npc then isConf = true end end
        for _, v in ipairs(unconf) do if v == npc then isUnconf = true end end
        if isConf then
            totals.confirmed = totals.confirmed + 1
        elseif isUnconf then
            totals.nowConfirmed = totals.nowConfirmed + 1
            notes[#notes + 1] = "    now confirmed: " .. recipeName(recipeID) .. " (" .. recipeID .. ")"
        else
            totals.new = totals.new + 1
            notes[#notes + 1] = "    NEW (not in data): " .. recipeName(recipeID) .. " (" .. recipeID .. ")"
        end
    end
    totals.vendorRecipes = totals.vendorRecipes + seen
    -- recipes the data says this vendor sells, never seen in its window
    for recipeID, o in pairs(ns.RecipeVendors) do
        for _, list in ipairs({ o.v or {}, o.u or {} }) do
            for _, v in ipairs(list) do
                if v == npc and not (e.ever and e.ever[recipeID]) then
                    totals.missing = totals.missing + 1
                    notes[#notes + 1] = "    NOT IN WINDOW: " .. recipeName(recipeID) .. " (" .. recipeID .. ")"
                end
            end
        end
    end
    local items = 0
    for _ in pairs(e.items or {}) do items = items + 1 end
    if #notes > 0 or seen > 0 then
        print(("  %s (%d): %d items, %d recipes%s"):format(e.name or "?", npc, items, seen, e.loc and "" or ", no location"))
        for _, n in ipairs(notes) do print(n) end
    end
end

-- ---- trainers
print("TRAINERS")
local trainerTotals = { trainers = 0, recipes = 0, rankAgrees = 0, rankDiffers = 0, newTrainerForRecipe = 0, skillDiffers = 0 }
for _, npc in ipairs(sorted(db.trainers or {})) do
    local t = db.trainers[npc]
    trainerTotals.trainers = trainerTotals.trainers + 1
    local highest
    for _, line in ipairs(t.services or {}) do
        for i, r in ipairs(RANKS) do
            if line:find("^" .. r .. " %a") and (not highest or i > highest) then highest = i end
        end
    end
    local notes = {}
    -- rank vs the researched list (a trainer is listed under the highest rank it teaches)
    local listedAt
    for i, r in ipairs(RANKS) do
        local list = ns.RankTrainers.For(t.skill, r)
        for _, e in ipairs(list or {}) do
            if e.id == npc or e.name == t.name then listedAt = math.max(listedAt or 0, i) end
        end
    end
    local all = ns.RankTrainers.allRanks[t.skill]
    if highest then
        if all then
            if highest >= 4 then trainerTotals.rankAgrees = trainerTotals.rankAgrees + 1
            else notes[#notes + 1] = "    teaches only up to " .. RANKS[highest] .. " (gathering trainers usually teach all ranks)" end
        elseif listedAt == highest or (not listedAt and highest <= 2 and ns.RankTrainers.journeymanFromAny[t.skill]) then
            trainerTotals.rankAgrees = trainerTotals.rankAgrees + 1
        elseif not listedAt then
            if highest >= 2 then
                trainerTotals.rankDiffers = trainerTotals.rankDiffers + 1
                notes[#notes + 1] = "    NOT IN RANK LIST: teaches " .. RANKS[highest]
            end
        else
            trainerTotals.rankDiffers = trainerTotals.rankDiffers + 1
            notes[#notes + 1] = ("    RANK DIFFERS: listed as %s, teaches up to %s"):format(RANKS[listedAt], RANKS[highest])
        end
    end
    -- recipes: is this trainer in the recipe's trainer list, and is the skill right?
    local recipesByName = {}
    for id, r in pairs(db.recipes or {}) do
        if r.s == t.skill and r.n then recipesByName[r.n] = recipesByName[r.n] or {}; table.insert(recipesByName[r.n], id) end
    end
    local newHere, skillHere = 0, 0
    for _, line in ipairs(t.services or {}) do
        local name, req = line:match("^([^|]*)|[^|]*|[^|]*|[^|]*|([^|]*)|")
        local need = tonumber((req or ""):match("(%d+)%s*$"))
        local isRank = false
        for _, r in ipairs(RANKS) do if name:find("^" .. r .. " %a") then isRank = true end end
        if not isRank then
            for _, id in ipairs(recipesByName[name] or {}) do
                trainerTotals.recipes = trainerTotals.recipes + 1
                local s = ns.SourceData[id]
                local listed = false
                for _, v in ipairs(s and s.t or {}) do if v == npc then listed = true end end
                if not listed then newHere = newHere + 1 end
                local data = ns.RecipeRequired and ns.RecipeRequired[id]
                if need and data and data[1] ~= need then
                    skillHere = skillHere + 1
                    if skillHere <= 3 then
                        notes[#notes + 1] = ("    skill differs: %s needs %d (data said %d)"):format(name, need, data[1])
                    end
                end
            end
        end
    end
    trainerTotals.newTrainerForRecipe = trainerTotals.newTrainerForRecipe + newHere
    trainerTotals.skillDiffers = trainerTotals.skillDiffers + skillHere
    print(("  %s (%d) %s: up to %s, %d services%s%s%s"):format(t.name or "?", npc, PROF[t.skill] or tostring(t.skill),
        highest and RANKS[highest] or "?", #(t.services or {}), t.loc and "" or ", no location",
        newHere > 0 and (", trainer newly known for " .. newHere .. " recipes") or "",
        skillHere > 0 and (", " .. skillHere .. " skill values corrected") or ""))
    for _, n in ipairs(notes) do print(n) end
end

print(("SUMMARY vendors %d (recipes %d: confirmed %d, now confirmed %d, new %d, data lists but not in window %d)"):format(
    totals.vendors, totals.vendorRecipes, totals.confirmed, totals.nowConfirmed, totals.new, totals.missing))
print(("SUMMARY trainers %d (rank agrees %d, differs %d; recipes taught %d, trainer new for a recipe %d, skill corrected %d)"):format(
    trainerTotals.trainers, trainerTotals.rankAgrees, trainerTotals.rankDiffers, trainerTotals.recipes,
    trainerTotals.newTrainerForRecipe, trainerTotals.skillDiffers))
