-- Data/Disenchant.lua
-- PURE. What disenchanting gives, by item quality and item level: the CLASSIC table, from
-- the Warcraft Wiki "Disenchanting tables" page (https://warcraft.wiki.gg/wiki/Disenchanting_tables,
-- CC BY-SA 4.0; pre-Battle for Azeroth tables, rows up to item level 65). Cross-checked
-- (2026-11-16) against the classic server databases cmangos classic-db and vmangos: the green
-- and purple rows match both exactly; the blue 56+ row (Nexus Crystal chance) differs between
-- every source, so it's marked disputed.
--
-- NOT confirmed for WoW Forever: what a disenchant gives is decided by the server and isn't in
-- the game data. Forever's own bands (which items can be disenchanted at all) are in
-- Data/DisenchantBands.lua; Forever adds blue bands at item level 5-20 that classic doesn't
-- have (given the classic blue 1-25 row here). Core/Disenchant.lua shows this table marked as
-- classic until disenchants recorded in game confirm a band, then shows what was seen.
--
-- Rows: { minLevel, maxLevel, { { itemID, chance (0-1), minCount, maxCount }, ... } }.
-- The row ranges are stretched to cover Forever's bands (green 61-99: the classic 61-65 row).
-- Material item IDs checked against Forever's ItemSparse table.

local _, ns = ...

local STRANGE, SOUL, VISION, DREAM, ILLUSION = 10940, 11083, 11137, 11176, 16204
local LMAGIC, GMAGIC, LASTRAL, GASTRAL = 10938, 10939, 10998, 11082
local LMYSTIC, GMYSTIC, LNETHER, GNETHER, LETERNAL, GETERNAL = 11134, 11135, 11174, 11175, 16202, 16203
local SGLIMMER, LGLIMMER, SGLOW, LGLOW, SRADIANT, LRADIANT = 10978, 11084, 11138, 11139, 11177, 11178
local SBRILLIANT, LBRILLIANT, NEXUS = 14343, 14344, 20725

-- Bands whose results have been seen in WoW Forever by an outside source, by Forever band ID
-- (Data/DisenchantBands.lua). Wowhead's WoW Forever loot counts for green armor crafts (via
-- timesaver.gg's Forever enchanting tool, checked 2026-11-16) fit the classic rows below for
-- these bands. Nothing is copied from it: it only marks the classic row as seen in Forever.
ns.DisenchantForeverSeen = {
    [4] = "Wowhead", -- green armor 5-15
    [5] = "Wowhead", -- green armor 16-20
    [13] = "Wowhead", -- green armor 26-30
}

