-- Data/Specializations.lua
-- PURE. Profession specializations in WoW Forever.
--
-- Confirmed for Forever (researched 2026-11-13, docs/DATA.md):
--   Engineering: Gnomish or Goblin, from level 30 and Engineering 200, through a quest chain
--     (Wowhead, Icy Veins and one more Forever source agree on the requirement).
--   Leatherworking: Dragonscale, Elemental or Tribal (Wowhead, wow-professions, Icy Veins,
--     Overgear agree they exist).
-- Not confirmed for Forever by any source, so not shown: Blacksmithing and Tailoring.
--
-- The spells are in Forever's own SkillLineAbility data (1.60.1.70938), so a character's
-- specialization can be read from its spellbook. The quests (who gives them, where, what they
-- need) are read from QuestieDB at runtime: by ID for Engineering (IDs from Wowhead's Forever
-- guide, only shown when QuestieDB has them), by name for Leatherworking. Nothing about them
-- is typed in here, so the window only shows what the game database says.

local _, ns = ...

local Specializations = {}
ns.Specializations = Specializations

Specializations.list = {
    [202] = { -- Engineering
        level = 30, skill = 200,
        options = {
            { name = "Gnomish Engineering", spell = 20219,
                quests = { Alliance = { 3640, 3641 }, Horde = { 3642, 3643 } } },
            { name = "Goblin Engineering", spell = 20222,
                quests = { Alliance = { 3638, 3639 }, Horde = { 3638, 3639 } } },
        },
    },
    [165] = { -- Leatherworking
        options = {
            { name = "Dragonscale Leatherworking", spell = 10656, questName = "Dragonscale Leatherworking" },
            { name = "Elemental Leatherworking", spell = 10658, questName = "Elemental Leatherworking" },
            { name = "Tribal Leatherworking", spell = 10660, questName = "Tribal Leatherworking" },
        },
    },
}

function Specializations.For(skillLine)
    return Specializations.list[skillLine]
end

-- Every specialization spell: { [spellID] = skillLine } (for the spellbook scan).
function Specializations.Spells()
    local out = {}
    for skill, s in pairs(Specializations.list) do
        for _, o in ipairs(s.options) do out[o.spell] = skill end
    end
    return out
end

-- The option a character has chosen, from its saved specs ({ [skillLine] = spellID }).
function Specializations.Chosen(c, skillLine)
    local spell = c and c.specs and c.specs[skillLine]
    local s = Specializations.list[skillLine]
    if not (spell and s) then return nil end
    for _, o in ipairs(s.options) do
        if o.spell == spell then return o end
    end
    return nil
end
