-- Core/Friends.lua
-- PURE. Friends' profession ranks from Fellowship Ledger (Decoupled Lane Studio), when it is
-- installed. Fellowship Ledger has no API, so this reads its saved variables
-- (FellowshipLedgerDB) defensively:
--   FellowshipLedgerDB.friends[id] = { name, tag, characters = {
--       [key] = { name, display, class, level, faction, lastSeen, professions = {
--           ["<skillLineID>"] = { name, rank, max, lastAt } } } } }
-- Only ranks are shared there (no recipe lists). Read only; nothing is written.

local _, ns = ...

local Friends = {}
ns.Friends = Friends

-- Friend characters who have a profession: { name, class, rank, max, at, friend } sorted
-- by rank (highest first), then name. fl: the FellowshipLedgerDB table (or nil).
-- faction: only friend characters of that faction ("Alliance" / "Horde"; ones with no faction
-- saved count), since you can't trade or mail across factions; nil: every faction.
function Friends.WithProfession(fl, skillLineID, faction)
    local out = {}
    if type(fl) ~= "table" or type(fl.friends) ~= "table" then return out end
    local key = tostring(skillLineID)
    for _, friend in pairs(fl.friends) do
        if type(friend) == "table" and type(friend.characters) == "table" then
            for charKey, c in pairs(friend.characters) do
                local profs = type(c) == "table" and c.professions
                local p = type(profs) == "table" and (profs[key] or profs[tonumber(key)])
                local sameSide = not faction or c.faction == nil or c.faction == faction
                if sameSide and type(p) == "table" and tonumber(p.rank) then
                    out[#out + 1] = {
                        name = c.display or c.name or tostring(charKey),
                        class = c.class,
                        rank = tonumber(p.rank) or 0,
                        max = tonumber(p.max) or 0,
                        at = tonumber(p.lastAt) or tonumber(c.lastSeen),
                        friend = friend.name,
                    }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.name < b.name
    end)
    return out
end

-- The live FellowshipLedgerDB when Fellowship Ledger is loaded, else nil.
function Friends.Source()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("FellowshipLedger")
    if not loaded then return nil end
    local db = _G.FellowshipLedgerDB
    return type(db) == "table" and db or nil
end

-- Convenience for the UI: friends with a profession, safe if anything is missing.
function Friends.For(skillLineID)
    if ns.fake and ns.FakeData then return ns.FakeData.FriendsWith(skillLineID, GetServerTime()) end
    -- Same faction as the character you're playing (unless the setting combines them).
    local faction
    if not (ns.db and ns.db.settings and ns.db.settings.crossFaction) then
        faction = ns.char and ns.char.faction or (UnitFactionGroup and UnitFactionGroup("player"))
    end
    local ok, list = pcall(Friends.WithProfession, Friends.Source(), skillLineID, faction)
    return ok and list or {}
end
