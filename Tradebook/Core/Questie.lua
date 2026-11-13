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

-- Clear distances when the player moves to another zone.
function Questie.Start()
    ns.On("ZONE_CHANGED_NEW_AREA", function() cache = {} end)
end
