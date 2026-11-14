-- Core/Questie.lua
-- Where to get a material, from QuestieDB when it is installed (optional dependency).
-- QuestieDB is GPLv3, so nothing of it is copied into Tradebook; it is only read at runtime
-- through its public API (LibQuestieDB, ItemDB/NpcDB/ObjectDB .Get) after a contract check.
--
--   Questie.WhereToGet(itemID) -> { vendors = {...}, drops = {...}, objects = {...} } or nil
--   each list: nearest first, { id, name, sub, minLevel, maxLevel, areaID, x, y, distance }

local _, ns = ...
local Compat, Locations = ns.Compat, ns.Locations

local Questie = {}
ns.Questie = Questie

local CONTRACT = 1     -- the QuestieDB API contract this was written against
local LIMIT = 3        -- nearest N shown per list
local MAX_CANDIDATES = 150
local CACHE_SECONDS = 15

local lib -- LibQuestieDB once checked
local checked = false

function Questie.Available()
    if checked then return lib ~= nil end
    checked = true
    local q = _G.LibQuestieDB
    if type(q) ~= "table" or type(q.RequireContract) ~= "function" then return false end
    local ok, fits = pcall(q.RequireContract, CONTRACT)
    if not (ok and fits) then
        ns.Debug("QuestieDB present but contract", CONTRACT, "not supported")
        return false
    end
    if not (q.Item and q.Npc and q.Item.Get and q.Npc.Get) then return false end
    lib = q
    return true
end

local function get(entity, id, key)
    if not entity or not entity.Get then return nil end
    local ok, value = pcall(entity.Get, id, key)
    return ok and value or nil
end

-- Player world position: { continent, x, y } or nil (e.g. in instances).
local function playerPosition()
    local map = Compat.Call("C_Map.GetBestMapForUnit", "player")
    if not map or Compat.IsSecret(map) then return nil end
    local pos = Compat.Call("C_Map.GetPlayerMapPosition", map, "player")
    if not pos then return nil end
    local continent, world = Compat.Call("C_Map.GetWorldPosFromMapPos", map, pos)
    if not continent or not world then return nil end
    local x, y = world:GetXY()
    return { continent = continent, x = x, y = y, map = map }
end

function Questie.DebugState()
    local here = playerPosition()
    return string.format("questie=%s position=%s", tostring(Questie.Available()),
        here and string.format("map %s continent %s (%.0f, %.0f)", tostring(here.map), tostring(here.continent), here.x, here.y)
        or "unknown")
end

local worldCache = {}
-- Zone (area) + 0-100 coordinates -> continent, world x, y.
local function toWorld(areaID, x, y)
    local map = ns.ZoneMaps and ns.ZoneMaps[areaID]
    if not map or not CreateVector2D then return nil end
    local key = areaID .. ":" .. x .. ":" .. y
    local c = worldCache[key]
    if c == nil then
        local continent, world = Compat.Call("C_Map.GetWorldPosFromMapPos", map, CreateVector2D(x / 100, y / 100))
        c = continent and world and { continent, world:GetXY() } or false
        worldCache[key] = c
    end
    if not c then return nil end
    return c[1], c[2], c[3]
end
Questie.ToWorld = toWorld

local function npcEntry(id, faction)
    local npc = lib.Npc
    local flag = get(npc, id, "friendlyToFaction")
    -- Vendors: QuestieDB uses nil for "hostile to both", so they must be friendly to you.
    if faction and (flag == nil or not Locations.FriendlyTo(flag, faction)) then return nil end
    local spawns = get(npc, id, "spawns")
    if type(spawns) ~= "table" then return nil end
    return { id = id, name = get(npc, id, "name") or ("NPC " .. id), sub = get(npc, id, "subName"),
        minLevel = get(npc, id, "minLevel"), maxLevel = get(npc, id, "maxLevel"), spawns = spawns }
end

local function objectEntry(id)
    local spawns = get(lib.Object, id, "spawns")
    if type(spawns) ~= "table" then return nil end
    return { id = id, name = get(lib.Object, id, "name") or ("Object " .. id), spawns = spawns }