ns.DisenchantClassic = {
    -- Uncommon (green) armor (item class 4).
    armor = {
        { 5, 15, { { STRANGE, 0.80, 1, 2 }, { LMAGIC, 0.20, 1, 2 } } },
        { 16, 20, { { STRANGE, 0.75, 2, 3 }, { GMAGIC, 0.20, 1, 2 }, { SGLIMMER, 0.05, 1, 1 } } },
        { 21, 25, { { STRANGE, 0.75, 4, 6 }, { LASTRAL, 0.15, 1, 2 }, { SGLIMMER, 0.10, 1, 1 } } },
        { 26, 30, { { SOUL, 0.75, 1, 2 }, { GASTRAL, 0.20, 1, 2 }, { LGLIMMER, 0.05, 1, 1 } } },
        { 31, 35, { { SOUL, 0.75, 2, 5 }, { LMYSTIC, 0.20, 1, 2 }, { SGLOW, 0.05, 1, 1 } } },
        { 36, 40, { { VISION, 0.75, 1, 2 }, { GMYSTIC, 0.20, 1, 2 }, { LGLOW, 0.05, 1, 1 } } },
        { 41, 45, { { VISION, 0.75, 2, 5 }, { LNETHER, 0.20, 1, 2 }, { SRADIANT, 0.05, 1, 1 } } },
        { 46, 50, { { DREAM, 0.75, 1, 2 }, { GNETHER, 0.20, 1, 2 }, { LRADIANT, 0.05, 1, 1 } } },
        { 51, 55, { { DREAM, 0.75, 2, 5 }, { LETERNAL, 0.20, 1, 2 }, { SBRILLIANT, 0.05, 1, 1 } } },
        { 56, 60, { { ILLUSION, 0.75, 1, 2 }, { GETERNAL, 0.20, 1, 2 }, { LBRILLIANT, 0.05, 1, 1 } } },
        { 61, 99, { { ILLUSION, 0.75, 2, 5 }, { GETERNAL, 0.20, 2, 3 }, { LBRILLIANT, 0.05, 1, 1 } } },
    },
    -- Uncommon (green) weapons (item class 2).
    weapon = {
        { 5, 15, { { STRANGE, 0.20, 1, 2 }, { LMAGIC, 0.80, 1, 2 } } },
        { 16, 20, { { STRANGE, 0.20, 2, 3 }, { GMAGIC, 0.75, 1, 2 }, { SGLIMMER, 0.05, 1, 1 } } },
        { 21, 25, { { STRANGE, 0.15, 4, 6 }, { LASTRAL, 0.75, 1, 2 }, { SGLIMMER, 0.10, 1, 1 } } },
        { 26, 30, { { SOUL, 0.20, 1, 2 }, { GASTRAL, 0.75, 1, 2 }, { LGLIMMER, 0.05, 1, 1 } } },
        { 31, 35, { { SOUL, 0.20, 2, 5 }, { LMYSTIC, 0.75, 1, 2 }, { SGLOW, 0.05, 1, 1 } } },
        { 36, 40, { { VISION, 0.20, 1, 2 }, { GMYSTIC, 0.75, 1, 2 }, { LGLOW, 0.05, 1, 1 } } },
        { 41, 45, { { VISION, 0.20, 2, 5 }, { LNETHER, 0.75, 1, 2 }, { SRADIANT, 0.05, 1, 1 } } },
        { 46, 50, { { DREAM, 0.20, 1, 2 }, { GNETHER, 0.75, 1, 2 }, { LRADIANT, 0.05, 1, 1 } } },
        { 51, 55, { { DREAM, 0.22, 2, 5 }, { LETERNAL, 0.75, 1, 2 }, { SBRILLIANT, 0.03, 1, 1 } } },
        { 56, 60, { { ILLUSION, 0.22, 1, 2 }, { GETERNAL, 0.75, 1, 2 }, { LBRILLIANT, 0.03, 1, 1 } } },
        { 61, 99, { { ILLUSION, 0.22, 2, 5 }, { GETERNAL, 0.75, 2, 3 }, { LBRILLIANT, 0.03, 1, 1 } } },
    },
    -- Rare (blue), armor and weapons alike.
    rare = {
        { 5, 25, { { SGLIMMER, 1, 1, 1 } } },
        { 26, 30, { { LGLIMMER, 1, 1, 1 } } },
        { 31, 35, { { SGLOW, 1, 1, 1 } } },
        { 36, 40, { { LGLOW, 1, 1, 1 } } },
        { 41, 45, { { SRADIANT, 1, 1, 1 } } },
        { 46, 50, { { LRADIANT, 1, 1, 1 } } },
        { 51, 55, { { SBRILLIANT, 1, 1, 1 } } },
        -- Disputed: Wiki 99.5% / 0.5% Nexus, vmangos 99% / 1% (from item level 60), cmangos no
        -- Nexus below 66.
        { 56, 99, { { LBRILLIANT, 0.995, 1, 1 }, { NEXUS, 0.005, 1, 1 } }, "disputed" },
    },
    -- Epic (purple), armor and weapons alike.
    epic = {
        { 40, 45, { { SRADIANT, 1, 2, 4 } } },
        { 46, 50, { { LRADIANT, 1, 2, 4 } } },
        { 51, 55, { { SBRILLIANT, 1, 2, 4 } } },
        { 56, 60, { { NEXUS, 1, 1, 1 } } },
        { 61, 99, { { NEXUS, 1, 1, 2 } } },
    },
}
