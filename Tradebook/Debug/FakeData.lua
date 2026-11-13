-- Debug/FakeData.lua
-- PURE (the builder). /tb fake swaps in a made-up account for screenshots: four characters
-- with professions, ranks, known recipes, bags and banks, plus made-up Fellowship Ledger
-- friends. Recipe *data* (names, reagents, skill-up ranges) is the real game data, so the
-- pictures show genuine recipes; no real character, bag or friend appears.
--
-- The fake set lives in memory only (never saved; /reload clears it). While it is on, the
-- scanners and crafting do nothing (see ns.fake checks), so nothing real is written.
-- Deterministic (fixed seed) so screenshots are repeatable.

local _, ns = ...

local FakeData = {}
ns.FakeData = FakeData

FakeData.SEED = 20261113
FakeData.SECOND = "Fernhollow" -- every fake character's second name

-- name, class, level, play type, days since seen, professions { skillLine, rank, max }
FakeData.CHARACTERS = {
    { name = "Aldric", class = "PALADIN", level = 34, seen = 0,
        professions = { { 164, 172, 225 }, { 186, 188, 225 }, { 185, 140, 150 }, { 129, 150, 150 } } },
    { name = "Mirelle", class = "MAGE", level = 27, seen = 2,
        professions = { { 197, 131, 150 }, { 333, 118, 150 }, { 185, 75, 75 }, { 356, 92, 150 } } },
    { name = "Thornick", class = "ROGUE", level = 22, seen = 5,
        professions = { { 165, 98, 150 }, { 393, 120, 150 }, { 129, 75, 75 } } },
    { name = "Sefaria", class = "PRIEST", level = 18, seen = 41, -- stale (shows the warning)
        professions = { { 171, 66, 75 }, { 182, 74, 75 }, { 185, 30, 75 } } },
}

FakeData.FRIENDS = {
    { name = "Grimwald Ashby", class = "WARRIOR", profs = { [164] = { 205, 225 }, [186] = { 210, 225 } } },
    { name = "Vexa Moonrill", class = "DRUID", profs = { [171] = { 178, 225 }, [182] = { 190, 225 } } },
    { name = "Brask Ironvein", class = "SHAMAN", profs = { [202] = { 140, 150 }, [186] = { 150, 150 } } },
    { name = "Okka Thistle", class = "HUNTER", profs = { [165] = { 160, 225 }, [393] = { 175, 225 }, [185] = { 90, 150 } } },
    { name = "Lune Varrow", class = "WARLOCK", profs = { [197] = { 220, 225 }, [333] = { 200, 225 } } },
}

local function newRng(seed)
    local state = seed % 2147483647
    if state <= 0 then state = state + 2147483646 end
    local rng = {}
    function rng.float()
        state = (state * 16807) % 2147483647
        return (state - 1) / 2147483646
    end
    function rng.int(lo, hi) return lo + math.floor(rng.float() * (hi - lo + 1)) end
    return rng
end

-- Recipe IDs of a profession a character at `rank` would plausibly know: everything whose
-- yellow point is at or below rank + 25, from the game's own skill-up data.
local function knownRecipes(skillLineID, rank)
    local out = {}
    for id, lv in pairs(ns.RecipeLevels or {}) do
        if lv[1] == skillLineID and lv[2] <= rank + 25 then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end
FakeData.KnownRecipes = knownRecipes

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

-- Build the fake TradebookDB. real: the real DB (recipe cache, categories and settings are
-- copied, so the fake set never changes them). now: current time.
-- ensure(db, recipeID, skillLineID): optional; caches a recipe missing from the copy.
-- Returns db, currentKey.
function FakeData.Build(real, now, ensure)
    local rng = newRng(FakeData.SEED)
    local db = ns.DB.Migrate(nil)
    db.recipes = copy(real.recipes)
    db.categories = copy(real.categories)
    db.campCategories = copy(real.campCategories)
    db.settings = copy(real.settings)
    db.fake = true

    local currentKey
    for i, spec in ipairs(FakeData.CHARACTERS) do
        local key = ns.Characters.Key(spec.name, FakeData.SECOND)
        local c = ns.Characters.Ensure(db, key)
        ns.Characters.UpdateIdentity(c, { name = spec.name, second = FakeData.SECOND, class = spec.class,
            level = spec.level, race = "Human", faction = "Alliance", playType = "normal" },
            now - spec.seen * 86400 - rng.int(0, 3600))
        c.fake = true
        local list = {}
        for _, p in ipairs(spec.professions) do
            local def = ns.Professions.Get(p[1])
            list[#list + 1] = { id = p[1], name = def.name, rank = p[2], max = p[3], primary = def.primary }
        end
        ns.Characters.UpdateProfessions(c, list, now)
        for _, p in ipairs(spec.professions) do
            local learned = {}
            for _, id in ipairs(knownRecipes(p[1], p[2])) do
                if not db.recipes[id] and ensure then ensure(db, id, p[1]) end
                if db.recipes[id] and not db.recipes[id].x then
                    learned[id] = ns.Sources.Difficulty(id, p[2]) or 3
                end
            end
            ns.Characters.SetRecipes(c, p[1], learned, now - spec.seen * 86400)
        end
        -- Bags and bank: some of the reagents their recipes use.
        c.bags, c.bank = {}, {}
        for _, prof in pairs(c.professions) do
            for id in pairs(prof.recipes) do
                local r = db.recipes[id]
                for _, reagent in ipairs(ns.Recipes.Reagents(r)) do
                    if rng.float() < 0.45 then c.bags[reagent.itemID] = rng.int(1, 30) end
                    if rng.float() < 0.25 then c.bank[reagent.itemID] = rng.int(5, 80) end
                end
            end
        end
        if i == 1 then currentKey = key end
    end

    -- A few starred and pinned recipes on the main character.
    local main = db.characters[currentKey]
    local picks = {}
    for id in pairs(main.professions[164] and main.professions[164].recipes or {}) do
        if db.recipes[id] then picks[#picks + 1] = id end
    end
    table.sort(picks)
    for n = 1, math.min(3, #picks) do db.favorites[picks[#picks - n + 1]] = true end
    if picks[1] then db.pinned[picks[1]] = 2 end
    return db, currentKey
end

-- Fake friends in the shape ns.Friends.WithProfession returns.
function FakeData.FriendsWith(skillLineID, now)
    local out = {}
    for i, f in ipairs(FakeData.FRIENDS) do
        local p = f.profs[skillLineID]
        if p then
            out[#out + 1] = { name = f.name, class = f.class, rank = p[1], max = p[2],
                at = now - i * 86400 * 2, friend = f.name }
        end
    end
    table.sort(out, function(a, b) return a.rank > b.rank end)
    return out
end
