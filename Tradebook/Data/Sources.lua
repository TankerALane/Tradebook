-- Data/Sources.lua
-- PURE. Reads the bundled LibProfessionDB data (Data/SourceData.lua): where a recipe is
-- learned, its required skill, and skill-up colors from thresholds. The Forever client
-- exposes no source text (Phase 0), so this is the only source information.
-- Phase 2 can add farming/vendor-price data here without touching the UI.

local _, ns = ...
local L = ns.L

local Sources = {}
ns.Sources = Sources

local MAX_NAMES = 3

local function npcNames(ids, total)
    local names = {}
    for _, id in ipairs(ids or {}) do
        local n = ns.SourceNames and ns.SourceNames[id]
        if n and #names < MAX_NAMES then names[#names + 1] = n end
    end
    local count = total or #(ids or {})
    local more = count - #names
    local text = table.concat(names, ", ")
    if more > 0 then text = text .. (text ~= "" and " " or "") .. L.SOURCE_MORE:format(more) end
    return text
end

-- Source lines for the details pane: { { text, right } }, or nil when unknown.
-- resolve (optional): { quest = fn(id) -> name, item = fn(id) -> name } for runtime lookups.
function Sources.Get(recipeID, resolve)
    local s = ns.SourceData and ns.SourceData[recipeID]
    if not s then return nil end
    resolve = resolve or {}
    local out = {}
    if s.a == 1 then out[#out + 1] = { text = L.SOURCE_AUTO } end
    if s.t then
        out[#out + 1] = { text = L.SOURCE_TRAINER, right = L.SOURCE_LOCATIONS:format(s.tn or #s.t) }
    end
    if s.v then out[#out + 1] = { text = L.SOURCE_VENDOR .. ": " .. npcNames(s.v, s.vn) } end
    if s.d then out[#out + 1] = { text = L.SOURCE_DROP .. ": " .. npcNames(s.d, s.dn) } end
    for _, q in ipairs(s.q or {}) do
        local name = resolve.quest and resolve.quest(q)
        out[#out + 1] = { text = L.SOURCE_QUEST .. ": " .. (name or ("#" .. q)) }
    end
    for _, item in ipairs(s.c or {}) do
        local name = resolve.item and resolve.item(item)
        out[#out + 1] = { text = L.SOURCE_CONTAINER .. ": " .. (name or ("item " .. item)) }
    end
    if #out == 0 then return nil end
    return out, s.b == true
end

-- Required skill to learn (LibProfessionDB, Data/SourceData.lua), and whether it was
-- borrowed from Vanilla.
function Sources.Required(recipeID)
    local r = ns.RecipeRequired and ns.RecipeRequired[recipeID]
    if not r then return nil end
    return r[1], r[2] == true
end

-- Skill-up thresholds from the game itself (Data/SkillLevels.lua, regenerated per build by
-- scripts/update_game_data.py): { skillLine, yellow, green, grey }. Scans still flag any
-- recipe where they disagree with the game (db.badThresholds).
local function levels(recipeID)
    local lv = ns.RecipeLevels and ns.RecipeLevels[recipeID]
    if not lv or lv[4] == 0 then return nil end
    return lv
end
Sources.Levels = levels

-- Skill-up color for a rank: 0 orange, 1 yellow, 2 green, 3 grey.
function Sources.Difficulty(recipeID, rank)
    local lv = levels(recipeID)
    if not lv or not rank then return nil end
    if rank >= lv[4] then return 3 end
    if rank >= lv[3] then return 2 end
    if rank >= lv[2] then return 1 end
    return 0
end

-- Thresholds { orange, yellow, green, grey } (skill where each colour starts), or nil.
-- Orange starts at the skill needed to learn the recipe (or 1 when unknown).
function Sources.Thresholds(recipeID)
    local lv = levels(recipeID)
    if not lv then return nil end
    local orange = math.min(Sources.Required(recipeID) or 1, lv[2])
    return { orange, lv[2], lv[3], lv[4] }
end
