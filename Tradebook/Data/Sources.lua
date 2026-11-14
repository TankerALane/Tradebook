-- Data/Sources.lua
-- PURE. Reads the bundled LibProfessionDB data (Data/SourceData.lua): where a recipe is
-- learned, its required skill, and skill-up colors from thresholds, with recipe vendors
-- replaced by the Forever-checked data in Data/RecipeVendors.lua. The Forever client exposes
-- no source text (Phase 0), so this is the only source information.

local _, ns = ...
local L = ns.L

local Sources = {}
ns.Sources = Sources

local MAX_NAMES = 3

local function npcName(id)
    return (ns.RecipeVendorNames and ns.RecipeVendorNames[id]) or (ns.SourceNames and ns.SourceNames[id])
end

local function npcNames(ids, total)
    local names = {}
    for _, id in ipairs(ids or {}) do
        local n = npcName(id)
        if n and #names < MAX_NAMES then names[#names + 1] = n end
    end
    local count = total or #(ids or {})
    local more = count - #names
    local text = table.concat(names, ", ")
    if more > 0 then text = text .. (text ~= "" and " " or "") .. L.SOURCE_MORE:format(more) end
    return text
end

-- Where a recipe comes from: the classic data (Data/SourceData.lua), with the vendors (and,
-- where no vendor sells it, drops and quests) replaced by the Forever-checked data in
-- Data/RecipeVendors.lua. Returns { t, tn, a, c, v, u, vn, d, dn, q, x, b, checked } or nil:
--   v vendors (confirmed when checked), u unconfirmed vendors (one source), x 1 not in Forever
--   yet / 2 sources disagree, b the remaining classic parts are unconfirmed, checked = the
--   vendors were checked for Forever.
function Sources.Raw(recipeID)
    local s = ns.SourceData and ns.SourceData[recipeID]
    local o = ns.RecipeVendors and ns.RecipeVendors[recipeID]
    if not o then return s end
    s = s or {}
    local out = { t = s.t, tn = s.tn, a = s.a, c = s.c, checked = true, x = o.x, v = o.v, u = o.u }
    local replaced = (o.d or o.q) ~= nil
    if replaced then
        out.d, out.q = o.d, o.q
    else
        out.d, out.dn, out.q = s.d, s.dn, s.q
    end
    -- What's still classic (and unconfirmed): trainers, containers, and drops/quests the
    -- check didn't replace.
    out.b = s.b == true and (out.t ~= nil or out.c ~= nil or (not replaced and (out.d or out.q) ~= nil))
    return out
end

-- Vendors that sell a recipe: confirmed { npcID }, unconfirmed { npcID } (either may be empty).
function Sources.Vendors(recipeID)
    local s = Sources.Raw(recipeID)
    if not s then return {}, {} end
    if s.checked then return s.v or {}, s.u or {} end
    return {}, s.v or {} -- not checked for Forever: classic data, unconfirmed
end

-- Source lines for the details pane: { { text, right, grey } }, or nil when unknown.
-- resolve (optional): { quest = fn(id) -> name, item = fn(id) -> name } for runtime lookups.
-- Second result: the classic parts are unconfirmed. Third: the vendors were checked for Forever.
function Sources.Get(recipeID, resolve)
    local s = Sources.Raw(recipeID)
    if not s then return nil end
    resolve = resolve or {}
    local out = {}
    if s.x == 1 then out[#out + 1] = { text = L.SOURCE_NOT_YET, grey = true } end
    if s.x == 2 then out[#out + 1] = { text = L.SOURCE_DISPUTED, grey = true } end
    if s.a == 1 then out[#out + 1] = { text = L.SOURCE_AUTO } end
    if s.t then
        out[#out + 1] = { text = L.SOURCE_TRAINER, right = L.SOURCE_LOCATIONS:format(s.tn or #s.t) }
    end
    if s.v then
        out[#out + 1] = { text = L.SOURCE_VENDOR .. ": " .. npcNames(s.v, not s.checked and s.vn or nil) }
    end
    if s.u then
        out[#out + 1] = { text = L.SOURCE_VENDOR_UNCONFIRMED .. ": " .. npcNames(s.u) }
    end
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
    return out, s.b == true, s.checked == true
end

-- Required skill to learn (LibProfessionDB, Data/SourceData.lua), and whether it was
-- borrowed from Vanilla.
function Sources.Required(recipeID)
    local r = ns.RecipeRequired and ns.RecipeRequired[recipeID]
    if not r then return nil end
    return r[1], r[2] == true
end

-- How a recipe is learned: { trainer = bool, recipe = bool (a recipe item: vendor, drop,
-- quest or container), auto = bool (learned with the profession) }, or nil when unknown.
function Sources.Kinds(recipeID)
    local s = Sources.Raw(recipeID)
    if not s then return nil end
    return { trainer = s.t ~= nil, recipe = (s.v or s.u or s.d or s.q or s.c) ~= nil, auto = s.a == 1 }
end

-- Can a character at `rank` learn this recipe now? true / false, or nil when the required
-- skill isn't known.
function Sources.Learnable(recipeID, rank)
    local required = Sources.Required(recipeID)
    if not required or not rank then return nil end
    return rank >= required
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
    local t = Sources.Thresholds(recipeID)
    if not t or not rank then return nil end
    if rank >= t[3] then return 3 end
    if rank >= t[2] then return 2 end
    if rank >= t[1] then return 1 end
    return 0
end

-- Thresholds { yellow, green, grey } (skill where each colour starts), or nil.
-- Orange is everything below yellow. (The "skill to learn" value is NOT used here: it's
-- borrowed from classic and often wrong, e.g. 130 for a recipe learned at 115.)
function Sources.Thresholds(recipeID)
    local lv = levels(recipeID)
    if not lv then return nil end
    -- Defensive: keep yellow <= green <= grey (the generator already clamps).
    local grey = lv[4]
    local green = math.min(lv[3], grey)
    return { math.min(lv[2], green), green, grey }
end

-- Skill-up lines for the details pane, from the colour the character is in now:
-- { { colour = 0..2, untilSkill = n } ... } meaning "<colour> until <n>". Colours whose
-- range is already behind the rank or empty are skipped; grey is never listed.
-- current: the colour as the game reports it (0 orange .. 3 grey), or nil if unknown.
-- When there are no thresholds, returns just { { colour = current } } (shown as "<colour> now").
-- ignoreThresholds: the game disagreed with them for this recipe (db.badThresholds).
function Sources.SkillUpLines(recipeID, rank, current, ignoreThresholds)
    local t = not ignoreThresholds and Sources.Thresholds(recipeID) or nil
    if current == nil and t and rank then current = Sources.Difficulty(recipeID, rank) end
    if current == nil or current >= 3 then return {} end
    if not t then return { { colour = current } } end
    local out = {}
    for colour = current, 2 do
        local stop = t[colour + 1]                 -- where the next colour starts
        local start = colour == 0 and 0 or t[colour] -- where this colour starts
        if stop > start and (not rank or stop > rank) then
            out[#out + 1] = { colour = colour, untilSkill = stop }
        end
    end
    if #out == 0 then out[1] = { colour = current } end
    return out
end
