-- tests/run.lua
-- Plain-Lua tests for Tradebook's pure data logic. Run from the repo root:
--   luajit tests/run.lua      (or lua5.1 tests/run.lua)
-- Loads the PURE addon files the way WoW does (addonName, ns as varargs); no WoW API needed.

local PURE_FILES = {
    "Tradebook/Core/Namespace.lua",
    "Tradebook/Locales/enUS.lua",
    "Tradebook/Data/Professions.lua",
    "Tradebook/Data/Camp.lua",
    "Tradebook/Data/SourceData.lua",
    "Tradebook/Data/SkillLevels.lua",
    "Tradebook/Data/Sources.lua",
    "Tradebook/Core/DB.lua",
    "Tradebook/Core/Characters.lua",
    "Tradebook/Core/Recipes.lua",
    "Tradebook/Core/Reagents.lua",
    "Tradebook/Core/Friends.lua",
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
        parts[#parts + 1] = ns.L.SKILLUP_COLORS[l.colour + 1] .. (l.untilSkill and (" until " .. l.untilSkill) or " now")
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

test("migration v3 clears old threshold mismatches", function()
    local db = ns.DB.Migrate({ version = 2, badThresholds = { [3852] = true } })
    eq(next(db.badThresholds), nil)
end)

test("vendor and drop names are capped with a count", function()
    local found
    for id, s in pairs(ns.SourceData) do
        if s.d and s.dn and s.dn > 3 then found = id break end
    end
    local lines = ns.Sources.Get(found)
    local text
    for _, l in ipairs(lines) do if l.text:find("^Drop") then text = l.text end end
    assert(text and text:find("more%)"), "drop line shows the remaining count: " .. tostring(text))
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
