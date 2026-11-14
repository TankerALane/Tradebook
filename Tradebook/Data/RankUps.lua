-- Data/RankUps.lua
-- PURE. How a character trains the next profession rank.
--
-- Ranks: you can train the next rank 25 points before your cap (50 for Journeyman, 125 for
-- Expert, 200 for Artisan). Character levels confirmed in game (Forever 1.60.1): Apprentice
-- none, Journeyman 10, Expert 20, Artisan 35, the same for every profession.
--
-- Most ranks come from a trainer. The exceptions (from classic, checked against Forever's
-- item data where a book is involved; see docs/DATA.md):
--   Expert Cooking / Fishing / First Aid: a book sold by vendors (or the auction house).
--   Artisan Fishing / First Aid: a quest.

local _, ns = ...

local RankUps = {}
ns.RankUps = RankUps

-- cap -> the rank trained next, the skill it can be trained at, and the character level.
RankUps.byCap = {
    [75] = { rank = "Journeyman", skill = 50, level = 10, cap = 150 },
    [150] = { rank = "Expert", skill = 125, level = 20, cap = 225 },
    [225] = { rank = "Artisan", skill = 200, level = 35, cap = 300 },
}

-- Trainers that teach a rank also teach recipes needing at least this much skill
-- (used to pick them from the recipe source data: an Apprentice-only trainer teaches
-- nothing above 75, a Journeyman one nothing above 150, and so on).
RankUps.trainerMinRecipe = { Journeyman = 80, Expert = 155, Artisan = 230 }

-- Books: item IDs and requirements from Forever's ItemSparse (build 1.60.1.70938).
-- Quests: looked up in QuestieDB by name (IDs differ between factions).
RankUps.special = {
    [185] = { -- Cooking
        Expert = { book = 16072, bookSkill = 125 },
    },
    [356] = { -- Fishing
        Expert = { book = 16083, bookSkill = 125, bookLevel = 20 },
        Artisan = { quest = "Nat Pagle, Angler Extreme" },
    },
    [129] = { -- First Aid
        Expert = { book = 16084, bookSkill = 125 },
        Artisan = { quest = "Triage" },
    },
}

-- The next rank for a profession { rank, max } (nil when there is none to train), with
-- how it is learned: { rank, skill, level, cap, book?, bookSkill?, bookLevel?, quest? }.
function RankUps.Next(skillLine, prof)
    local step = prof and RankUps.byCap[prof.max]
    if not step then return nil end
    local out = { rank = step.rank, skill = step.skill, level = step.level, cap = step.cap }
    local special = RankUps.special[skillLine] and RankUps.special[skillLine][step.rank]
    for k, v in pairs(special or {}) do out[k] = v end
    return out
end

-- Should the rank-up button show? When the next rank exists and the skill is high enough
-- to train it. (It goes away by itself once trained: the cap goes up.)
function RankUps.Ready(skillLine, prof)
    local nextRank = RankUps.Next(skillLine, prof)
    return nextRank ~= nil and (prof.rank or 0) >= nextRank.skill, nextRank
end

-- Requirement checks for display: { { text-key, need, have, ok } }.
-- level: the character's level (nil when unknown).
function RankUps.Requirements(nextRank, prof, level)
    local list = {
        { key = "skill", need = nextRank.skill, have = prof and prof.rank },
        { key = "level", need = nextRank.level, have = level },
    }
    for _, r in ipairs(list) do r.ok = r.have ~= nil and r.have >= r.need end
    return list
end
