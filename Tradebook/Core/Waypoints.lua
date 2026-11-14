-- Core/Waypoints.lua
-- Set a waypoint for a location given as zone (area) + 0-100 coordinates: a TomTom arrow when
-- TomTom is installed, otherwise the game's own map pin (C_Map.SetUserWaypoint + supertrack).

local _, ns = ...
local Compat, L = ns.Compat, ns.L

local Waypoints = {}
ns.Waypoints = Waypoints

function Waypoints.Set(areaID, x, y, title)
    local map = ns.ZoneMaps and ns.ZoneMaps[areaID]
    if not map then
        ns.Print(L.WAYPOINT_NONE)
        return false
    end
    return Waypoints.SetOnMap(map, x, y, title)
end

-- Same, for a UI map ID (positions saved from the game's map API).
function Waypoints.SetOnMap(map, x, y, title)
    local tomtom = _G.TomTom
    if type(tomtom) == "table" and type(tomtom.AddWaypoint) == "function" then
        local ok = pcall(tomtom.AddWaypoint, tomtom, map, x / 100, y / 100, { title = title, from = "Tradebook" })
        if ok then
            ns.Print(L.WAYPOINT_SET:format(title or "", x, y))
            return true
        end
    end
    if Compat.Call("C_Map.CanSetUserWaypointOnMap", map) and UiMapPoint then
        Compat.Call("C_Map.SetUserWaypoint", UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
        Compat.Call("C_SuperTrack.SetSuperTrackedUserWaypoint", true)
        ns.Print(L.WAYPOINT_SET:format(title or "", x, y))
        return true
    end
    ns.Print(L.WAYPOINT_NONE)
    return false
end
