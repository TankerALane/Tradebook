-- Core/Trainers.lua
-- Learns which trainer teaches which profession rank, from the trainer window itself.
-- Trainer services live on the server (not in the game files), so the only reliable source
-- is to read a trainer's list when the player opens it. Saved account-wide in
-- TradebookDB.trainers[npcID]:
--   { name, skill = skillLineID, seenAt, ranks = { [rank] = { level, skill, cost } },
--     services = { "name|subText|type|level|skill|cost", ... } (raw, for checking) }
-- Unavailable services (too low level/skill) are hidden by the trainer's default filter, so
-- the filters are switched on for the read and put back right after.

local _, ns = ...
local Compat = ns.Compat

local Trainers = {}
ns.Trainers = Trainers

local RANK_WORDS = { "Apprentice", "Journeyman", "Expert", "Artisan", "Master" }

-- PURE. The rank a trainer service teaches, or nil. Forever names them "<Rank> <profession>"
-- ("Journeyman Enchanting", "Expert Herbalism", "Journeyman Cook"); the game only flags
-- Apprentice as a profession service, so the name is what counts.
function Trainers.ParseRank(name)
    for _, word in ipairs(RANK_WORDS) do
        if (name or ""):find("^" .. word .. " %a") then return word end
    end
    return nil
end

-- PURE. Rebuild a trainer's ranks from its saved raw service lines
-- ("name|subText|type|level|skill rank|cost|prof").
function Trainers.RanksFromServices(services)
    local ranks = {}
    for _, line in ipairs(services or {}) do
        local name, _, _, level, skill, cost = line:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
        local rank = name and Trainers.ParseRank(name)
        if rank then
            ranks[rank] = { level = tonumber(level), skill = tonumber(skill:match("(%d+)%s*$")), cost = tonumber(cost) }
        end
    end
    return ranks
end

-- PURE. Skill line ID for a profession name as the trainer shows it, or nil.
function Trainers.SkillLineFor(name)
    if not name or name == "" then return nil end
    for _, p in ipairs(ns.Professions.list) do
        if name == p.name or name == ns.L[p.name] then return p.id end
    end
    return nil
end

local function npcID()
    local guid = Compat.Call("UnitGUID", "npc")
    if not guid or Compat.IsSecret(guid) then return nil end
    local id = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    return tonumber(id)
end

local FILTERS = { "available", "unavailable", "used" }
local reading = false

local function read()
    if reading or ns.fake then return end
    if not Compat.Call("IsTradeskillTrainer") then return end
    local id = npcID()
    if not id then return end
    reading = true
    -- Show everything for the read, then restore the player's filter choices.
    local saved = {}
    for _, f in ipairs(FILTERS) do
        saved[f] = Compat.Call("GetTrainerServiceTypeFilter", f)
        if not saved[f] then Compat.Call("SetTrainerServiceTypeFilter", f, true) end
    end
    local entry = { name = Compat.Call("UnitName", "npc"), seenAt = GetServerTime(), ranks = {}, services = {} }
    for i = 1, Compat.Call("GetNumTrainerServices") or 0 do
        local name, serviceType, _, reqLevel, subText = Compat.Call("GetTrainerServiceInfo", i)
        if name then
            local skillName, skillRank = Compat.Call("GetTrainerServiceSkillReq", i)
            local cost, isProfession = Compat.Call("GetTrainerServiceCost", i)
            local rank = Trainers.ParseRank(name)
            local line = Compat.Call("GetTrainerServiceSkillLine", i)
            entry.skill = entry.skill or Trainers.SkillLineFor(line)
            entry.services[#entry.services + 1] = table.concat({ tostring(name), tostring(subText or ""),
                tostring(serviceType or ""), tostring(reqLevel or ""), tostring(skillName or "") .. " "
                .. tostring(skillRank or ""), tostring(cost or ""), isProfession and "prof" or "" }, "|")
            if rank then
                entry.ranks[rank] = { level = reqLevel, skill = skillRank, cost = cost }
            end
        end
    end
    for _, f in ipairs(FILTERS) do
        if not saved[f] then Compat.Call("SetTrainerServiceTypeFilter", f, false) end
    end
    reading = false
    ns.db.trainers = ns.db.trainers or {}
    ns.db.trainers[id] = entry
    ns.Debug("trainer", id, entry.name, "skill", entry.skill, "ranks",
        table.concat((function() local t = {} for r in pairs(entry.ranks) do t[#t + 1] = r end return t end)(), ","))
end

-- What a scanned trainer teaches: the entry, or nil when never opened.
function Trainers.Get(id)
    return ns.db.trainers and ns.db.trainers[id]
end

-- Does trainer `id` teach `rank`? true / false (opened, and it doesn't), nil (never opened).
function Trainers.Teaches(id, rank)
    local t = Trainers.Get(id)
    if not t then return nil end
    return t.ranks[rank] ~= nil
end

-- The level/skill/cost a trainer charged for `rank` of a profession, from any trainer seen.
function Trainers.RankInfo(skillLine, rank)
    for _, t in pairs(ns.db.trainers or {}) do
        if t.skill == skillLine and t.ranks[rank] then return t.ranks[rank] end
    end
    return nil
end

function Trainers.Start()
    -- Trainers read by an earlier version: rebuild their ranks from the saved services.
    for _, t in pairs(ns.db.trainers or {}) do
        if t.services then t.ranks = Trainers.RanksFromServices(t.services) end
    end
    ns.On("TRAINER_SHOW", function() C_Timer.After(0.2, read) end)
end
