-- tests/run.lua
-- Plain-Lua tests for Tradebook's pure data logic. Run from the repo root:
--   luajit tests/run.lua      (or lua5.1 tests/run.lua)
-- Loads the PURE addon files the way WoW does (addonName, ns as varargs); no WoW API needed.

local PURE_FILES = {
    "Tradebook/Core/Namespace.lua",
    "Tradebook/Locales/enUS.lua",
    "Tradebook/Data/Professions.lua",
    "Tradebook/Data/NotInForever.lua",
    "Tradebook/Data/Camp.lua",
    "Tradebook/Data/SourceData.lua",
    "Tradebook/Data/RecipeVendors.lua",
    "Tradebook/Data/RecipeItems.lua",
    "Tradebook/Data/ItemPrices.lua",
    "Tradebook/Data/CommunityVendors.lua",
    "Tradebook/Data/CommunityTrainers.lua",
    "Tradebook/Data/SkillLevels.lua",
    "Tradebook/Data/Sources.lua",
    "Tradebook/Data/RankUps.lua",
    "Tradebook/Data/RankTrainers.lua",
    "Tradebook/Data/Specializations.lua",
    "Tradebook/Core/DB.lua",
    "Tradebook/Core/Characters.lua",
    "Tradebook/Core/Recipes.lua",
    "Tradebook/Core/Reagents.lua",
    "Tradebook/Core/Friends.lua",
    "Tradebook/Core/Locations.lua",
    "Tradebook/Data/DisenchantBands.lua",
    "Tradebook/Data/Disenchant.lua",
    "Tradebook/Data/CommunityDisenchants.lua",
    "Tradebook/Core/Prices.lua",
    "Tradebook/Core/Disenchant.lua",
    "Tradebook/Core/Trainers.lua",
    "Tradebook/Core/Merchants.lua",
    "Tradebook/Core/VendorDB.lua",
    "Tradebook/Core/Share.lua",
    "Tradebook/Core/Net.lua",
    "Tradebook/Core/Planner.lua",
    "Tradebook/Debug/FakeData.lua",
}

local function loadAddon()
    local ns = {}
    for _, path in ipairs(PURE_FILES) do
        local chunk = assert(loadfile(path))
        chunk("Tradebook", ns)
    end
    return ns
end

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