end

local function nearest(ids, build, here)
    local entries = {}
    for i, id in ipairs(type(ids) == "table" and ids or {}) do
        if i > MAX_CANDIDATES then break end
        local e = build(id)
        if e then entries[#entries + 1] = e end
    end
    return Locations.Nearest(entries, here, toWorld, LIMIT)
end

local cache = {}

-- Has Questie got anything for this item? (cheap; used to decide whether to offer the section)
function Questie.HasSources(itemID)
    if not Questie.Available() or not itemID then return false end
    for _, key in ipairs({ "vendors", "npcDrops", "objectDrops" }) do
        local v = get(lib.Item, itemID, key)
        if type(v) == "table" and next(v) then return true end
    end
    return false
end

function Questie.WhereToGet(itemID)
    if not Questie.Available() or not itemID then return nil end
    local now = GetTime()
    local hit = cache[itemID]
    if hit and now - hit.at < CACHE_SECONDS then return hit.data end
    local here = playerPosition()
    local faction = Compat.Call("UnitFactionGroup", "player")
    local data = {
        vendors = nearest(get(lib.Item, itemID, "vendors"), function(id) return npcEntry(id, faction) end, here),
        drops = nearest(get(lib.Item, itemID, "npcDrops"), function(id) return npcEntry(id) end, here),
        objects = nearest(get(lib.Item, itemID, "objectDrops"), objectEntry, here),
        located = here ~= nil,
    }
    cache[itemID] = { at = now, data = data }
    return data
end

-- Zone name for an area ID.
function Questie.ZoneName(areaID)
    local map = ns.ZoneMaps and ns.ZoneMaps[areaID]
    local info = map and Compat.Call("C_Map.GetMapInfo", map)
    if info and info.name then return info.name end
    local name = Compat.Call("C_Map.GetAreaInfo", areaID)
    return name or ("Zone " .. tostring(areaID))
end

---------------------------------------------------------------------------
-- Where to learn a recipe (bundled LibProfessionDB trainer/vendor NPC ids + Questie spawns)
---------------------------------------------------------------------------

-- Player position, re-read at most every 2 s, plus a coarse "bucket" (40 yd grid) so the
-- distance caches below know when you have actually moved.
local hereCache = { at = -100 }
local function here()
    local now = GetTime()
    if now - hereCache.at > 2 then
        hereCache.at = now
        local p = playerPosition()
        hereCache.pos = p
        hereCache.bucket = p and string.format("%s:%d:%d", tostring(p.continent), math.floor(p.x / 40), math.floor(p.y / 40))
            or "none"
    end
    return hereCache.pos, hereCache.bucket
end

-- Nearest spawn of one NPC (friendly to you), cached per position bucket. Many recipes share
-- the same trainers, so this keeps a long "nearest first" list cheap.
local npcCache = {}
local function nearestNpc(id, faction)
    local pos, bucket = here()
    local hit = npcCache[id]
    if hit and hit.bucket == bucket then return hit.entry end
    local e = npcEntry(id, faction)
    local entry = e and Locations.Nearest({ e }, pos, toWorld, 1)[1] or false
    npcCache[id] = { bucket = bucket, entry = entry }
    return entry
end

local function nearestOf(ids, faction, kind)
    local out = {}
    for i, id in ipairs(type(ids) == "table" and ids or {}) do
        if i > MAX_CANDIDATES then break end
        local e = nearestNpc(id, faction)
        if e then
            local copy = { kind = kind }
            for k, v in pairs(e) do copy[k] = v end
            out[#out + 1] = copy
        end
    end
    table.sort(out, function(a, b)
        if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
        if a.distance and b.distance and a.distance ~= b.distance then return a.distance < b.distance end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

-- Nearest trainers and vendors that teach a recipe: { list = {...up to 3, mixed, nearest
-- first}, best = nearest entry or nil }, or nil when unknown. Entries carry kind =
-- "trainer" or "vendor".
function Questie.RecipeSources(recipeID)
    if not Questie.Available() then return nil end
    local s = ns.SourceData and ns.SourceData[recipeID]
    if not s or not (s.t or s.v) then return nil end
    local faction = Compat.Call("UnitFactionGroup", "player")
    local all = nearestOf(s.t, faction, "trainer")
    for _, e in ipairs(nearestOf(s.v, faction, "vendor")) do all[#all + 1] = e end
    table.sort(all, function(a, b)
        if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
        if a.distance and b.distance and a.distance ~= b.distance then return a.distance < b.distance end
        return tostring(a.name) < tostring(b.name)
    end)
    if #all == 0 then return nil end
    local list = {}
    for i = 1, math.min(LIMIT, #all) do list[i] = all[i] end
    return { list = list, best = all[1] }
end

---------------------------------------------------------------------------
-- Rank-ups: trainers for a rank, and rank-up quests
---------------------------------------------------------------------------

local function sortByDistance(list)
    table.sort(list, function(a, b)
        if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
        if a.distance and b.distance and a.distance ~= b.distance then return a.distance < b.distance end
        return tostring(a.name) < tostring(b.name)
    end)
end

-- Trainer NPC IDs for a profession that teach recipes needing at least `minRecipe` skill
-- (bundled recipe source data). Cached per profession and level.
local trainerIDs = {}
local function trainersFromRecipes(skillLine, minRecipe)
    local key = skillLine .. ":" .. minRecipe
    if trainerIDs[key] then return trainerIDs[key] end
    local seen, ids = {}, {}
    for recipeID, s in pairs(ns.SourceData or {}) do
        local lv = s.t and ns.RecipeLevels and ns.RecipeLevels[recipeID]
        local required = lv and lv[1] == skillLine and ns.Sources.Required(recipeID)
        if required and required >= minRecipe then
            for _, id in ipairs(s.t) do
                if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
            end
        end
    end
    trainerIDs[key] = ids
    return ids
end

-- Fallback for professions without trainer data (Herbalism, Skinning): NPCs whose title
-- mentions the profession and "Trainer" (one pass over QuestieDB's NPCs, cached).
local titleIDs = {}
local function trainersByTitle(word)
    if titleIDs[word] then return titleIDs[word] end
    local ids = {}
    local ok, all = pcall(lib.Npc.GetAllIds)
    if ok and type(all) == "table" then
        for _, id in ipairs(all) do
            local sub = get(lib.Npc, id, "subName")
            if type(sub) == "string" and sub:find(word, 1, true) and sub:find("Trainer", 1, true) then
                ids[#ids + 1] = id
            end
        end
    end
    titleIDs[word] = ids
    return ids
end

-- NPC IDs for a list of { id?, name } (Data/RankTrainers.lua): the given ID, or every
-- QuestieDB NPC with that exact name.
local nameIDs = {}
local function idsOf(list)
    local ids = {}
    for _, t in ipairs(list) do
        if t.id then
            ids[#ids + 1] = t.id
        else
            if nameIDs[t.name] == nil then
                local ok, found = pcall(lib.Npc.IdsByName, t.name)
                nameIDs[t.name] = ok and type(found) == "table" and found or false
            end
            for _, id in ipairs(nameIDs[t.name] or {}) do ids[#ids + 1] = id end
        end
    end
    return ids
end

-- Nearest trainers (friendly to `faction`) that teach `rank` of a profession: up to LIMIT
-- entries, nearest first. Each has confirmed = true when the trainer is known to teach it
-- (researched list, or its window read in game); false for the fallback guess.
function Questie.RankTrainers(skillLine, rank, faction)
    if not Questie.Available() then return {} end
    local listed, known = ns.RankTrainers.For(skillLine, rank)
    local ids, sure, seen = {}, {}, {}
    local function add(id, certain)
        if seen[id] or ns.Trainers.Teaches(id, rank) == false then return end
        seen[id] = true
        ids[#ids + 1] = id
        sure[id] = certain
    end
    -- Read in game: certain.
    for id, t in pairs(ns.db.trainers or {}) do
        if t.skill == skillLine and t.ranks[rank] then add(id, true) end
    end
    if known then
        for _, id in ipairs(idsOf(listed)) do add(id, true) end
    elseif ns.RankTrainers.journeymanFromAny[skillLine] and rank == "Journeyman" then
        -- Every Cooking / Fishing / First Aid trainer teaches Journeyman.
        local p = ns.Professions.Get(skillLine)
        for _, id in ipairs(p and trainersByTitle(p.name) or {}) do add(id, true) end
    else
        -- No researched list: a guess from the recipes trainers teach.
        for _, id in ipairs(trainersFromRecipes(skillLine, ns.RankUps.trainerMinRecipe[rank] or 0)) do add(id, false) end
    end
    local all = nearestOf(ids, faction, "trainer")
    local out = {}
    for i = 1, math.min(LIMIT, #all) do
        out[i] = all[i]
        out[i].confirmed = sure[all[i].id] == true
    end
    return out
end

-- Race masks for the two factions (classic races).
local ALLIANCE_RACES = 1 + 4 + 8 + 64   -- Human, Dwarf, Night Elf, Gnome
local HORDE_RACES = 2 + 16 + 32 + 128   -- Orc, Undead, Tauren, Troll
local function forFaction(races, faction)
    if not races or races == 0 then return true end
    local mask = faction == "Alliance" and ALLIANCE_RACES or faction == "Horde" and HORDE_RACES or nil
    if not mask then return true end
    -- bit.band without the bit library: test each faction race bit.
    for b = 0, 7 do
        local bitValue = 2 ^ b
        if math.floor(races / bitValue) % 2 == 1 and math.floor(mask / bitValue) % 2 == 1 then return true end
    end
    return false
end

-- One quest from QuestieDB for `faction`:
-- { id, name, givers = { nearest NPC entries }, level, skill = { skillLine, value },
--   rep = { factionID, value }, prereqs = { { id, name } }, next = { id, name } } or nil when
-- QuestieDB doesn't have it (or it's for the other faction).
local function questInfo(id, faction)
    if not (lib.Quest and get(lib.Quest, id, "name")) then return nil end
    if not forFaction(get(lib.Quest, id, "requiredRaces"), faction) then return nil end
    local started = get(lib.Quest, id, "startedBy")
    local givers = nearestOf(type(started) == "table" and started[1] or nil, faction, "quest")
    sortByDistance(givers)
    local prereqs = {}
    for _, key in ipairs({ "preQuestSingle", "preQuestGroup" }) do
        for _, q in ipairs(get(lib.Quest, id, key) or {}) do
            prereqs[#prereqs + 1] = { id = q, name = get(lib.Quest, q, "name") or ("#" .. q) }
        end
    end
    local skill = get(lib.Quest, id, "requiredSkill")
    local rep = get(lib.Quest, id, "requiredMinRep")
    local nextID = get(lib.Quest, id, "nextQuestInChain")
    return {
        id = id, name = get(lib.Quest, id, "name"),
        givers = { givers[1], givers[2], givers[3] },
        level = get(lib.Quest, id, "requiredLevel"),
        skill = type(skill) == "table" and { skill[1], skill[2] } or nil,
        rep = type(rep) == "table" and { rep[1], rep[2] } or nil,
        prereqs = prereqs,
        next = nextID and nextID ~= 0 and { id = nextID, name = get(lib.Quest, nextID, "name") or ("#" .. nextID) } or nil,
    }
end

function Questie.QuestInfo(id, faction)
    if not Questie.Available() or not id then return nil end
    return questInfo(id, faction)
end

-- A quest by name for `faction` (see questInfo), e.g. a rank-up quest.
function Questie.RankQuest(name, faction)
    if not Questie.Available() or not lib.Quest then return nil end
    local ok, ids = pcall(lib.Quest.IdsByName, name)
    if not ok or type(ids) ~= "table" then return nil end
    for _, id in ipairs(ids) do
        local q = questInfo(id, faction)
        if q then return q end
    end
    return nil
end

-- Clear distances when the player moves to another zone.
function Questie.Start()
    ns.On("ZONE_CHANGED_NEW_AREA", function() cache = {} end)
end
