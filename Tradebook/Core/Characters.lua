-- Core/Characters.lua
-- PURE. Saved characters: identity, merging a fresh snapshot, staleness and summaries.
--
-- character = {
--   key, name, second, class, level, race, faction, playType, realm, realmID, guid,
--   lastSeen = time, hidden = bool,
--   professions = { [skillLineID] = { rank, max, name, primary, scannedAt,
--                                      recipes = { [recipeID] = difficulty (0-3) or true } } },
--   bags = { [itemID] = count }, bank = { [itemID] = count }, bankAt = time,
-- }

local _, ns = ...

local Characters = {}
ns.Characters = Characters

local DAY = 86400

-- Forever names have two parts; UnitFullName returns (name, secondName).
function Characters.Key(name, second)
    if not name or name == "" then return nil end
    if second and second ~= "" then return name .. "-" .. second end
    return name
end

-- Play type from the two ruleset game rules.
function Characters.PlayType(pvp, rp)
    if pvp == nil and rp == nil then return "unknown" end
    if pvp and rp then return "rppvp" end
    if pvp then return "pvp" end
    if rp then return "rp" end
    return "normal"
end

function Characters.Ensure(db, key)
    db.characters[key] = db.characters[key] or {}
    local c = db.characters[key]
    c.key = key
    c.professions = c.professions or {}
    c.bags = c.bags or {}
    c.bank = c.bank or {}
    return c
end

-- Merge identity fields from a snapshot (fields that are nil are left alone).
function Characters.UpdateIdentity(c, info, now)
    for _, field in ipairs({ "name", "second", "class", "level", "race", "faction", "playType", "realm", "realmID", "guid" }) do
        if info[field] ~= nil then c[field] = info[field] end
    end
    c.lastSeen = now
end

-- Merge the character's current professions. Professions no longer present are
-- removed (unlearned); saved recipe lists of the ones still present are kept.
function Characters.UpdateProfessions(c, list, now)
    local seen = {}
    for _, p in ipairs(list) do
        if p.id then
            seen[p.id] = true
            local saved = c.professions[p.id] or { recipes = {} }
            saved.rank, saved.max, saved.name, saved.primary = p.rank, p.max, p.name, p.primary
            saved.updatedAt = now
            c.professions[p.id] = saved
        end
    end
    for id in pairs(c.professions) do
        if not seen[id] then c.professions[id] = nil end
    end
end

-- Replace one profession's learned recipe list (from a full scan).
function Characters.SetRecipes(c, skillLineID, recipes, now)
    local p = c.professions[skillLineID]
    if not p then
        p = { recipes = {} }
        c.professions[skillLineID] = p
    end
    p.recipes = recipes
    p.scannedAt = now
end

function Characters.DaysSince(c, now)
    if not c or not c.lastSeen then return nil end
    return math.floor((now - c.lastSeen) / DAY)
end

function Characters.IsStale(c, now, staleDays, currentKey)
    if c.key == currentKey then return false end
    local days = Characters.DaysSince(c, now)
    return days ~= nil and days >= (staleDays or 30)
end

-- Characters to show, current first, then by last seen (newest first), then name.
function Characters.List(db, currentKey, includeHidden)
    local out = {}
    for key, c in pairs(db.characters) do
        if includeHidden or not c.hidden or key == currentKey then out[#out + 1] = c end
    end
    table.sort(out, function(a, b)
        if (a.key == currentKey) ~= (b.key == currentKey) then return a.key == currentKey end
        local la, lb = a.lastSeen or 0, b.lastSeen or 0
        if la ~= lb then return la > lb end
        return a.key < b.key
    end)
    return out
end

-- Characters (not hidden) that have a profession, sorted by rank (highest first).
function Characters.WithProfession(db, skillLineID, currentKey)
    local out = {}
    for key, c in pairs(db.characters) do
        local p = c.professions and c.professions[skillLineID]
        if p and (not c.hidden or key == currentKey) then out[#out + 1] = c end
    end
    table.sort(out, function(a, b)
        local ra, rb = a.professions[skillLineID].rank or 0, b.professions[skillLineID].rank or 0
        if ra ~= rb then return ra > rb end
        return a.key < b.key
    end)
    return out
end

-- How many visible characters have each profession.
function Characters.ProfessionCounts(db, currentKey)
    local counts = {}
    for key, c in pairs(db.characters) do
        if not c.hidden or key == currentKey then
            for id in pairs(c.professions or {}) do counts[id] = (counts[id] or 0) + 1 end
        end
    end
    return counts
end

-- The character closest to the next rank-up in a profession: smallest gap between
-- rank and the current cap. Returns character, gap (0 = ready to train).
function Characters.ClosestToRankUp(db, skillLineID, currentKey)
    local best, bestGap
    for _, c in ipairs(Characters.WithProfession(db, skillLineID, currentKey)) do
        local p = c.professions[skillLineID]
        if p.rank and p.max and p.max > 0 and p.max < 300 then
            local gap = math.max(0, p.max - p.rank)
            if not bestGap or gap < bestGap then best, bestGap = c, gap end
        end
    end
    return best, bestGap
end

-- Next rank to train after the current cap: "Journeyman", "Expert", "Artisan" or nil at the top.
function Characters.NextRank(max)
    return ns.Professions.nextRank[max]
end

function Characters.Delete(db, key)
    if db.characters[key] then
        db.characters[key] = nil
        return true
    end
    return false
end
