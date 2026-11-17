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

DB.VERSION = 5

-- The window's scale 1.0 is drawn at this size (1.25x the native frame), per user preference.
DB.BASE_SCALE = 1.25

DB.DEFAULTS = {
    settings = {
        replaceDefault = true,
        scale = 1,
        staleDays = 30,
        showHidden = false,
        debug = false,
        minimap = { hide = false },
        window = { width = 900, height = 560 },
        campView = "profession",
        lastTab = nil,
        filters = { learned = true, unlearned = false, unlearnedNearest = false, unlearnedLearnable = false,
            unlearnedTrainer = false, unlearnedRecipe = false, unlearnedVendor = false, unlearnedDrop = false,
            unlearnedNoFavor = false, -- hide recipes only bought with Merchant's Favor
            haveMats = false, skillup = false,
            skillupColors = { true, true, true } }, -- orange, yellow, green
        crossFaction = false, -- combine Alliance and Horde characters (Characters.SameSide)
        listOrder = "game", -- recipe list order: "game" (like the default window) | "az"
        listProfit = "off", -- recipe list profit column: "off" | "vendor" | "auction" | "disenchant"
        deTooltip = true, -- item tooltips say what an item disenchants into (Core/Disenchant.lua)
        deCompact = true, -- ...in one line, with the details while Shift is held
        collapsed = {},
        browse = {}, -- [skillLine] = true: list every recipe of a profession nobody has
        tabLayout = {}, -- tab order and hidden tabs, shared or per character (Core/TabLayout.lua)
        netShare = true, -- share NPC data with other Tradebook users in game (Core/Net.lua)
    },
    characters = {},
    trainers = {}, -- [npcID] = what a trainer teaches, read from its window (Core/Trainers.lua)
    vendors = {}, -- [npcID] = recipes a vendor sells, read from its window (Core/Merchants.lua)
    heard = {}, -- NPC data other players shared in game (Core/Net.lua)
    disenchants = {}, -- [bandID] = what your disenchants gave (Core/Disenchant.lua)
    netSent = {}, -- ["vendor:npcID"] = { seen, at }: your scans already announced
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
    [4] = function(db)
        -- The first in-game sharing build (never released) took its own echoed messages for
        -- another player's: what it "heard" is your own scans again. Forget it.
        db.heard = {}
        return db
    end,
    [5] = function(db)
        -- "Show gathering profession tabs" off is now those tabs hidden in the tab layout.
        local s = db.settings
        if s and s.showGathering == false then
            s.tabLayout = s.tabLayout or {}
            s.tabLayout.shared = s.tabLayout.shared or { order = {}, hidden = {} }
            local hidden = s.tabLayout.shared.hidden or {}
            s.tabLayout.shared.hidden = hidden
            for _, p in ipairs(ns.Professions and ns.Professions.list or {}) do
                if p.gathering then hidden[p.id] = true end
            end
        end
        if s then s.showGathering = nil end
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
