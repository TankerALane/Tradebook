-- Core/Trainers.lua
-- Learns which trainer teaches which profession rank, from the trainer window itself.
-- Trainer services live on the server (not in the game files), so the only reliable source
-- is to read a trainer's list when the player opens it. Saved account-wide in
-- TradebookDB.trainers[npcID]:
--   { name, skill = skillLineID, seenAt, ranks = { [rank] = { level, skill, cost } },
--     services = { "name|subText|type|level|skill|cost", ... } (raw, for checking) }
-- Unavailable services (too low level/skill) are hidden by the trainer's default filter, so
-- the filters are switched on for the read and put back right after.
-- Also saved: loc (your map position at the trainer, like vendors). Trainers other players read
-- and shared (/tb share) ship in Data/CommunityTrainers.lua (same fields); your own reads win.
-- From the services Tradebook also knows which trainers teach which recipe, the skill needed
-- and the cost (Trainers.ForRecipe / RecipeSkill).

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
    entry.loc = ns.Merchants and ns.Merchants.Here() or nil
    ns.db.trainers = ns.db.trainers or {}
    ns.db.trainers[id] = entry
    Trainers.Invalidate()
    ns.Debug("trainer", id, entry.name, "skill", entry.skill, "ranks",
        table.concat((function() local t = {} for r in pairs(entry.ranks) do t[#t + 1] = r end return t end)(), ","))
end

-- Every trainer read: your own, then the community's (Data/CommunityTrainers.lua).
-- { [npcID] = entry } (entries have .community = true when not yours).
local all
function Trainers.All()
    if all then return all end
    all = {}
    for id, t in pairs(ns.CommunityTrainers or {}) do
        if t.services and not t.ranks then t.ranks = Trainers.RanksFromServices(t.services) end
        t.community = true
        all[id] = t
    end
    for id, t in pairs(ns.db and ns.db.trainers or {}) do all[id] = t end
    return all
end

local byRecipe -- [recipeID] = { [npcID] = { cost, skill } }
function Trainers.Invalidate()
    all, byRecipe = nil, nil
end

-- What a trainer teaches (yours or the community's): the entry, or nil when nobody opened it.
function Trainers.Get(id)
    return Trainers.All()[id]
end

-- PURE. One service line ("name|subText|type|level|skill rank|cost|prof") as
-- name, required skill (number or nil), cost (copper or nil).
function Trainers.ParseService(line)
    local name, _, _, _, skill, cost = line:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    if not name then return nil end
    return name, tonumber((skill or ""):match("(%d+)%s*$")), tonumber(cost)
end

-- Recipe IDs by name for a profession, from the recipe cache (built per call to ForRecipe's index).
local function recipesByName()
    local out = {}
    for id, r in pairs(ns.db and ns.db.recipes or {}) do
        if r.n and r.s then
            local key = r.s .. ":" .. r.n
            out[key] = out[key] or {}
            table.insert(out[key], id)
        end
    end
    return out
end

-- Trainers seen teaching a recipe: { [npcID] = { cost, skill, name, loc, seenAt, community } }, or nil.
function Trainers.ForRecipe(recipeID)
    if not byRecipe then
        byRecipe = {}
        local names = recipesByName()
        for npc, t in pairs(Trainers.All()) do
            for _, line in ipairs(t.services or {}) do
                local name, skill, cost = Trainers.ParseService(line)
                if name and not Trainers.ParseRank(name) and t.skill then
                    for _, rid in ipairs(names[t.skill .. ":" .. name] or {}) do
                        byRecipe[rid] = byRecipe[rid] or {}
                        byRecipe[rid][npc] = { cost = cost, skill = skill, name = t.name, loc = t.loc,
                            seenAt = t.seenAt, community = t.community }
                    end
                end
            end
        end
    end
    return byRecipe[recipeID]
end

-- The skill a trainer asked for to learn a recipe (seen in a trainer window), or nil.
function Trainers.RecipeSkill(recipeID)
    local best
    for _, e in pairs(Trainers.ForRecipe(recipeID) or {}) do
        if e.skill and (not best or e.skill > best) then best = e.skill end
    end
    return best
end

-- What a trainer charges for a recipe: the highest cost seen (before reputation discounts), or nil.
function Trainers.RecipeCost(recipeID)
    local best
    for _, e in pairs(Trainers.ForRecipe(recipeID) or {}) do
        if e.cost and (not best or e.cost > best) then best = e.cost end
    end
    return best
end

-- Does trainer `id` teach `rank`? true / false (opened, and it doesn't), nil (never opened).
function Trainers.Teaches(id, rank)
    local t = Trainers.Get(id)
    if not t then return nil end
    return t.ranks[rank] ~= nil
end

-- The level/skill/cost a trainer charged for `rank` of a profession, from any trainer seen.
function Trainers.RankInfo(skillLine, rank)
    for _, t in pairs(Trainers.All()) do
        if t.skill == skillLine and t.ranks[rank] then return t.ranks[rank] end
    end
    return nil
end

function Trainers.Start()
    -- Trainers read by an earlier version: rebuild their ranks from the saved services.
    for _, t in pairs(ns.db.trainers or {}) do
        if t.services then t.ranks = Trainers.RanksFromServices(t.services) end
    end
    Trainers.Invalidate()
    ns.On("TRAINER_SHOW", function() C_Timer.After(0.2, read) end)
end