local function eq(actual, expected, msg)
    if actual ~= expected then
        error((msg or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local DAY = 86400
local NOW = 1800000000

-- A small account: two characters, a few recipes.
local function fixture(ns)
    local db = ns.DB.Migrate(nil)
    local R = ns.Recipes
    R.Store(db, 100, { s = 197, n = "Bolt of Linen Cloth", o = 2996, r = { 2589, 2 }, c = 2576 })
    R.Store(db, 101, { s = 197, n = "Linen Bag", o = 4238, r = { 2996, 3, 2320, 3 }, c = 2578 })
    R.Store(db, 102, { s = 197, n = "Frosty Vest", o = 5000, r = { 2996, 1 }, c = 2598, x = true })
    R.Store(db, 103, { s = 197, n = "Spinning Wheel", o = 279943, r = { 4470, 2, 4305, 5 }, c = 2591, camp = true })
    R.Store(db, 200, { s = 185, n = "Basic Campfire", o = 279981, r = { 4470, 1 }, c = 2714, camp = true })
    R.Store(db, 201, { s = 185, n = "Roasted Boar Meat", o = 2888, r = { 769, 1 }, c = 2632 })

    local C = ns.Characters
    local a = C.Ensure(db, "Ana-Forever")
    C.UpdateIdentity(a, { name = "Ana", second = "Forever", class = "MAGE", level = 30, playType = "normal" }, NOW)
    C.UpdateProfessions(a, { { id = 197, rank = 140, max = 150, name = "Tailoring", primary = true } }, NOW)
    C.SetRecipes(a, 197, { [100] = 3, [101] = 2 }, NOW)
    a.bags = { [2589] = 5, [2320] = 10 }
    a.bank = { [2589] = 20 }

    local b = C.Ensure(db, "Bo-Ironside")
    C.UpdateIdentity(b, { name = "Bo", second = "Ironside", class = "WARRIOR", level = 20, playType = "normal" }, NOW - 40 * DAY)
    C.UpdateProfessions(b, {
        { id = 197, rank = 75, max = 75, name = "Tailoring", primary = true },
        { id = 185, rank = 10, max = 75, name = "Cooking", primary = false },
    }, NOW - 40 * DAY)
    C.SetRecipes(b, 197, { [100] = 0, [103] = 1 }, NOW - 40 * DAY)
    C.SetRecipes(b, 185, { [200] = 0 }, NOW - 40 * DAY)
    db.account.bank = { [2320] = 4 }
    R.Invalidate()
    return db, a, b
end

local ns = loadAddon()

---------------------------------------------------------------------------
-- migration
---------------------------------------------------------------------------

test("migrate nil creates defaults", function()
    local db = ns.DB.Migrate(nil)
    eq(db.version, ns.DB.VERSION)
    eq(db.settings.replaceDefault, true)
    eq(db.settings.staleDays, 30)
    eq(type(db.characters), "table")
end)

test("migrate keeps existing data and settings", function()
    local db = ns.DB.Migrate({ version = ns.DB.VERSION, settings = { replaceDefault = false, scale = 1.2 },
        characters = { X = { key = "X" } } })
    eq(db.settings.replaceDefault, false, "setting kept")
    eq(db.settings.scale, 1.2, "scale kept")
    eq(db.settings.staleDays, 30, "missing default filled")
    eq(db.characters.X.key, "X", "character kept")
    eq(db.version, ns.DB.VERSION)
end)

test("migrate leaves newer data alone", function()
    local db = ns.DB.Migrate({ version = ns.DB.VERSION + 5, characters = { Y = {} } })
    eq(db.version, ns.DB.VERSION + 5)
    eq(db.newerVersion, ns.DB.VERSION + 5)
    eq(type(db.characters.Y), "table")
end)

test("migration v2 rescales the window scale (old 1.25 -> new 1.0)", function()
    local db = ns.DB.Migrate({ version = 1, settings = { scale = 1.25 } })
    eq(db.settings.scale, 1)
    eq(db.settings.showGathering, true, "new setting defaulted")
    eq(ns.DB.Migrate({ version = 1, settings = { scale = 1 } }).settings.scale, 0.8)
    eq(ns.DB.Migrate({ version = 2, settings = { scale = 1.25 } }).settings.scale, 1.25, "not applied twice")
end)

test("tab order: crafting, secondary, gathering last", function()
    local list = ns.Professions.list
    eq(#list, 12)
    eq(list[1].name, "Alchemy")
    eq(list[9].name, "Fishing")
    eq(list[10].gathering, true)
    eq(list[11].name, "Mining")
    eq(list[12].noRecipes, true)
    eq(ns.Characters.NextRank(75), "Journeyman")
    eq(ns.Characters.NextRank(225), "Artisan")
    eq(ns.Characters.NextRank(300), nil)
end)

test("migrate is idempotent", function()
    local db = ns.DB.Migrate(ns.DB.Migrate(nil))
    eq(db.version, ns.DB.VERSION)
end)

---------------------------------------------------------------------------
-- characters
---------------------------------------------------------------------------

test("character key and play type", function()
    eq(ns.Characters.Key("Ana", "Forever"), "Ana-Forever")
    eq(ns.Characters.Key("Ana", nil), "Ana")
    eq(ns.Characters.Key(nil, "x"), nil)
    eq(ns.Characters.PlayType(false, false), "normal")
    eq(ns.Characters.PlayType(true, false), "pvp")
    eq(ns.Characters.PlayType(false, true), "rp")
    eq(ns.Characters.PlayType(true, true), "rppvp")
    eq(ns.Characters.PlayType(nil, nil), "unknown")
end)

test("merging professions keeps recipes and drops unlearned professions", function()
    local db, a = fixture(ns)
    ns.Characters.UpdateProfessions(a, { { id = 197, rank = 145, max = 150, name = "Tailoring" },
        { id = 129, rank = 1, max = 75, name = "First Aid" } }, NOW)
    eq(a.professions[197].rank, 145)
    eq(a.professions[197].recipes[100], 3, "recipes kept after rank update")
    eq(a.professions[129].rank, 1)
    ns.Characters.UpdateProfessions(a, { { id = 129, rank = 2, max = 75 } }, NOW)
    eq(a.professions[197], nil, "unlearned profession removed")
    eq(db.characters["Ana-Forever"].professions[129].rank, 2)
end)

test("stale detection", function()
    local _, a, b = fixture(ns)
    eq(ns.Characters.IsStale(a, NOW, 30, "Ana-Forever"), false)
    eq(ns.Characters.IsStale(b, NOW, 30, "Ana-Forever"), true)
    eq(ns.Characters.IsStale(b, NOW, 60, "Ana-Forever"), false, "threshold respected")
    eq(ns.Characters.IsStale(b, NOW, 30, "Bo-Ironside"), false, "current character never stale")
    eq(ns.Characters.DaysSince(b, NOW), 40)
end)

test("list order, hide and delete", function()
    local db, _, b = fixture(ns)
    local list = ns.Characters.List(db, "Bo-Ironside")
    eq(list[1].key, "Bo-Ironside", "current first")
    b.hidden = true
    eq(#ns.Characters.List(db, "Ana-Forever"), 1, "hidden left out")
    eq(#ns.Characters.List(db, "Ana-Forever", true), 2, "hidden included on request")
    eq(ns.Characters.ProfessionCounts(db, "Ana-Forever")[197], 1, "hidden not counted")
    eq(ns.Characters.Delete(db, "Bo-Ironside"), true)
    eq(db.characters["Bo-Ironside"], nil)
    eq(ns.Characters.Delete(db, "Bo-Ironside"), false)
end)

test("profession counts and closest to rank-up", function()
    local db = fixture(ns)
    local counts = ns.Characters.ProfessionCounts(db, "Ana-Forever")
    eq(counts[197], 2)
    eq(counts[185], 1)
    eq(counts[171], nil)
    local c, gap = ns.Characters.ClosestToRankUp(db, 197, "Ana-Forever")
    eq(c.key, "Bo-Ironside", "75/75 is ready to train")
    eq(gap, 0)
end)

---------------------------------------------------------------------------
-- who can craft / search
---------------------------------------------------------------------------

test("who can craft: known by", function()
    local db = fixture(ns)
    local keys = ns.Recipes.KnownBy(db, 100)
    eq(#keys, 2)
    eq(keys[1], "Ana-Forever")
    eq(#ns.Recipes.KnownBy(db, 101), 1)
    eq(#ns.Recipes.KnownBy(db, 201), 0)
end)

test("search finds recipes, crafters first, hides extras", function()
    local db = fixture(ns)
    local res = ns.Recipes.Search(db, "  LINEN ")
    eq(#res, 2)
    eq(res[1].recipe.n, "Linen Bag", "both known; prefix match ranks first")
    eq(res[2].recipe.n, "Bolt of Linen Cloth")
    eq(#res[2].crafters, 2)
    eq(#ns.Recipes.Search(db, "frosty"), 0, "Season of Discovery hidden")
    eq(#ns.Recipes.Search(db, "frosty", { showExtras = true }), 1)
    local roast = ns.Recipes.Search(db, "boar")
    eq(#roast, 1)
    eq(#roast[1].crafters, 0, "nobody knows it")
    eq(#ns.Recipes.Search(db, "boar", { onlyKnown = true }), 0)
    eq(#ns.Recipes.Search(db, ""), 0, "empty query")
    eq(#ns.Recipes.Search(db, "a", { limit = 2 }), 2, "limit")
end)

test("search treats pattern characters literally", function()
    local db = fixture(ns)
    eq(#ns.Recipes.Search(db, "%"), 0)
    eq(#ns.Recipes.Search(db, "("), 0)
end)

test("index refreshes after a new recipe is learned", function()
    local db, a = fixture(ns)
    eq(#ns.Recipes.KnownBy(db, 201), 0)
    ns.Characters.SetRecipes(a, 185, { [201] = 0 }, NOW)
    ns.Recipes.Invalidate()
    eq(#ns.Recipes.KnownBy(db, 201), 1)
end)

test("missing recipes per character", function()
    local db, a, b = fixture(ns)
    local missing = ns.Recipes.Missing(db, a, 197)
    eq(#missing, 1, "Ana misses Spinning Wheel only (SoD hidden)")
    eq(missing[1], 103)
    eq(#ns.Recipes.Missing(db, a, 197, true), 2, "with extras")
    eq(ns.Recipes.Missing(db, a, 185), nil, "profession never scanned")
    eq(#ns.Recipes.Missing(db, b, 185), 1)
end)

test("camp recipes grouped by profession", function()
    local db = fixture(ns)
    local camp = ns.Recipes.Camp(db)
    eq(#camp[197], 1)
    eq(camp[197][1], 103)
    eq(#camp[185], 1)
    -- Same-name campsite recipes (one per faction): one row, the known one.
    db.recipes[901] = { n = db.recipes[103].n, camp = true, s = 197 }
    camp = ns.Recipes.Camp(db)
    eq(#camp[197], 1, "same-name camp recipes shown once")
    eq(camp[197][1], 103, "known version kept")
    eq(ns.Camp.IsCampCategory(2591), true)
    eq(ns.Camp.IsCampCategory(9999, "Camping"), true)
    eq(ns.Camp.IsCampCategory(9999, "Bags", 2714), true, "parent id")
    eq(ns.Camp.IsCampCategory(9999, "Bags", 1, { [1] = 197 }), true, "learned at runtime")
    eq(ns.Camp.IsCampCategory(9999, "Bags"), false)
end)

---------------------------------------------------------------------------
-- reagents
---------------------------------------------------------------------------

test("shortage math uses bags only and flags bank items", function()
    local db, a = fixture(ns)
    local list, possible = ns.Reagents.Shortage(db, a, db.recipes[100], 4) -- needs 8 linen, has 5 in bags, 20 in bank
    eq(#list, 1)
    eq(list[1].need, 8)
    eq(list[1].bags, 5)
    eq(list[1].missing, 3)
    eq(list[1].fetch, 3, "can be fetched from the bank")
    eq(possible, 2, "5 linen / 2 per craft")
end)

test("shortage with nothing", function()
    local db, _, b = fixture(ns)
    local list, possible = ns.Reagents.Shortage(db, b, db.recipes[101], 1)
    eq(possible, 0)
    eq(list[1].missing, 3)
    eq(list[2].account, 4, "account bank counted")
    eq(list[2].fetch, 3)
end)

test("other characters' counts: only those who have it, most first", function()
    local db, a, b = fixture(ns)
    b.bags = { [2589] = 3 }
    b.bank = { [2589] = 30 }
    local list = ns.Reagents.OnOtherCharacters(db, 2589, "Ana-Forever")
    eq(#list, 1, "Ana excluded as the current character")
    eq(list[1].name, "Bo")
    eq(list[1].total, 33)
    eq(list[1].bags, 3)
    eq(#ns.Reagents.OnOtherCharacters(db, 2320, "Ana-Forever"), 0, "Bo has none")
    eq(#ns.Reagents.OnOtherCharacters(db, 2589, "Bo-Ironside"), 1, "Ana has some")
    b.hidden = true
    eq(#ns.Reagents.OnOtherCharacters(db, 2589, "Ana-Forever"), 0, "hidden left out")
    eq(a.bags[2589], 5)
end)

test("shopping list totals across recipes", function()
    local db, a = fixture(ns)
    local list = ns.Reagents.ShoppingList(db, a, {
        { recipeID = 100, times = 2 }, -- 4 linen
        { recipeID = 101, times = 2 }, -- 6 bolts, 6 thread
    })
    -- linen: need 4, have 5 -> fine; bolts 2996: need 6, have 0; thread 2320: need 6, have 10
    eq(#list, 1)
    eq(list[1].itemID, 2996)
    eq(list[1].missing, 6)
    eq(#ns.Reagents.ShoppingList(db, a, {}), 0)
end)

test("reagent tree finds sub-recipes and stops on cycles", function()
    local db = fixture(ns)
    local tree = ns.Reagents.Tree(db, 101)
    eq(#tree, 2)
    eq(tree[1].itemID, 2996)
    eq(#tree[1].makers, 1, "bolt made by Tailoring")
    eq(tree[1].makers[1].recipeID, 100)
    eq(#tree[2].makers, 0)
    ns.Recipes.Store(db, 300, { s = 197, n = "Loop A", o = 1, r = { 2, 1 } })
    ns.Recipes.Store(db, 301, { s = 197, n = "Loop B", o = 2, r = { 1, 1 } })
    local loop = ns.Reagents.Tree(db, 300, 10)
    eq(#loop[1].makers, 1)
    eq(#loop[1].makers[1].children[1].makers, 0, "cycle cut")
    eq(#ns.Reagents.Tree(db, 100, 0), 0, "depth limit")
end)

---------------------------------------------------------------------------
-- bundled source data
---------------------------------------------------------------------------

test("source data loads and resolves", function()
    -- 2385 Brown Linen Vest: trainer recipe, required skill 10, thresholds 1/23/45/70 (borrowed req)
    local lines, borrowed = ns.Sources.Get(2385)
    eq(type(lines), "table")
    eq(lines[1].text, "Trainer")
    eq(lines[1].right, "33 locations")
    eq(borrowed, true)
    local req, reqBorrowed = ns.Sources.Required(2385)
    eq(req, 10)
    eq(reqBorrowed, true)
    eq(ns.Sources.Get(2387)[1].text, ns.L.SOURCE_AUTO, "auto-learned recipe")
    eq(ns.Sources.Get(-1), nil)
end)

test("difficulty from the game's own thresholds", function()
    -- 2385 Brown Linen Vest (SkillLineAbility low 45, high 70): orange 10, yellow 45, green 57, grey 70
    local t = ns.Sources.Thresholds(2385)
    eq(t[1], 45)
    eq(t[2], 57)
    eq(t[3], 70)
    eq(ns.Sources.Difficulty(2385, 44), 0)
    eq(ns.Sources.Difficulty(2385, 45), 1)
    eq(ns.Sources.Difficulty(2385, 57), 2)
    eq(ns.Sources.Difficulty(2385, 70), 3)
    eq(ns.Sources.Difficulty(-1, 10), nil)
end)

test("thresholds agree with colours the game reported", function()
    -- At Tailoring 115 the game showed Gloves of Meditation (3852) orange and
    -- Heavy Woolen Pants (3850) yellow; the old LibProfessionDB rows got both wrong.
    eq(ns.Sources.Difficulty(3852, 115), 0)
    eq(ns.Sources.Thresholds(3852)[1], 125)
    eq(ns.Sources.Difficulty(3850, 115), 1)
    for _, id in ipairs({ 3850, 3866, 3852, 8467, 3848, 3855, 8758, 6690 }) do
        assert(ns.Sources.Thresholds(id), "thresholds present for " .. id)
    end
end)

local function linesText(lines)
    local parts = {}
    for _, l in ipairs(lines) do
        parts[#parts + 1] = ns.L.SKILLUP_COLORS[l.colour + 1]:lower() .. (l.untilSkill and (" until " .. l.untilSkill) or " now")
    end
    return table.concat(parts, " / ")
end

test("skill-up lines: Gloves of Meditation at 115 and other cases", function()
    eq(linesText(ns.Sources.SkillUpLines(3852, 115, 0)), "orange until 125 / yellow until 140 / green until 155")
    eq(linesText(ns.Sources.SkillUpLines(3852, 130, 1)), "yellow until 140 / green until 155")
    eq(linesText(ns.Sources.SkillUpLines(3852, 150, 2)), "green until 155")
    eq(#ns.Sources.SkillUpLines(3852, 155, 3), 0, "grey: no section")
    eq(linesText(ns.Sources.SkillUpLines(3852, 115, nil)), "orange until 125 / yellow until 140 / green until 155",
        "colour worked out from the rank when the game's isn't known")
    eq(linesText(ns.Sources.SkillUpLines(3852, 115, 0, true)), "orange now", "thresholds the game disagreed with")
    eq(linesText(ns.Sources.SkillUpLines(-1, 50, 1)), "yellow now", "no data: game colour only")
    eq(#ns.Sources.SkillUpLines(-1, 50, nil), 0, "nothing known")
    -- Heavy Woolen Pants: yellow from 110, so at 115 the first line is yellow
    eq(linesText(ns.Sources.SkillUpLines(3850, 115, 1)), "yellow until 127 / green until 145")
end)

test("skill-up lines are right for every recipe at every skill 1-300", function()
    local checked = 0
    for id in pairs(ns.RecipeLevels) do
        for rank = 1, 300 do
            local current = ns.Sources.Difficulty(id, rank)
            local lines = ns.Sources.SkillUpLines(id, rank, current)
            if current == nil or current == 3 then
                eq(#lines, 0, "no section when grey/unknown: recipe " .. id .. " rank " .. rank)
            else
                assert(#lines > 0, "missing section: recipe " .. id .. " rank " .. rank)
                eq(lines[1].colour, current, "first line is the current colour: recipe " .. id .. " rank " .. rank)
                local last = rank
                for _, l in ipairs(lines) do
                    assert(l.untilSkill and l.untilSkill > last,
                        "until values rise above the rank: recipe " .. id .. " rank " .. rank)
                    eq(ns.Sources.Difficulty(id, l.untilSkill - 1), l.colour,
                        "colour holds until just before: recipe " .. id .. " rank " .. rank)
                    assert(ns.Sources.Difficulty(id, l.untilSkill) > l.colour,
                        "colour changes at the until value: recipe " .. id .. " rank " .. rank)
                    last = l.untilSkill
                end
                checked = checked + 1
            end
        end
    end
    assert(checked > 100000, "checked " .. checked)
end)

test("friends' professions from Fellowship Ledger data", function()
    local fl = { friends = {
        a = { name = "Sam", characters = {
            ["Grim-Stone"] = { display = "Grim Stone", class = "WARRIOR", lastSeen = 100,
                professions = { ["164"] = { name = "Blacksmithing", rank = 125, max = 150, lastAt = 200 },
                    ["186"] = { name = "Mining", rank = 140, max = 150 } } },
            ["Ivy-Leaf"] = { name = "Ivy", class = "DRUID", professions = { ["182"] = { rank = 60, max = 75 } } },
        } },
        b = { name = "Kim", characters = {
            ["Bolt-Iron"] = { display = "Bolt Iron", class = "ROGUE", professions = { [164] = { rank = 200, max = 225 } } },
            ["Nope-Nope"] = { display = "Nope", professions = "broken" },
        } },
        c = "not a table",
    } }
    local list = ns.Friends.WithProfession(fl, 164)
    eq(#list, 2)
    eq(list[1].name, "Bolt Iron", "highest rank first; numeric keys accepted")
    eq(list[1].rank, 200)
    eq(list[2].name, "Grim Stone")
    eq(list[2].max, 150)
    eq(list[2].at, 200)
    eq(list[2].friend, "Sam")
    eq(#ns.Friends.WithProfession(fl, 171), 0, "nobody has Alchemy")
    eq(#ns.Friends.WithProfession(nil, 164), 0, "Fellowship Ledger not installed")
    eq(#ns.Friends.WithProfession({ friends = 5 }, 164), 0, "unexpected shape")
end)

test("nearest vendors: closest on this continent first, then the rest", function()
    -- toWorld: area 1 and 2 on continent 0 (area 2 offset by 1000 yd), area 3 on continent 1
    local function toWorld(area, x, y)
        if area == 1 then return 0, x * 10, y * 10 end
        if area == 2 then return 0, 1000 + x * 10, y * 10 end
        if area == 3 then return 1, x * 10, y * 10 end
    end
    local here = { continent = 0, x = 500, y = 500 } -- (50, 50) in area 1
    local entries = {
        { id = 1, name = "Far", spawns = { [2] = { { 50, 50 } } } },                -- 1000 yd
        { id = 2, name = "Near", spawns = { [1] = { { 60, 50 }, { 90, 90 } } } },  -- 100 yd (best spawn)
        { id = 3, name = "Other continent", spawns = { [3] = { { 50, 50 } } } },
        { id = 4, name = "No spawns", spawns = {} },
        { id = 5, name = "Bad point", spawns = { [1] = { { -1, -1 } } } },
        { id = 6, name = "Unmapped", spawns = { [99] = { { 10, 10 } } } },
    }
    local list = ns.Locations.Nearest(entries, here, toWorld, 10)
    eq(#list, 4, "entries without valid spawns dropped")
    eq(list[1].name, "Near")
    eq(math.floor(list[1].distance + 0.5), 100)
    eq(list[1].x, 60, "nearest spawn picked")
    eq(list[2].name, "Far")
    eq(list[3].distance, nil, "no distance across continents")
    eq(#ns.Locations.Nearest(entries, here, toWorld, 2), 2, "limit")
    eq(ns.Locations.Nearest(entries, nil, toWorld, 10)[1].name, "Far", "position unknown: by name")
end)

test("faction filter and distance text", function()
    eq(ns.Locations.FriendlyTo("A", "Alliance"), true)
    eq(ns.Locations.FriendlyTo("H", "Alliance"), false)
    eq(ns.Locations.FriendlyTo("AH", "Horde"), true)
    eq(ns.Locations.FriendlyTo(nil, "Horde"), true)
    eq(ns.Locations.DistanceText(119.6), "120 yd")
    eq(ns.Locations.DistanceText(1500), "1.5k yd")
    eq(ns.Locations.DistanceText(nil), nil)
end)

test("fake data: four made-up characters, real data untouched", function()
    local real = ns.DB.Migrate(nil)
    real.recipes[2385] = { s = 197, n = "Brown Linen Vest", r = { 2996, 2 } }
    real.settings.scale = 1.1
    local before = ns.util.Count(real.recipes)
    local ensured = 0
    local db, key = ns.FakeData.Build(real, 1800000000, function(target, id, skill)
        ensured = ensured + 1
        target.recipes[id] = { s = skill, n = "Recipe " .. id, r = { 2589, 1 } }
    end)
    eq(ns.util.Count(db.characters), 4)
    eq(key, "Mirelle-Fernhollow", "Mirelle is the logged-in fake character")
    eq(db.fake, true)
    eq(ns.util.Count(real.characters), 0, "real characters untouched")
    eq(ns.util.Count(real.recipes), before, "real recipe cache untouched")
    assert(ensured > 0, "missing recipes are filled into the fake copy")
    eq(db.settings.scale, 1.1, "scale copied")
    eq(db.settings.filters.unlearned, false, "filters start at defaults")
    local aldric = db.characters["Aldric-Fernhollow"]
    assert(ns.util.Count(aldric.professions[164].recipes) > 10, "Blacksmithing recipes known")
    assert(next(aldric.bags), "bags filled")
    local stale = db.characters["Sefaria-Fernhollow"]
    eq(ns.Characters.IsStale(stale, 1800000000, 30, key), true, "one stale character for the warning")
    local friends = ns.FakeData.FriendsWith(164, 1800000000)
    eq(friends[1].name, "Grimwald Ashby")
    eq(#ns.FakeData.FriendsWith(202, 1800000000), 2, "two Engineering friends for the guide page")
    -- deterministic
    local db2 = ns.FakeData.Build(real, 1800000000, function(target, id, skill)
        target.recipes[id] = { s = skill, n = "Recipe " .. id, r = { 2589, 1 } }
    end)
    eq(ns.util.Count(db2.characters["Aldric-Fernhollow"].bags), ns.util.Count(aldric.bags), "same seed, same data")
end)

test("how a recipe is learned, and learnable now", function()
    -- 2385 Brown Linen Vest: trainer recipe, required 10; 2387: learned with the profession
    local k = ns.Sources.Kinds(2385)
    eq(k.trainer, true)
    eq(k.recipe, false)
    eq(ns.Sources.Kinds(2387).auto, true)
    eq(ns.Sources.Kinds(-1), nil)
    local vendorRecipe
    for id, s in pairs(ns.SourceData) do if s.v and not s.t then vendorRecipe = id break end end
    eq(ns.Sources.Kinds(vendorRecipe).recipe, true, "vendor-sold recipe item")
    -- vendor / drop kinds: Ice Deflector (3957) is sold; a world-drop recipe drops
    eq(ns.Sources.Kinds(3957).vendor, true)
    local dropped
    for id, d in pairs(ns.RecipeDrops) do if d.w then dropped = id break end end
    eq(ns.Sources.Kinds(dropped).drop, true)
    eq(ns.Sources.Kinds(dropped).recipe, true)
    eq(ns.Sources.Learnable(2385, 9), false)
    eq(ns.Sources.Learnable(2385, 10), true)
    eq(ns.Sources.Learnable(2385, nil), nil)
    eq(ns.Sources.Learnable(-1, 100), nil, "unknown required skill")
end)

test("migration v3 clears old threshold mismatches", function()
    local db = ns.DB.Migrate({ version = 2, badThresholds = { [3852] = true } })
    eq(next(db.badThresholds), nil)
end)

test("vendor and drop names are capped with a count", function()
    local found
    for id, s in pairs(ns.SourceData) do
        if s.d and s.dn and s.dn > 3 and not ns.RecipeVendors[id] and not ns.RecipeDrops[id] then found = id break end
    end
    local lines = ns.Sources.Get(found)
    local text
    for _, l in ipairs(lines) do if l.text:find("^Drop") then text = l.text end end
    assert(text and text:find("more%)"), "drop line shows the remaining count: " .. tostring(text))
end)

test("Forever-checked recipe vendors replace the classic ones", function()
    -- 6417 Dig Rat Stew: classic says vendors; in Forever it's a quest reward (862).
    local conf, unconf = ns.Sources.Vendors(6417)
    eq(#conf + #unconf, 0, "no vendor")
    eq(ns.Sources.Raw(6417).q[1], 862)
    eq(ns.Sources.Kinds(6417).recipe, true, "still learned from a recipe item")
    -- 20853 Corehound Boots: one source (Lokhtos Darkbargainer 12944), unconfirmed.
    conf, unconf = ns.Sources.Vendors(20853)
    eq(#conf, 0)
    eq(unconf[1], 12944)
    local lines = ns.Sources.Get(20853)
    local found
    for _, l in ipairs(lines) do if l.text:find("Lokhtos") then found = l.text end end
    assert(found and found:find("unconfirmed"), tostring(found))
    -- 28327 Steam Tonk Controller: seen in Gelvas Grimegate's window (14828), so confirmed.
    conf = ns.Sources.Vendors(28327)
    eq(conf[1], 14828)
    -- 24846 Spitfire Bracers: not in Forever yet, no vendor.
    eq(ns.Sources.Raw(24846).x, 1)
    eq(ns.Sources.Get(24846)[1].text, ns.L.SOURCE_NOT_YET)
    -- 7776 Enchant Chest - Lesser Intellect: Kithas doesn't sell it (seen in game).
    conf, unconf = ns.Sources.Vendors(7776)
    eq(#conf + #unconf, 0)
    eq(ns.Sources.Get(7776)[1].text, ns.L.SOURCE_NO_VENDOR)
    -- 3957 Ice Deflector: adds the Forever vendor Super-Seller 680 (12246), confirmed.
    conf = ns.Sources.Vendors(3957)
    local has = false
    for _, id in ipairs(conf) do if id == 12246 then has = true end end
    eq(has, true)
end)

test("Merchant's Favor recipes: cost, camp reputation by faction, skill", function()
    -- 1254966 Mystic Rugged Armor Kit: Pawani / Daniel Stitchsong, 90 Favor, Honored, skill 235.
    local conf = ns.Sources.Vendors(1254966, true)
    eq(table.concat(conf, ","), "248201,256734")
    local h = ns.Sources.Purchase(1254966, "Horde")
    eq(h.favor, 90)
    eq(h.factionID, 2587, "Durotar Supply and Logistics")
    eq(h.standing, 5, "Honored")
    eq(ns.Sources.Purchase(1254966, "Alliance").factionID, 2586, "Azeroth Commerce Authority")
    eq(ns.Sources.FactionName(2587), "Durotar Supply and Logistics")
    eq(ns.Sources.Required(1254966), 235)
    -- Gnomish Army Knife: QuestieDB said Fizzlefuse; his window (seen in game) doesn't have it.
    local c2, u2 = ns.Sources.Vendors(1266924, true)
    eq(#c2 + #u2, 0)
    -- Plans: Cracked Blacksmith Hammer: seen at Gor'mak, so confirmed (and his Alliance twin).
    eq(table.concat(ns.Sources.Vendors(1317962, true), ","), "248197,256730")
end)

test("deep dive: drops with chances, world drops, not in Forever", function()
    local S = ns.Sources
    -- a recipe with recorded loot counts: chance and sample, highest first
    local withChance
    for id, d in pairs(ns.RecipeDrops) do
        if d.n and d.n[1][4] > 0 and #d.n > 1 then withChance = id break end
    end
    assert(withChance, "some recipe has recorded loot counts")
    local drops = S.Drops(withChance)
    assert(drops[1].chance >= drops[2].chance, "highest chance first")
    assert(drops[1].loots > 0)
    -- a world drop shows its level range
    local world
    for id, d in pairs(ns.RecipeDrops) do if d.w then world = id break end end
    local found
    for _, l in ipairs(S.Get(world)) do if l.text:find("^World drop") then found = true end end
    eq(found, true)
    -- Soul Vessel (431362): a Season of Discovery leftover
    eq(S.Get(431362)[1].text, ns.L.SOURCE_NOT_IN_FOREVER)
    -- a recipe only known from drops counts as learned from a recipe item
    local onlyDrops
    for id in pairs(ns.RecipeDrops) do
        if not ns.SourceData[id] and not ns.RecipeVendors[id] then onlyDrops = id break end
    end
    if onlyDrops then eq(S.Kinds(onlyDrops).recipe, true) end
end)

test("vendor windows: merging visits", function()
    local M = ns.Merchants
    local e = M.Merge(nil, "Kithas", { [7793] = -1, [7776] = 1 }, 100)
    eq(e.ever[7776], true)
    eq(e.limited[7776], true, "stock 1 is limited")
    eq(e.limited[7793], nil, "-1 is unlimited")
    e = M.Merge(e, "Kithas", { [7793] = -1 }, 200)
    eq(e.recipes[7776], nil, "sold out on the second visit")
    eq(e.ever[7776], true, "still seen selling it once")
    eq(e.limited[7776], true)
    eq(e.seenAt, 200)
    -- prices: kept per recipe, updated when listed again
    e = M.Merge(e, "Kithas", { [7793] = -1 }, 300, { [7793] = 450 })
    eq(e.prices[7793], 450)
    e = M.Merge(e, "Kithas", { [7793] = -1 }, 400)
    eq(e.prices[7793], 450, "kept when a visit has no price")
    -- the game's buy price for recipe items (Smoked Sagefish 5s)
    eq(ns.RecipeItemPrice[21099], 500)
end)

test("vendor windows: seen vendors confirm, missing ones are noted", function()
    local S = ns.Sources
    -- 10 confirmed, 20 unconfirmed but seen selling it, 30 seen selling it and not in the data,
    -- 40 unconfirmed and visited without it (never seen selling it).
    local seen = { [20] = { ever = true }, [30] = { ever = true, limited = true } }
    local visits = { [20] = { sells = true, ever = true }, [30] = { sells = true, ever = true, limited = true },
        [40] = { sells = false, ever = false } }
    local conf, unconf, notes = S.MergeSeen({ 10 }, { 20, 40 }, seen, function(npc) return visits[npc] end)
    eq(table.concat(conf, ","), "10,20,30")
    eq(table.concat(unconf, ","), "40")
    eq(notes[30].limited, true)
    eq(notes[40].missing, true)
    eq(notes[10].missing, false, "never visited")
end)

test("vendor items: search finds the nearest vendor that sells it", function()
    local M = ns.Merchants
    local vendors = {
        [1] = { name = "Far Vendor", items = { [159] = { n = "Refreshing Spring Water", p = 25, s = -1 } },
            loc = { m = 1, x = 10, y = 10, c = 1, wx = 1000, wy = 0 } },
        [2] = { name = "Near Vendor", items = { [159] = { n = "Refreshing Spring Water", p = 25, s = -1 },
            [2320] = { n = "Coarse Thread", p = 10, s = -1 } }, loc = { m = 1, x = 50, y = 50, c = 1, wx = 10, wy = 0 } },
        [3] = { name = "Other Continent", items = { [159] = { n = "Refreshing Spring Water", p = 25, s = -1 } },
            loc = { m = 2, x = 1, y = 1, c = 0, wx = 0, wy = 0 } },
    }
    local pos = { c = 1, wx = 0, wy = 0 }
    local rows = M.Search(vendors, "spring", pos)
    eq(#rows, 1, "one row per item")
    eq(rows[1].vendor, "Near Vendor")
    eq(rows[1].others, 2)
    eq(math.floor(rows[1].distance), 10)
    eq(M.Distance(vendors[3].loc, pos), nil, "different continent")
    eq(#M.Search(vendors, "thread", nil), 1, "works without a position")
    eq(#M.Search(vendors, "", pos), 0)
end)

test("vendor database: sources merge, scanned first", function()
    local V = ns.VendorDB
    local items = {}
    V.AddSaved(items, { [10] = { name = "Mine", loc = { m = 1, x = 1, y = 1 }, seenAt = 5,
        items = { [2320] = { n = "Coarse Thread", p = 9, s = -1 } } } }, "scanned")
    V.AddSaved(items, { [10] = { name = "Old", items = { [2320] = { n = "Coarse Thread", p = 10, s = -1 } } },
        [11] = { name = "Theirs", items = { [2320] = { n = "Coarse Thread", p = 10, s = -1 } } } }, "community")
    V.AddQuestie(items, { { itemID = 2320, name = "Coarse Thread", vendors = { 10, 11, 12, 214098 } } }, { [2320] = 10 })
    local rec = items[2320]
    eq(rec.vendors[214098], nil, "an NPC that isn't in Forever is left out")
    eq(rec.vendors[10].source, "scanned")
    eq(rec.vendors[10].price, 9, "your price wins")
    eq(rec.vendors[11].source, "community")
    eq(rec.vendors[12].source, "questie")
    eq(rec.vendors[12].price, 10, "game data price")
    eq(rec.vendors[12].priceSeen, false)
    -- filters
    eq(V.RowPasses({ zone = "Durotar", price = 1 }, { zone = "Barrens" }), false)
    eq(V.RowPasses({ friendly = false }, { friendlyOnly = true }), false)
    eq(V.RowPasses({ cost = "currency:3402:60" }, { payment = "gold" }), false)
    eq(V.RowPasses({ cost = "currency:3402:60" }, { payment = "tokens" }), true)
    eq(V.RowPasses({ source = "questie" }, { source = "scanned" }), false)
end)

test("share text round-trips and keeps nothing personal", function()
    local S = ns.Share
    local vendors = { [248201] = { name = "Pawani", loc = { m = 1413, x = 49.7, y = 29.4 }, seenAt = 100,
        items = { [252941] = { n = "Pattern: Mystic Rugged Armor Kit", s = -1, c = "currency:3402:90" },
            [2320] = { n = "Coarse Thread", p = 10, s = 5 } } },
        [5] = { name = "Empty" } }
    local text, n = S.Encode(vendors, "1.60.1", "v1")
    eq(n, 1, "vendors without items are left out")
    assert(text:find("^TBV1~1.60.1~v1~1"))
    local back = assert(S.Decode(text))
    eq(back[248201].name, "Pawani")
    eq(back[248201].loc.x, 49.7)
    eq(back[248201].items[252941].c, "currency:3402:90")
    eq(back[248201].items[2320].p, 10)
    eq(back[248201].items[2320].s, 5)
    eq(S.Decode("nonsense"), nil)
end)

test("trainers: services, recipes they teach, share round-trip", function()
    local T = ns.Trainers
    local name, skill, cost = T.ParseService("Spiced Wolf Meat||used|0|Cooking 10|45|")
    eq(name, "Spiced Wolf Meat"); eq(skill, 10); eq(cost, 45)
    -- a trainer (yours) teaching a recipe found by name in the recipe cache
    local saved = ns.db
    ns.db = { recipes = { [2539] = { n = "Spiced Wolf Meat", s = 185 } },
        trainers = { [3399] = { name = "Zamja", skill = 185, seenAt = 1,
            services = { "Spiced Wolf Meat||used|0|Cooking 10|50|", "Journeyman Cook||used|0|Cooking 50|500|" } } },
        vendors = {} }
    T.Invalidate()
    local ok, err = pcall(function()
        local by = T.ForRecipe(2539)
        eq(by[3399].cost, 50)
        eq(T.RecipeSkill(2539), 10)
        eq(ns.Sources.Required(2539), 10, "trainer's skill beats the classic data")
        eq(T.Get(3399).name, "Zamja")
        -- share text carries trainers and their services
        local text, nv, nt = ns.Share.Encode({}, "b", "v", ns.db.trainers)
        eq(nv, 0); eq(nt, 1)
        local _, trainers = ns.Share.Decode(text)
        eq(trainers[3399].skill, 185)
        eq(trainers[3399].services[1], "Spiced Wolf Meat||used|0|Cooking 10|50|")
    end)
    ns.db = saved
    T.Invalidate()
    assert(ok, err)
end)

test("share: NPCs that still match are only confirmed", function()
    local S = ns.Share
    local community = { [1] = { name = "A", loc = { m = 1, x = 1, y = 1 }, items = {
        [10] = { p = 100, s = -1 }, [11] = { s = 2 } } } }
    -- same items, 10% cheaper (reputation discount), the limited item sold out: still matches
    local mine = { [1] = { name = "A", seenAt = 50, loc = { m = 1, x = 1, y = 1 }, items = { [10] = { p = 90, s = -1 } } },
        [2] = { name = "B", seenAt = 50, items = { [12] = { p = 5, s = -1 } } } }
    local text, nv, _, stats = S.Encode(mine, "b", "v", nil, { community = community })
    eq(nv, 2)
    eq(stats.confirmed, 1)
    eq(stats.vendors, 1, "only B in full")
    assert(text:find("\nC~1~50"), text)
    local _, _, confirmed = S.Decode(text)
    eq(confirmed[1].npc, 1)
    -- a higher price, a new item, or an unlimited item gone: changed
    eq(S.VendorMatches({ items = { [10] = { p = 120, s = -1 } } }, community[1]), false)
    eq(S.VendorMatches({ items = { [10] = { p = 100, s = -1 }, [99] = { p = 1, s = -1 } } }, community[1]), false)
    eq(S.VendorMatches({ items = { [11] = { s = 1 } } }, community[1]), false, "item 10 (unlimited) missing")
    -- since: only scans after the last share
    local _, n2 = S.Encode(mine, "b", "v", nil, { community = community, since = 60 })
    eq(n2, 0)
    -- trainers
    local ct = { [7] = { services = { "Linen Bag||used|0|Tailoring 5|50|" } } }
    eq(S.TrainerMatches({ services = { "Linen Bag||used|0|Tailoring 5|45|" } }, ct[7]), true, "discount")
    eq(S.TrainerMatches({ services = { "Linen Bag||used|0|Tailoring 5|50|", "Linen Belt||used|0|Tailoring 15|50|" } }, ct[7]), false)
end)

test("recipe items map to the recipe they teach", function()
    eq(ns.RecipeItems[2598], 2389, "Pattern: Red Linen Robe")
    eq(ns.RecipeItems[6346], 7776, "Formula: Enchant Chest - Lesser Intellect")
    eq(ns.RecipeItems[16072], 3413, "Expert Cookbook teaches Expert Cooking")
end)

---------------------------------------------------------------------------
-- rank-ups
---------------------------------------------------------------------------

test("rank-up button shows 25 points before the cap", function()
    local R = ns.RankUps
    eq(R.Ready(197, { rank = 49, max = 75 }), false)
    local ready, nextRank = R.Ready(197, { rank = 50, max = 75 })
    eq(ready, true)
    eq(nextRank.rank, "Journeyman")
    eq(nextRank.level, 10)
    eq(select(2, R.Ready(197, { rank = 130, max = 150 })).level, 20)
    eq(select(2, R.Ready(197, { rank = 200, max = 225 })).level, 35)
    eq(R.Ready(197, { rank = 210, max = 300 }), false, "nothing after Artisan")
    eq(R.Ready(197, nil), false)
    eq(R.Next(185, { max = 75 }).level, nil, "Cooking: no level requirement")
    eq(R.Next(182, { max = 150 }).level, nil, "Herbalism: no level requirement")
    eq(R.Next(197, { max = 150 }).cost, 5000, "Expert base price 50s")
end)

test("rank-up routes: books and quests for the secondary professions", function()
    local R = ns.RankUps
    eq(R.Next(185, { max = 150 }).book, 16072, "Expert Cookbook")
    eq(R.Next(185, { max = 225 }).book, nil, "Artisan Cooking: trainer")
    eq(R.Next(356, { max = 150 }).bookLevel, 20)
    eq(R.Next(356, { max = 225 }).quest, "Nat Pagle, Angler Extreme")
    eq(R.Next(129, { max = 225 }).quest, "Triage")
    eq(R.Next(185, { max = 225 }).quest, "Clamlette Surprise", "Artisan Cooking is a quest")
    eq(R.Next(356, { max = 75 }).level, 10, "Journeyman Fishing needs level 10")
    eq(R.Next(197, { max = 150 }).book, nil, "Tailoring: trainer")
    eq(R.Next(197, { max = 75 }).cost, 500, "Journeyman fee")
    eq(R.Next(197, { max = 225 }).cost, 50000, "Artisan fee")
    eq(R.Next(185, { max = 150 }).cost, nil, "book: no training fee")
    eq(R.Next(185, { max = 150 }).bookPrice, 10000)
end)

test("rank-up requirements are checked against the character", function()
    local nextRank = ns.RankUps.Next(197, { max = 150 })
    local reqs = ns.RankUps.Requirements(nextRank, { rank = 131, max = 150 }, 18)
    eq(reqs[1].ok, true, "skill 131 >= 125")
    eq(reqs[2].ok, false, "level 18 < 20")
    eq(ns.RankUps.Requirements(nextRank, { rank = 131 }, nil)[2].ok, false, "unknown level")
end)

test("could learn: characters with the profession, closest first", function()
    local db = fixture(ns)
    local real = ns.Sources.Required
    ns.Sources.Required = function(id) return ({ [101] = 70, [102] = 145, [103] = 160 })[id] end
    -- 101 (needs 70): Bo (75/75) knows 100 and 103 but not 101 -> learnable now.
    local list = ns.Recipes.CouldLearn(db, 101)
    eq(#list, 1)
    eq(list[1].key, "Bo-Ironside")
    eq(list[1].status, "now")
    -- 102 (needs 145): Ana 140/150 -> 5 more skill; Bo 75/75 -> train the next rank.
    list = ns.Recipes.CouldLearn(db, 102)
    eq(list[1].key, "Ana-Forever")
    eq(list[1].status, "skill")
    eq(list[2].status, "rank")
    -- 103 (needs 160): Ana 140/150 -> needs Expert first.
    list = ns.Recipes.CouldLearn(db, 103)
    eq(#list, 1)
    eq(list[1].status, "rank")
    ns.Sources.Required = real
end)

test("trainer services: rank and profession from the trainer window", function()
    local T = ns.Trainers
    -- Service names as Forever's trainers list them (Undercity, 1.60.1).
    eq(T.ParseRank("Journeyman Enchanting"), "Journeyman")
    eq(T.ParseRank("Expert Herbalism"), "Expert")
    eq(T.ParseRank("Journeyman Cook"), "Journeyman")
    eq(T.ParseRank("Enchant Chest - Minor Stats"), nil)
    eq(T.ParseRank("Mastery"), nil)
    local ranks = T.RanksFromServices({
        "Apprentice Herbalism||available|0| 0|9|prof",
        "Journeyman Herbalism||unavailable|0|Herbalism 50|450|",
        "Expert Herbalism||unavailable|0|Herbalism 125|4500|",
        "Artisan Herbalism||unavailable|0|Herbalism 200|45000|",
        "Incense Candle|Tier 1|unavailable|0|Herbalism 20|90|",
    })
    eq(ranks.Expert.cost, 4500)
    eq(ranks.Artisan.skill, 200)
    eq(ranks.Journeyman.level, 0)
    eq(ranks["Incense Candle"], nil)
    eq(T.SkillLineFor("Cooking"), 185)
    eq(T.SkillLineFor("First Aid"), 129)
    eq(T.SkillLineFor("Swords"), nil)
end)

test("researched rank trainers", function()
    local RT = ns.RankTrainers
    local list, known = RT.For(333, "Expert")
    eq(known, true)
    local names = {}
    for _, t in ipairs(list) do names[t.name] = true end
    eq(names["Hgarth"], true)
    eq(names["Lavinia Crowe"], nil, "Lavinia teaches Journeyman, not Expert (seen in game)")
    eq(RT.For(333, "Artisan")[1].id, 11073, "Annora")
    eq(select(2, RT.For(182, "Artisan")), true, "gathering trainers teach every rank")
    eq(select(2, RT.For(185, "Journeyman")), false, "Cooking: any trainer (searched)")
    -- Every listed trainer has a name, and IDs are numbers when present.
    for _, ranks in pairs(RT.crafting) do
        for _, l in pairs(ranks) do
            for _, t in ipairs(l) do assert(type(t.name) == "string" and (t.id == nil or type(t.id) == "number")) end
        end
    end
end)

test("specializations", function()
    local S = ns.Specializations
    eq(#S.For(202).options, 2, "Gnomish and Goblin Engineering")
    eq(S.For(202).level, 30)
    eq(#S.For(165).options, 3, "Dragonscale, Elemental, Tribal")
    eq(S.For(164), nil, "Blacksmithing: not confirmed for Forever")
    eq(S.For(197), nil, "Tailoring: none")
    eq(S.Spells()[20222], 202)
    eq(S.Chosen({ specs = { [202] = 20222 } }, 202).name, "Goblin Engineering")
    eq(S.Chosen({ specs = {} }, 202), nil)
end)

---------------------------------------------------------------------------
-- leveling planner
---------------------------------------------------------------------------

test("planner: skill-up chance", function()
    local P = ns.Planner
    local t = { 100, 110, 120 }
    eq(P.Chance(t, 90), 1, "orange")
    eq(P.Chance(t, 100), 1, "yellow starts: (120-100)/(120-100)")
    eq(P.Chance(t, 110), 0.5)
    eq(P.Chance(t, 120), 0, "grey")
    eq(P.Chance(nil, 100), 0)
end)

test("planner: cheapest recipe per point, merged steps, materials", function()
    -- A: cheap but yellow from 100, grey at 105. B: dearer, orange until 110, grey at 130.
    local recipes = {
        A = { t = { 100, 102, 105 }, r = { { itemID = 1, count = 1 } } },
        B = { t = { 110, 120, 130 }, r = { { itemID = 2, count = 2 } } },
    }
    local prices = { [1] = 10, [2] = 30 }
    local plan = ns.Planner.Plan({
        rank = 100, target = 110, recipes = { "A", "B" },
        thresholds = function(id) return recipes[id].t end,
        reagents = function(id) return recipes[id].r end,
        price = function(item) return prices[item] end,
        inventory = { [2] = 4 }, -- two crafts of B in the bags
    })
    eq(plan.reached, 110)
    eq(plan.steps[1].recipeID, "B", "orange from what you have first")
    eq(plan.steps[1].to, 102)
    eq(plan.steps[1].cost, 0)
    -- Then A per point: 10 / chance x 4/3 (yellow): 22, 33 at 102-103, then 67 > B's 60.
    eq(plan.steps[2].recipeID, "A", "the cheap yellow one while it is well under B's cost")
    eq(plan.steps[2].to, 104)
    eq(plan.steps[3].recipeID, "B")
    eq(plan.steps[3].to, 110)
    eq(#plan.steps, 3)
    eq(plan.materials[2].need, 16, "8 crafts of B")
    eq(plan.materials[2].have, 4)
    eq(plan.steps[3].cost, 12 * 30, "the bill only counts what you buy")
end)

test("planner: orange from your own materials before a yellow one you also have", function()
    -- Enchanting at 130: Enchant 2H Weapon - Minor Impact (yellow) and Enchant Boots - Minor
    -- Stamina / Bracer - Lesser Stamina (orange), materials for all of them in the bags.
    local recipes = {
        Impact = { t = { 130, 140, 150 }, r = { { itemID = 1, count = 1 } } },
        Boots = { t = { 150, 160, 170 }, r = { { itemID = 2, count = 1 } } },
        Bracer = { t = { 150, 160, 170 }, r = { { itemID = 3, count = 1 } } },
    }
    local prices = { [1] = 442, [2] = 396, [3] = 500 }
    local plan = ns.Planner.Plan({
        rank = 130, target = 150, recipes = { "Impact", "Boots", "Bracer" },
        thresholds = function(id) return recipes[id].t end,
        reagents = function(id) return recipes[id].r end,
        price = function(item) return prices[item] end,
        inventory = { [1] = 20, [2] = 10, [3] = 10 },
    })
    eq(plan.reached, 150)
    eq(plan.steps[1].recipeID, "Boots", "orange, cheapest materials first")
    eq(plan.steps[1].to, 140)
    eq(plan.steps[2].recipeID, "Bracer")
    eq(plan.steps[2].to, 150)
    eq(#plan.steps, 2, "never the yellow one")
    eq(plan.cost, 0, "nothing to buy")
end)

test("planner: orange first unless yellow is clearly cheaper; ties go to orange", function()
    local function first(yellowPrice)
        local recipes = {
            Y = { t = { 100, 110, 120 }, r = { { itemID = 1, count = 1 } } },
            O = { t = { 120, 130, 140 }, r = { { itemID = 2, count = 1 } } },
        }
        local prices = { [1] = yellowPrice, [2] = 100 }
        return ns.Planner.Plan({
            rank = 100, target = 101, recipes = { "Y", "O" },
            thresholds = function(id) return recipes[id].t end,
            reagents = function(id) return recipes[id].r end,
            price = function(item) return prices[item] end,
        }).steps[1].recipeID
    end
    eq(first(80), "O", "yellow 80 x 4/3 > 100")
    eq(first(75), "O", "a tie goes to the sure skill-up")
    eq(first(60), "Y", "yellow 60 x 4/3 = 80: clearly cheaper")
end)

test("planner: each step has its own materials (need, and what you have used first)", function()
    local recipes = {
        A = { t = { 100, 102, 105 }, r = { { itemID = 1, count = 1 } } },
        B = { t = { 110, 120, 130 }, r = { { itemID = 2, count = 2 } } },
    }
    local plan = ns.Planner.Plan({
        rank = 100, target = 110, recipes = { "A", "B" },
        thresholds = function(id) return recipes[id].t end,
        reagents = function(id) return recipes[id].r end,
        price = function(item) return ({ [1] = 10, [2] = 30 })[item] end,
        inventory = { [2] = 5 }, -- 2 crafts of B (and one left over)
    })
    -- Steps: B 100-102 (owned), A 102-104, B 104-110 (see the plan test above).
    local first, last = plan.steps[1], plan.steps[3]
    eq(first.materials[2].need, 4)
    eq(first.materials[2].have, 4, "the first B step uses what you have")
    eq(last.materials[2].need, last.crafts * 2)
    eq(last.materials[2].have, 1, "the one left over goes to the next B step")
    eq(plan.steps[2].materials[1].have, 0)
end)

test("planner: stops when nothing gives skill-ups; trainer recipes wait for their skill", function()
    local plan = ns.Planner.Plan({
        rank = 100, target = 120, recipes = { 1, 2 },
        thresholds = function(id) return id == 1 and { 90, 95, 105 } or { 110, 115, 125 } end,
        reagents = function() return { { itemID = 9, count = 1 } } end,
        price = function() return 5 end,
        learnAt = function(id) return id == 2 and 115 or nil end,
    })
    eq(plan.reached, 105, "recipe 2 can't be learned until 115")
    eq(#plan.steps, 1)
end)

test("planner: without prices, fewest unknown-price materials first", function()
    local plan = ns.Planner.Plan({
        rank = 50, target = 51, recipes = { 1, 2 },
        thresholds = function() return { 60, 70, 80 } end,
        reagents = function(id) return { { itemID = 100 + id, count = id == 1 and 5 or 2 } } end,
        price = function() return nil end,
    })
    eq(plan.steps[1].recipeID, 2, "2 unknown materials beat 5")
end)

test("planner: unpriced recipes only when nothing priced works", function()
    local plan = ns.Planner.Plan({
        rank = 50, target = 52, recipes = { 1, 2 },
        thresholds = function() return { 60, 70, 80 } end,
        reagents = function(id) return { { itemID = id, count = 1 } } end,
        price = function(item) return item == 2 and 100 or nil end,
    })
    eq(plan.steps[1].recipeID, 2, "priced beats unpriced")
    eq(plan.unpriced, false)
end)

---------------------------------------------------------------------------
-- disenchanting
---------------------------------------------------------------------------

test("disenchant: Forever's bands decide what can be disenchanted", function()
    local D = ns.Disenchant
    local bands = ns.DisenchantBands
    assert(#bands >= 50, "bands generated from the game data")
    eq(D.Band(bands, 4, 2, 18)[3], 16, "green armor 18 is in the 16-20 band")
    eq(D.Band(bands, 2, 3, 10)[2], 3, "Forever has blue bands below item level 21")
    eq(D.Band(bands, 4, 4, 30), nil, "no purple band below 40")
    eq(D.Band(bands, 4, 1, 30), nil, "white items don't disenchant")
    eq(D.Band(bands, 7, 2, 30), nil, "trade goods don't disenchant")
end)

test("disenchant: classic table, armor vs weapons", function()
    local D = ns.Disenchant
    local armor = D.Classic(ns.DisenchantClassic, 4, 2, 12)
    eq(armor[1][1], 10940, "green armor 5-15: Strange Dust first")
    eq(armor[1][2], 0.80)
    local weapon = D.Classic(ns.DisenchantClassic, 2, 2, 12)
    eq(weapon[2][1], 10938, "green weapon 5-15: Lesser Magic Essence")
    eq(weapon[2][2], 0.80, "weapons give essence most often")
    eq(D.Classic(ns.DisenchantClassic, 4, 3, 33)[1][1], 11138, "blue 31-35: Small Glowing Shard")
    eq(D.Classic(ns.DisenchantClassic, 2, 4, 58)[1][1], 20725, "purple 56-60: Nexus Crystal")
    -- Every Forever band has a classic row (so tooltips never go blank for a real band).
    for _, b in ipairs(ns.DisenchantBands) do
        for lvl = b[3], math.min(b[4], 70) do
            assert(D.Classic(ns.DisenchantClassic, b[1], b[2], lvl), "no classic row for band " .. b[7] .. " at " .. lvl)
        end
    end
end)

test("disenchant: recordings that fit the classic table confirm it (classic chances kept)", function()
    local D = ns.Disenchant
    local records = {}
    local band = D.Band(ns.DisenchantBands, 4, 2, 12)
    for i = 1, D.CONFIRM_AT - 1 do D.Record(records, band[7], { [10940] = (i % 2) + 1 }) end
    local r = D.Results(ns.DisenchantBands, ns.DisenchantClassic, records, 4, 2, 12)
    eq(r.source, "classic")
    eq(r.seen, D.CONFIRM_AT - 1)
    eq(r.differs, false)
    D.Record(records, band[7], { [10938] = 2 }, 2580, 12)
    eq(records[band[7]].items[2580], 12, "the item and the level it was read at are kept")
    r = D.Results(ns.DisenchantBands, ns.DisenchantClassic, records, 4, 2, 12)
    eq(r.source, "confirmed", "7 Strange Dust + 3 Lesser Magic Essence fit the classic 80/20")
    eq(r.results[1][2], 0.80, "classic chances kept: 10 disenchants can't measure them better")
    eq(D.Results(ns.DisenchantBands, ns.DisenchantClassic, records, 4, 1, 12), nil, "white: nothing")
end)

test("disenchant: recordings that don't fit are flagged, then shown instead", function()
    local D = ns.Disenchant
    local records = {}
    local band = D.Band(ns.DisenchantBands, 2, 2, 28) -- green weapon 26-30
    D.Record(records, band[7], { [10939] = 2 }) -- Greater Magic Essence: not in the classic row
    local r = D.Results(ns.DisenchantBands, ns.DisenchantClassic, records, 2, 2, 28)
    eq(r.source, "classic")
    eq(r.differs, true)
    for _ = 2, D.CONFIRM_AT do D.Record(records, band[7], { [10939] = 1 }) end
    r = D.Results(ns.DisenchantBands, ns.DisenchantClassic, records, 2, 2, 28)
    eq(r.source, "seen")
    eq(r.results[1][1], 10939)
    eq(r.results[1][2], 1)
    eq(r.results[1][3], 1)
    eq(r.results[1][4], 2)
    -- A count outside the classic range doesn't fit either.
    eq(D.Fits({ { 1, 1, 1, 2 } }, { mats = { [1] = { t = 1, q = 3, lo = 3, hi = 3 } } }), false)
    eq(D.Fits({ { 1, 0.95, 1, 2 }, { 2, 0.05, 1, 1 } }, { mats = { [1] = { t = 4, q = 6, lo = 1, hi = 2 } } }), true,
        "a rare material not seen yet is fine")
end)

test("disenchant: expected value, nil when a result has no price", function()
    local D = ns.Disenchant
    local results = { { 1, 0.75, 1, 3 }, { 2, 0.25, 1, 1 } }
    eq(D.Value(results, function(id) return id == 1 and 100 or 40 end), 160, "0.75 x 2 x 100 + 0.25 x 1 x 40")
    eq(D.Value(results, function(id) return id == 1 and 100 or nil end), nil)
    eq(D.Value({}, function() return 1 end), nil)
end)

test("disenchant: list profit counts the materials' value as is", function()
    local mats = { { itemID = 1, need = 2 } }
    local lookup = function() return { vendor = 10 } end
    local profit, cost, value = ns.Prices.ListProfit(mats, 1, "disenchant", 95, lookup)
    eq(cost, 20)
    eq(value, 95, "the auction cut is already in the disenchant value")
    eq(profit, 75)
end)

test("disenchant: shared totals travel in D lines and come back the same", function()
    local records = { [4] = { n = 10, mats = { [10940] = { t = 7, q = 11, lo = 1, hi = 2 }, [10938] = { t = 3, q = 4, lo = 1, hi = 2 } } } }
    local text = ns.Share.Encode({}, "1.60.1", "1.2.0", nil, { disenchants = records })
    assert(text:find("\nD~4~10~10938:3:4:1:2;10940:7:11:1:2", 1, true), text)
    local vendors, trainers, confirmed, de = ns.Share.Decode(text)
    assert(vendors and trainers and confirmed)
    eq(de[4].n, 10)
    eq(de[4].mats[10940].q, 11)
    -- A copy that doesn't know D lines (older Tradebook) just skips them: no vendors, no error.
    eq(next(vendors), nil)
end)

test("disenchant: shared totals are checked before they're kept", function()
    local C = ns.Net.CleanDisenchant
    assert(C(4, { n = 2, mats = { [10940] = { t = 2, q = 3, lo = 1, hi = 2 } } }))
    eq(C(4, { n = 2, mats = { [10940] = { t = 3, q = 3, lo = 1, hi = 1 } } }), nil, "seen more often than disenchanted")
    eq(C(4, { n = 2, mats = { [10940] = { t = 2, q = 9, lo = 1, hi = 2 } } }), nil, "total outside min/max")
    eq(C(4, { n = 0, mats = { [10940] = { t = 0, q = 0, lo = 1, hi = 1 } } }), nil)
    eq(C(-1, { n = 1, mats = { [10940] = { t = 1, q = 1, lo = 1, hi = 1 } } }), nil)
    eq(C(4, { n = 1, mats = {} }), nil, "nothing in it")
    local heard = {}
    ns.Net.Accept(heard, ns.Share.Encode({}, "b", "v", nil, { disenchants = {
        [4] = { n = 1, mats = { [10940] = { t = 1, q = 2, lo = 2, hi = 2 } } } } }), "p1", 100)
    eq(heard.de.p1.bands[4].n, 1)
    ns.Net.Accept(heard, ns.Share.Encode({}, "b", "v", nil, { disenchants = {
        [4] = { n = 3, mats = { [10940] = { t = 3, q = 4, lo = 1, hi = 2 } } } } }), "p1", 200)
    eq(heard.de.p1.bands[4].n, 3, "a player's latest totals replace the older ones")
end)

test("disenchant: other players count for a band once 2+ players reported it", function()
    local D = ns.Disenchant
    local one = { mats = { [10940] = { t = 1, q = 1, lo = 1, hi = 1 } }, n = 1 }
    local heard = { p1 = { at = 1, bands = { [4] = one, [5] = one } }, p2 = { at = 1, bands = { [5] = one } } }
    local c = D.Combine({ [4] = { n = 2, mats = { [10940] = { t = 2, q = 3, lo = 1, hi = 2 } } } }, heard)
    eq(c[4].n, 3, "you + p1")
    eq(c[4].players, 2)
    eq(c[5].n, 2, "p1 + p2")
    local alone = D.Combine({}, { p1 = { at = 1, bands = { [6] = one } } })
    eq(alone[6], nil, "one other player alone doesn't count")
    local r = D.Results(ns.DisenchantBands, ns.DisenchantClassic, c, 4, 2, 12, ns.DisenchantForeverSeen)
    eq(r.players, 2)
    eq(r.outside, "Wowhead", "green armor 5-15 was seen in Forever by Wowhead")
end)

test("disenchant: reverse lookup, disputed row, best option", function()
    local D = ns.Disenchant
    local src = D.Sources(ns.DisenchantBands, ns.DisenchantClassic, 10938) -- Lesser Magic Essence
    eq(#src, 2, "green armor and weapons 5-15")
    eq(src[1][2], 4, "armor first")
    eq(src[2][5], 0.80, "weapons give it 80%")
    local r = D.Results(ns.DisenchantBands, ns.DisenchantClassic, {}, 4, 3, 58)
    eq(r.disputed, true, "blue 56+ Nexus chance is disputed")
    eq(D.Results(ns.DisenchantBands, ns.DisenchantClassic, {}, 4, 2, 58).disputed, false)
    eq(D.Best(100, 50, 80), "disenchant")
    local best, close = D.Best(100, 95, nil)
    eq(best, "disenchant")
    eq(close, true, "within 10%: roughly equal")
    eq(D.Best(100, 300, nil), "vendor")
    eq(D.Best(nil, 300, nil), nil)
end)

test("disenchant: shipped community totals don't add to your own (the bigger one is used)", function()
    local D = ns.Disenchant
    local live = { [4] = { n = 3, players = 1, mats = {} }, [7] = { n = 20, players = 2, mats = {} } }
    local community = { [4] = { n = 10, players = 1, mats = {} }, [7] = { n = 5, players = 1, mats = {} }, [8] = { n = 2, mats = {} } }
    local r = D.WithCommunity(live, community)
    eq(r[4].n, 10)
    eq(r[7].n, 20)
    eq(r[8].n, 2)
    assert(type(ns.CommunityDisenchants) == "table")
end)

test("dev: heard notifications say what came in, marking new NPCs", function()
    SlashCmdList = SlashCmdList or {}
    assert(loadfile("dev/TradebookDev/Dev.lua"))()
    local text = TradebookDev.HeardText("Another player (#1)",
        { vendors = { [12027] = "Tukk", [3005] = "Mahu" }, trainers = { [11084] = "Tarn" }, confirms = 2, disenchants = 3 },
        function(_, npc) return npc == 12027 or npc == 11084 end)
    assert(text:find("2 vendors (Mahu, |cff40ff40NEW|r Tukk)", 1, true), text)
    assert(text:find("1 trainer (|cff40ff40NEW|r Tarn)", 1, true), text)
    assert(text:find("2 confirmed again", 1, true), text)
    assert(text:find("disenchants for 3 bands", 1, true), text)
    eq(TradebookDev.HeardText("x", { vendors = {}, trainers = {}, confirms = 0, disenchants = 0 }, function() end), nil)
    -- What Tradebook reports it kept from a share text.
    local heard = {}
    local share = ns.Share.Encode({ [3005] = { name = "Mahu", seenAt = 100, items = { [2320] = { p = 10, s = -1 } },
        loc = { m = 1456, x = 43.7, y = 44.4 } } }, "b", "v", nil, { disenchants = {
        [4] = { n = 1, mats = { [10940] = { t = 1, q = 1, lo = 1, hi = 1 } } } } })
    local kept, info = ns.Net.Accept(heard, share, "p1", 200)
    eq(kept, 2)
    eq(info.vendors[3005], "Mahu")
    eq(info.disenchants, 1)
end)

test("dev: counts what came in since the last import", function()
    SlashCmdList = SlashCmdList or {}
    assert(loadfile("dev/TradebookDev/Dev.lua"))()
    local log = {
        { at = 50, who = "a", v = 9, vn = 9, t = 0, tn = 0, c = 0, d = 0 }, -- before the import
        { at = 150, who = "a", v = 2, vn = 1, t = 1, tn = 1, c = 3, d = 0 },
        { at = 160, who = "b", v = 1, vn = 0, t = 0, tn = 0, c = 0, d = 4 },
        { at = 170, who = "a", v = 0, vn = 0, t = 0, tn = 0, c = 1, d = 2 },
    }
    local s = TradebookDev.SinceImport(log, 100)
    eq(s.vendors, 3)
    eq(s.newVendors, 1)
    eq(s.trainers, 1)
    eq(s.confirms, 4)
    eq(s.disenchantPlayers, 2)
    eq(s.players, 2)
    eq(TradebookDev.SinceImport(log, 200).messages, 0, "all imported")
    eq(TradebookDev.SinceText(TradebookDev.SinceImport(log, 200), 200), nil)
end)

---------------------------------------------------------------------------
-- prices (Auctionator)
---------------------------------------------------------------------------

test("cheapest price prefers the vendor when it is cheaper or equal", function()
    local P = ns.Prices
    eq(select(2, P.Cheapest({ vendor = 50, auction = 80 })), "vendor")
    eq(select(2, P.Cheapest({ vendor = 90, auction = 80 })), "auction")
    eq(P.Cheapest({ vendor = 80, auction = 80 }), 80)
    eq(P.Cheapest({ auction = 7 }), 7)
    eq(P.Cheapest({}), nil)
    eq(P.Cheapest(nil), nil)
end)

test("craft cost sums priced materials and counts unpriced ones", function()
    local prices = { [1] = { auction = 100 }, [2] = { vendor = 25, auction = 40 }, [3] = {} }
    local lookup = function(id) return prices[id] end
    local total, unpriced = ns.Prices.CraftCost({
        { itemID = 1, need = 3 }, { itemID = 2, need = 4 }, { itemID = 3, need = 1 },
    }, lookup)
    eq(total, 400)
    eq(unpriced, 1)
    eq(select(2, ns.Prices.CraftCost({}, lookup)), 0)
end)

test("profit takes the auction house cut off the sale", function()
    local value, profit = ns.Prices.Profit(500, 1000, 2)
    eq(value, 1900)
    eq(profit, 1400)
    eq(ns.Prices.Profit(500, nil, 1), nil, "no auction price")
end)

test("list profit: buy every material, sell to a vendor or at auction", function()
    local prices = { [1] = { auction = 100 }, [2] = { vendor = 25, auction = 40 }, [3] = {} }
    local lookup = function(id) return prices[id] end
    local mats = { { itemID = 1, need = 3 }, { itemID = 2, need = 4 } } -- 300 + 100 = 400
    local profit, cost, value = ns.Prices.ListProfit(mats, 2, "vendor", 150, lookup)
    eq(cost, 400); eq(value, 300); eq(profit, -100)
    local p2, _, v2 = ns.Prices.ListProfit(mats, 1, "auction", 1000, lookup)
    eq(v2, 950, "auction house cut"); eq(p2, 550)
    eq(ns.Prices.ListProfit(mats, 1, "auction", nil, lookup), nil, "no sale price")
    eq(ns.Prices.ListProfit({ { itemID = 3, need = 1 } }, 1, "vendor", 100, lookup), nil, "a material without a price")
    eq(ns.Prices.ListProfit({}, 1, "vendor", 100, lookup), nil, "no materials")
    eq(ns.Prices.ListProfit(mats, 1, "off", 100, lookup), nil, "off")
    eq(ns.Prices.RoundForList(12345), 12300)
    eq(ns.Prices.RoundForList(-25678), -25700)
    eq(ns.Prices.RoundForList(9999), 9999)
end)

test("No Merchant's Favor hides recipes only bought with favor", function()
    eq(ns.Sources.NeedsFavor(1213622), true, "Enchant Gloves - Holy Power: supply camp only")
    eq(ns.Sources.NeedsFavor(2163), false, "White Leather Jerkin: dropped, no favor")
    -- Any recipe that costs favor but a trainer teaches or a mob drops stays.
    for id, o in pairs(ns.RecipeVendors) do
        if o.fv then
            local k = ns.Sources.Kinds(id)
            if k and (k.trainer or k.drop) then eq(ns.Sources.NeedsFavor(id), false, "other source " .. id) end
        end
    end
end)

test("tabs wrap onto more rows only when they don't fit", function()
    local wrap = ns.util.WrapRows
    local rows = wrap({ 50, 50, 50 }, 200, 300, 3)
    eq(#rows, 1, "all fit")
    rows = wrap({ 50, 50, 50, 50, 50 }, 110, 300, 3) -- first row: 50 + 3 + 50 = 103
    eq(#rows, 2); eq(#rows[1], 2); eq(rows[2][1], 3); eq(#rows[2], 3)
    rows = wrap({ 120, 40 }, 100, 100, 3)
    eq(#rows[1], 1, "a row always takes one tab, even a too-wide one"); eq(rows[2][1], 2)
    eq(#wrap({}, 100, 100, 3), 0)
end)

test("game vendor prices only for items a vendor sells", function()
    local real = ns.VendorPrices
    ns.VendorPrices = { [2320] = 10, [3371] = 4 }
    local sold = function(id) return id == 2320 end
    eq(ns.Prices.GameVendorPrice(2320, sold), 10, "Coarse Thread")
    eq(ns.Prices.GameVendorPrice(3371, sold), nil, "has a buy price but no vendor sells it")
    eq(ns.Prices.GameVendorPrice(999, sold), nil)
    ns.VendorPrices = real
end)

test("shopping list split: vendor vs auction house", function()
    local prices = { [1] = { vendor = 10 }, [2] = { auction = 50, vendor = 80 }, [3] = { auction = 5, vendor = 10 }, [4] = {} }
    local split = ns.Prices.SplitShopping({
        { itemID = 1, missing = 3 }, { itemID = 2, missing = 2 }, { itemID = 3, missing = 1 }, { itemID = 4, missing = 7 },
    }, function(id) return prices[id] end)
    eq(#split.vendor.items, 1, "thread: vendor")
    eq(split.vendor.total, 30)
    eq(#split.auction.items, 3, "cheaper at auction, or no price")
    eq(split.auction.total, 105)
    eq(split.auction.unpriced, 1)
    eq(split.vendor.items[1].unit, 10)
end)

test("money text", function()
    eq(ns.Prices.MoneyText(12345), "1g 23s 45c")
    eq(ns.Prices.MoneyText(10000), "1g")
    eq(ns.Prices.MoneyText(0), "0c")
    eq(ns.Prices.MoneyText(-250), "-2s 50c")
end)

test("net: share text survives chunking, any part order, and rejects bad parts", function()
    local N = ns.Net
    local lines = { "TBV1~b~v~1~0", "V~5~Odd ^ Name~1453~50.1~60.2~100" }
    for i = 1, 60 do lines[#lines + 1] = ("I~%d~%d~-1~"):format(1000 + i, i * 10) end
    local text = table.concat(lines, "\n")
    local parts = assert(N.Chunk(text, "a1"))
    assert(#parts > 1, "long text is split")
    for _, p in ipairs(parts) do assert(#p <= 255, "fits in one addon message") end
    local asm = N.NewAssembler()
    local full
    for i = #parts, 1, -1 do full = N.Feed(asm, "p1", parts[i], 0) or full end
    local back = assert(ns.Share.Decode(full))
    eq(back[5].name, "Odd   Name", "a ^ in a name can't break the lines")
    eq(back[5].items[1060].p, 600)
    eq(N.Feed(asm, "p1", "junk", 0), nil)
    eq(N.Feed(asm, "p1", "a2~3~2~x", 0), nil, "part beyond the total")
    eq(N.Feed(asm, "p1", "a3~1~99~x", 0), nil, "too many parts")
    -- unfinished texts expire
    N.Feed(asm, "p2", "b1~1~2~TBV1", 0)
    eq(asm.n, 1)
    N.Feed(asm, "p3", "c1~1~2~TBV1", 1000)
    eq(asm.pending["p2/b1"], nil, "expired")
end)

test("net: heard vendors are checked, and agreeing players confirm them", function()
    local N, S = ns.Net, ns.Share
    local NOW_T = 1800000000
    local v = { name = "Pawani", seenAt = NOW_T - 60, loc = { m = 1453, x = 50, y = 60 },
        items = { [2320] = { p = 10, s = -1 }, [252941] = { s = -1, c = "currency:3402:90" } } }
    local text = S.Encode({ [248201] = v }, "b", "v")
    local heard = {}
    eq(N.Accept(heard, text, "aaaa", NOW_T), 1)
    local best = N.BestAll(heard, "vendors")[248201]
    eq(best.name, "Pawani")
    eq(best.agree, 1, "one player: unconfirmed")
    eq(N.Accept(heard, text, "bbbb", NOW_T + 1), 1)
    eq(N.BestAll(heard, "vendors")[248201].agree, 2, "two players agree")
    -- a third player with a different price doesn't beat the two who agree
    local odd = { name = "Pawani", seenAt = NOW_T, loc = v.loc, items = { [2320] = { p = 99, s = -1 } } }
    N.Accept(heard, S.Encode({ [248201] = odd }, "b", "v"), "cccc", NOW_T + 2)
    best = N.BestAll(heard, "vendors")[248201]
    eq(best.items[2320].p, 10)
    eq(best.agree, 2)
    -- a fourth player replaces the oldest report (3 kept)
    N.Accept(heard, text, "dddd", NOW_T + 5)
    local n = 0
    for _ in pairs(heard.vendors[248201].reports) do n = n + 1 end
    eq(n, N.MAX_REPORTERS)
    -- bad data is dropped
    eq(N.CleanVendor({ name = "X", items = { [1] = { p = -5 } } }, NOW_T), nil, "negative price")
    eq(N.CleanVendor({ name = "X", loc = { m = 1, x = 500, y = 1 }, items = { [1] = { p = 1 } } }, NOW_T), nil, "off the map")
    eq(N.CleanVendor({ name = "X", items = {} }, NOW_T), nil, "sells nothing")
    eq(N.CleanVendor({ name = string.rep("x", 80), items = { [1] = { p = 1 } } }, NOW_T), nil, "name too long")
    eq(N.CleanVendor({ name = "X", seenAt = NOW_T * 2, items = { [1] = { p = 1 } } }, NOW_T).seenAt, NOW_T,
        "a time in the future becomes now")
    -- confirmations and trainers
    eq(N.Accept(heard, "TBV1~b~v~1~0\nC~3399~" .. NOW_T, "aaaa", NOW_T), 1)
    eq(heard.confirms.vendor[3399].aaaa, NOW_T)
    local t = { [3399] = { name = "Zamja", skill = 185, seenAt = NOW_T, services = { "Spiced Wolf Meat||used|0|Cooking 10|50|" } } }
    N.Accept(heard, S.Encode({}, "b", "v", t), "aaaa", NOW_T)
    eq(N.BestAll(heard, "trainers")[3399].services[1], "Spiced Wolf Meat||used|0|Cooking 10|50|")
    -- the Vendors tab keeps how many agree
    local items = ns.VendorDB.AddSaved({}, N.BestAll(heard, "vendors"), "players")
    eq(items[2320].vendors[248201].agree, 2)
    eq(items[2320].vendors[248201].source, "players")
end)

test("net: own messages are known by the session tag; migration 4 forgets heard data", function()
    local N = ns.Net
    eq(N.IsOwn("ab121f~1~2~TBV1", "ab12"), true)
    eq(N.IsOwn("cd341f~1~2~TBV1", "ab12"), false)
    eq(N.IsOwn("ab12", ""), false)
    local db = ns.DB.Migrate({ version = 3, heard = { vendors = { [1] = { reports = {} } } }, netSent = { x = 1 } })
    eq(next(db.heard), nil, "echoed reports forgotten")
    eq(db.netSent.x, 1, "what you sent is kept")
end)

test("net: test messages are known as your own and ignored by everyone else", function()
    local N = ns.Net
    local msg = N.TestMessage("ab12", 7)
    eq(N.IsOwn(msg, "ab12"), true)
    eq(N.Feed(N.NewAssembler(), "x", msg, 0), nil)
    assert(#msg <= 255)
end)

test("dev: unscanned vendors leave out everyone's scans", function()
    SlashCmdList = {}
    assert(loadfile("dev/TradebookDev/Dev.lua"))()
    local set = TradebookDev.Unscanned(
        { { itemID = 1, vendors = { 10, 11 } }, { itemID = 2, vendors = { 10 } } },
        { [500] = { v = { 11, 12 } }, [501] = { x = 3 } },
        { { [11] = {} }, { [99] = {} } })
    eq(set[10].items, 2)
    eq(set[11], nil, "scanned")
    eq(set[12].recipe, true, "recipe vendor Questie doesn't list")
    eq(set[12].items, 0)
    -- sorting: faction (yours, Both, the other, hostile, unknown), then nearest first
    local rows = { { npcID = 1, faction = "Alliance", distance = 5 }, { npcID = 2, faction = "Both", distance = 50 },
        { npcID = 3, faction = "Horde", distance = 90 }, { npcID = 4, faction = "Horde", distance = 10 },
        { npcID = 5, distance = 1 }, { npcID = 6, faction = "Neither", distance = 2 } }
    local order = {}
    for _, r in ipairs(TradebookDev.Sort(rows, "faction", "Horde")) do order[#order + 1] = r.npcID end
    eq(table.concat(order, ","), "4,3,2,1,6,5")
    order = {}
    for _, r in ipairs(TradebookDev.Sort(rows, "distance", "Horde")) do order[#order + 1] = r.npcID end
    eq(table.concat(order, ","), "5,6,1,4,2,3")
    -- filters: faction checkboxes, distance, checked NPCs
    local D = TradebookDev
    local f = { factions = D.DefaultFactions("Horde") }
    eq(D.Passes({ faction = "Horde", distance = 10 }, f), true)
    eq(D.Passes({ faction = "Alliance", distance = 10 }, f), false, "other faction off by default")
    eq(D.Passes({ distance = 10 }, f), true, "unknown faction shown")
    eq(D.Passes({ faction = "Neither" }, f), false)
    f.within = 500
    eq(D.Passes({ faction = "Both", distance = 600 }, f), false, "too far")
    eq(D.Passes({ faction = "Both" }, f), false, "distance unknown")
    eq(D.Passes({ faction = "Both", distance = 400, marks = { novendor = "auto" } }, f), false, "marked: hidden")
    f.showChecked = true
    eq(D.Passes({ faction = "Both", distance = 400, marks = { novendor = "auto" } }, f), true)
    f.showChecked = nil
    -- world events: off-season event NPCs hidden; "not there" doesn't count while the event is on
    eq(D.EventOf("Lhara", "Darkmoon Faire"), "Darkmoon Faire")
    eq(D.EventOf("Valadar Starsong", "Lunar Festival Vendor"), "Lunar Festival")
    eq(D.EventOf("Joseph Moore", "Leatherworking Supplies"), nil)
    local dmf = { faction = "Both", distance = 100, event = "Darkmoon Faire", marks = { missing = "manual" } }
    eq(D.Passes(dmf, f, {}), false, "event not on")
    eq(D.Passes(dmf, f, D.EventsInTitles({ "Darkmoon Faire: Elwynn" })), true, "on now: shown, not-there ignored")
    eq(D.Passes(dmf, f, nil), false, "calendar unknown: the not-there mark still counts")
    dmf.marks = { novendor = "manual" }
    eq(D.Passes(dmf, f, D.EventsInTitles({ "Darkmoon Faire" })), false, "not a vendor still counts")
    dmf.marks = nil
    f.events = "all"
    eq(D.Passes(dmf, f, {}), true, "always: shown off-season")
    f.events = "none"
    eq(D.Passes(dmf, f, D.EventsInTitles({ "Darkmoon Faire" })), false, "world events off: hidden even when on")
    eq(D.Passes({ faction = "Both", distance = 100 }, f, {}), true, "other NPCs unaffected")
    f.events = nil
    -- marks: "not there" and "not a vendor" are kept apart; no marks left removes the NPC
    local marks = {}
    D.Mark(marks, 7, "Brother Zendraas", "missing", "manual", 1)
    D.Mark(marks, 7, "Brother Zendraas", "novendor", "auto", 2)
    eq(marks[7].missing, "manual"); eq(marks[7].novendor, "auto")
    D.Mark(marks, 7, nil, "missing", nil, 3)
    eq(marks[7].missing, nil); eq(marks[7].novendor, "auto")
    eq(D.Mark(marks, 7, nil, "novendor", nil, 4), nil)
    eq(marks[7], nil)
    TradebookDev, SlashCmdList, SLASH_TRADEBOOKDEV1 = nil, nil, nil
end)

test("tracking spell: newest known rank, only for herbalism and mining", function()
    local tns = { L = {}, Compat = {}, On = function() end }
    assert(loadfile("Tradebook/UI/TrackingButton.lua"))("Tradebook", tns)
    local T = tns.TrackingButton
    local knows = function(set) return function(id) return set[id] == true end end
    eq(T.KnownSpell(182, knows({ [2383] = true })), 2383, "Find Herbs")
    eq(T.KnownSpell(182, knows({ [2383] = true, [8387] = true })), 8387, "newer rank first")
    eq(T.KnownSpell(186, knows({ [2580] = true })), 2580, "Find Minerals")
    eq(T.KnownSpell(186, knows({})), nil, "not learned")
    eq(T.KnownSpell(393, knows({ [2383] = true })), nil, "skinning has no tracking")
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
