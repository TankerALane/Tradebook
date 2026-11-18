-- Core/Locations.lua
-- PURE. Picks the nearest spawn of each NPC/object and sorts them by distance from the
-- player. World positions come from an injected converter, so this runs without the game.
--
-- entry   = { id, name, spawns = { [areaID] = { {x, y}, ... } }, ... }   (x/y 0-100)
-- here    = { continent = id, x = n, y = n }  (world position) or nil when unknown
-- toWorld = function(areaID, x, y) -> continent, wx, wy   (nil when that zone can't be mapped)

local _, ns = ...

local Locations = {}
ns.Locations = Locations

local MAX_SPAWNS_PER_ENTRY = 40 -- enough to find the nearest; keeps big spawn lists cheap

local function validPoint(p)
    return type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" and p[1] >= 0 and p[2] >= 0
end

-- The spawn points of one entry, in a fixed order (by area, at most MAX_SPAWNS_PER_ENTRY),
-- with their world positions when toWorld is given: { { areaID, x, y, c, wx, wy } }. These
-- don't change as you move, so they can be kept (Questie.VendorPlace).
function Locations.SpawnPoints(spawns, toWorld)
    local out = {}
    if type(spawns) ~= "table" then return out end
    local areas = {}
    for areaID in pairs(spawns) do areas[#areas + 1] = areaID end
    table.sort(areas)
    for _, areaID in ipairs(areas) do
        for _, p in ipairs(spawns[areaID]) do
            if validPoint(p) then
                if #out >= MAX_SPAWNS_PER_ENTRY then return out end
                local pt = { areaID = areaID, x = p[1], y = p[2] }
                if toWorld then pt.c, pt.wx, pt.wy = toWorld(areaID, p[1], p[2]) end
                out[#out + 1] = pt
            end
        end
    end
    return out
end

-- The nearest of those points on the player's continent, else the first one:
-- { areaID, x, y, distance (yards, or nil) }, or nil when there are none.
function Locations.NearestPoint(points, here)
    local best, bestD
    if here then
        local hc, hx, hy = here.continent, here.x, here.y
        for _, pt in ipairs(points) do
            if pt.c and pt.c == hc and pt.wx then
                local dx, dy = pt.wx - hx, pt.wy - hy
                local d = dx * dx + dy * dy
                if not bestD or d < bestD then best, bestD = pt, d end
            end
        end
    end
    if best then return { areaID = best.areaID, x = best.x, y = best.y, distance = math.sqrt(bestD) } end
    local first = points[1]
    return first and { areaID = first.areaID, x = first.x, y = first.y } or nil
end

-- The best spawn of one entry: nearest on the player's continent, else the first valid one.
-- Returns { areaID, x, y, distance (yards, or nil) } or nil when there are no spawns.
function Locations.BestSpawn(spawns, here, toWorld)
    if type(spawns) ~= "table" then return nil end
    return Locations.NearestPoint(Locations.SpawnPoints(spawns, here and toWorld or nil), here)
end

-- Nearest `limit` entries: those with a distance first (closest first), then the rest by
-- name. Each result is the entry plus { areaID, x, y, distance }.
function Locations.Nearest(entries, here, toWorld, limit)
    local out = {}
    for _, e in ipairs(entries or {}) do
        local spot = Locations.BestSpawn(e.spawns, here, toWorld)
        if spot then
            local r = {}
            for k, v in pairs(e) do r[k] = v end
            r.spawns = nil
            r.areaID, r.x, r.y, r.distance = spot.areaID, spot.x, spot.y, spot.distance
            out[#out + 1] = r
        end
    end
    table.sort(out, function(a, b)
        if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
        if a.distance and b.distance and a.distance ~= b.distance then return a.distance < b.distance end
        return tostring(a.name) < tostring(b.name)
    end)
    if limit and #out > limit then
        for i = #out, limit + 1, -1 do out[i] = nil end
    end
    return out
end

-- Questie-style faction flag ("A", "H", "AH" or nil) against the player's faction.
function Locations.FriendlyTo(flag, faction)
    if flag == nil or flag == "" then return true end
    local letter = faction == "Alliance" and "A" or faction == "Horde" and "H" or nil
    if not letter then return true end
    return tostring(flag):find(letter, 1, true) ~= nil
end

-- "120 yd" / "1.2 km" style distance text (yards).
function Locations.DistanceText(yards)
    if not yards then return nil end
    if yards < 1000 then return string.format("%d yd", math.floor(yards + 0.5)) end
    return string.format("%.1fk yd", yards / 1000)
end
