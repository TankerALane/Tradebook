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
        or (ns.Merchants and ns.Merchants.Name(id))
end

-- decorate(id, name) -> name with a note, optional.
local function npcNames(ids, total, decorate)
    local names = {}
    for _, id in ipairs(ids or {}) do
        local n = npcName(id)
        if n and decorate then n = decorate(id, n) end
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

-- PURE. Combine the bundled vendors with what you've seen in vendor windows.
-- seen: { [npcID] = { ever, limited } } of vendors seen selling it (Merchants.ForRecipe);
-- visit(npcID) -> { sells, ever, limited } or nil (never visited). A vendor seen selling it is
-- confirmed; one visited whose window didn't list it (and never did) is kept but noted, since
-- a limited recipe that's sold out isn't listed until it restocks.
-- Returns confirmed, unconfirmed, notes { [npcID] = { limited = bool, missing = bool } }.
function Sources.MergeSeen(confirmed, unconfirmed, seen, visit)
    local conf, unconf, notes = {}, {}, {}
    for _, npc in ipairs(confirmed) do conf[#conf + 1] = npc end
    for _, npc in ipairs(unconfirmed) do
        if seen and seen[npc] then conf[#conf + 1] = npc else unconf[#unconf + 1] = npc end
    end
    local listed = {}
    for _, npc in ipairs(conf) do listed[npc] = true end
    local extra = {}
    for npc in pairs(seen or {}) do if not listed[npc] then extra[#extra + 1] = npc end end
    table.sort(extra)
    for _, npc in ipairs(extra) do conf[#conf + 1] = npc end
    for _, list in ipairs({ conf, unconf }) do
        for _, npc in ipairs(list) do
            local v = visit and visit(npc)
            local s = seen and seen[npc]
            notes[npc] = { limited = (s and s.limited) or (v and v.limited) or false,
                missing = v ~= nil and not v.sells and not v.ever }
        end
    end
    return conf, unconf, notes
end

-- Vendors that sell a recipe: confirmed { npcID }, unconfirmed { npcID } (either may be empty),
-- and notes { [npcID] = { limited, missing } } from vendor windows you've opened. dataOnly:
-- just the bundled data.
function Sources.Vendors(recipeID, dataOnly)
    local s = Sources.Raw(recipeID)
    local conf, unconf = {}, {}
    if s and s.checked then
        conf, unconf = s.v or {}, s.u or {}
    elseif s then
        unconf = s.v or {} -- not checked for Forever: classic data, unconfirmed
    end
    if dataOnly or not ns.Merchants then return conf, unconf, {} end
    return Sources.MergeSeen(conf, unconf, ns.Merchants.ForRecipe(recipeID),
        function(npc) return ns.Merchants.Visit(npc, recipeID) end)
end

-- Source lines for the details pane: { { text, right, grey } }, or nil when unknown.
-- resolve (optional): { quest = fn(id) -> name, item = fn(id) -> name } for runtime lookups.
-- Second result: the classic parts are unconfirmed. Third: the vendors were checked for Forever.
function Sources.Get(recipeID, resolve)
    local s = Sources.Raw(recipeID)
    if not s then return nil end
    resolve = resolve or {}
    local out = {}
    local conf, unconf, notes = Sources.Vendors(recipeID)
    -- Seen selling it in a vendor window beats "not in Forever yet" / "no vendor known".
    if #conf == 0 then
        if s.x == 1 then out[#out + 1] = { text = L.SOURCE_NOT_YET, grey = true } end
        if s.x == 2 then out[#out + 1] = { text = L.SOURCE_DISPUTED, grey = true } end
        if s.x == 3 and #unconf == 0 then out[#out + 1] = { text = L.SOURCE_NO_VENDOR, grey = true } end
    end
    local function decorate(id, name)
        local n = notes[id]
        if n and n.missing then return name .. " " .. L.SOURCE_NOT_IN_STOCK end
        if n and n.limited then return name .. " " .. L.SOURCE_LIMITED end
        return name
    end
    if s.a == 1 then out[#out + 1] = { text = L.SOURCE_AUTO } end
    if s.t then
        out[#out + 1] = { text = L.SOURCE_TRAINER, right = L.SOURCE_LOCATIONS:format(s.tn or #s.t) }
    end
    if #conf > 0 then
        out[#out + 1] = { text = L.SOURCE_VENDOR .. ": " .. npcNames(conf, nil, decorate) }
    end
    if #unconf > 0 then
        out[#out + 1] = { text = L.SOURCE_VENDOR_UNCONFIRMED .. ": "
            .. npcNames(unconf, not s.checked and s.vn or nil, decorate) }
    end
    -- Drops with chances are listed separately (Sources.Drops); otherwise the names.
    local o = ns.RecipeVendors and ns.RecipeVendors[recipeID]
    if s.d and not (o and o.dr) then out[#out + 1] = { text = L.SOURCE_DROP .. ": " .. npcNames(s.d, s.dn) } end
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
    if not r then
        -- New Forever recipes: the skill from the checked vendor data.
        local o = ns.RecipeVendors and ns.RecipeVendors[recipeID]
        if o and o.k then return o.k, false end
        return nil
    end
    return r[1], r[2] == true
end

-- NPCs that drop a recipe, with the drop chance in percent, highest first:
-- { { npcID, chance, name, areaID } } (Data/RecipeVendors.lua `dr`), or {}.
function Sources.Drops(recipeID)
    local o = ns.RecipeVendors and ns.RecipeVendors[recipeID]
    local out = {}
    for _, d in ipairs(o and o.dr or {}) do
        out[#out + 1] = { npcID = d[1], chance = d[2] / 100, name = npcName(d[1]),
            areaID = ns.RecipeNpcZones and ns.RecipeNpcZones[d[1]] }
    end
    return out
end

-- Items that teach a recipe (Data/RecipeItems.lua): { itemID, ... } (built once).
local itemsByRecipe
function Sources.RecipeItems(recipeID)
    if not itemsByRecipe then
        itemsByRecipe = {}
        for itemID, r in pairs(ns.RecipeItems or {}) do
            itemsByRecipe[r] = itemsByRecipe[r] or {}
            table.insert(itemsByRecipe[r], itemID)
        end
        for _, list in pairs(itemsByRecipe) do table.sort(list) end
    end
    return itemsByRecipe[recipeID] or {}
end

-- Can this recipe item be bought from other players (not soulbound on pickup)?
function Sources.Tradeable(itemID)
    return not (ns.RecipeItemBound and ns.RecipeItemBound[itemID])
end

-- Merchant's Favor camps: the reputation is the one for your faction.
local CAMP_FACTION = { Horde = 2587, Alliance = 2586 } -- Durotar Supply and Logistics / Azeroth Commerce Authority

-- What buying a recipe from its vendor needs: { favor = Merchant's Favor cost or nil,
-- factionID, standing (4 Friendly .. 7 Exalted) or nil }, or nil when nothing is known.
-- playerFaction: "Horde" / "Alliance" (for the supply camps' reputation).
function Sources.Purchase(recipeID, playerFaction)
    local o = ns.RecipeVendors and ns.RecipeVendors[recipeID]
    if not o or not (o.fv or o.cr or o.rf) then return nil end
    local out = { favor = o.fv }
    if o.rf then
        out.factionID, out.standing = o.rf[1], o.rf[2]
    elseif o.cr then
        out.factionID, out.standing = CAMP_FACTION[playerFaction] or CAMP_FACTION.Horde, o.cr
        out.camp = true
    end
    return out
end

-- English name of a faction in the data (ns.RecipeFactionNames), or nil.
function Sources.FactionName(id)
    return ns.RecipeFactionNames and ns.RecipeFactionNames[id]
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
