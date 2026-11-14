-- Core/DB.lua
-- PURE. Shape of TradebookDB, defaults and versioned migrations.
--
-- TradebookDB = {
--   version = n,
--   settings = { ... },                       -- see DB.DEFAULTS.settings
--   characters = { [key] = character },       -- see Characters.lua
--   account = { bank = {[itemID]=count}, bankAt = time },
--   recipes = { [recipeID] = recipe },        -- shared static recipe cache, see Recipes.lua
--   categories = { [categoryID] = { n = name, p = parentID } },
--   campCategories = { [categoryID] = skillLineID },
--   favorites = { [recipeID] = true },
--   pinned = { [recipeID] = quantity },
-- }

local _, ns = ...

local DB = {}
ns.DB = DB

DB.VERSION = 3

-- The window's scale 1.0 is drawn at this size (1.25x the native frame), per user preference.
DB.BASE_SCALE = 1.25

DB.DEFAULTS = {
    settings = {
        replaceDefault = true,
        scale = 1,
        showGathering = true,
        staleDays = 30,
        showHidden = false,
        debug = false,
        minimap = { hide = false },
        window = { width = 900, height = 560 },
        campView = "profession",
        lastTab = nil,
        filters = { learned = true, unlearned = false, unlearnedNearest = false, unlearnedLearnable = false,
            unlearnedTrainer = false, unlearnedRecipe = false, haveMats = false, skillup = false,
            skillupColors = { true, true, true } }, -- orange, yellow, green
        collapsed = {},
        browse = {}, -- [skillLine] = true: list every recipe of a profession nobody has
    },
    characters = {},
    trainers = {}, -- [npcID] = what a trainer teaches, read from its window (Core/Trainers.lua)
    vendors = {}, -- [npcID] = recipes a vendor sells, read from its window (Core/Merchants.lua)
    account = { bank = {} },
    recipes = {},
    categories = {},
    campCategories = {},
    badThresholds = {}, -- [recipeID] = true when bundled skill-up thresholds disagreed with the game
    favorites = {},
    pinned = {},
}

-- Ordered migrations: MIGRATIONS[n] upgrades a version n-1 table to version n.
-- Add new steps here; never edit an old one once released.
DB.MIGRATIONS = {
    [1] = function(db)
        -- First version: nothing to convert, defaults are filled below.
        return db
    end,
    [2] = function(db)
        -- Scale is now relative to BASE_SCALE (old 1.25 becomes the new 1.0).
        local s = db.settings
        if s and tonumber(s.scale) then
            s.scale = math.floor(s.scale / DB.BASE_SCALE * 20 + 0.5) / 20
        end
        return db
    end,
    [3] = function(db)
        -- Skill-up thresholds now come from the game's own table; forget mismatches
        -- recorded against the old LibProfessionDB thresholds.
        db.badThresholds = {}
        return db
    end,
}

-- Bring any saved table (or nil) up to the current version without losing data.
function DB.Migrate(db)
    if type(db) ~= "table" then db = {} end
    local from = tonumber(db.version) or 0
    if from > DB.VERSION then
        -- Saved by a newer Tradebook: keep it as is, only fill gaps.
        ns.util.Fill(db, DB.DEFAULTS)
        db.newerVersion = from
        return db
    end
    for v = from + 1, DB.VERSION do
        local step = DB.MIGRATIONS[v]
        if step then db = step(db) or db end
        db.version = v
    end
    ns.util.Fill(db, DB.DEFAULTS)
    db.version = DB.VERSION
    return db
end
