-- Core/Linked.lua
-- Another player's profession, opened from a link in chat (or a guild member's list): read
-- what they know into a temporary character that Tradebook shows like your own (read only),
-- so their recipes come with materials, prices and where to buy them.
--
-- The temporary character lives in memory only: never in TradebookDB, never shared, never in
-- the Characters view, "Who can craft" or "Could learn it". Recipe names and materials are
-- game data, cached like any profession's (Scanner.CacheRecipeInto).

local _, ns = ...
local Compat = ns.Compat

local Linked = {}
ns.Linked = Linked

Linked.char = nil -- the last profession list linked to you this session

local KEY_PREFIX = "linked:"

function Linked.IsKey(key)
    return type(key) == "string" and key:sub(1, #KEY_PREFIX) == KEY_PREFIX
end

function Linked.Get(key)
    local c = Linked.char
    if c and key == c.key then return c end
    return nil
end

-- The trade-skill session shows someone else's list: linked, or a guild member's.
function Linked.IsOpen()
    return (Compat.Call("C_TradeSkillUI.IsTradeSkillLinked") or Compat.Call("C_TradeSkillUI.IsTradeSkillGuild"))
        and true or false
end

-- Read the open linked list into Linked.char. Returns the character and the profession's
-- skill line, or nil (not a linked list, or not a profession Tradebook knows).
function Linked.Read()
    local linked, linkedName = Compat.Call("C_TradeSkillUI.IsTradeSkillLinked")
    if not linked and not Compat.Call("C_TradeSkillUI.IsTradeSkillGuild") then return nil end
    if not Compat.Call("C_TradeSkillUI.IsTradeSkillReady") then return nil end
    local base = Compat.Call("C_TradeSkillUI.GetBaseProfessionInfo")
    local skill = base and base.professionID
    if not skill or skill == 0 or not ns.Professions.Get(skill) then return nil end
    local ids = Compat.Call("C_TradeSkillUI.GetAllRecipeIDs") or Compat.Call("C_TradeSkillUI.GetFilteredRecipeIDs") or {}
    local learned, cached = {}, false
    for _, id in ipairs(ids) do
        local info = Compat.Call("C_TradeSkillUI.GetRecipeInfo", id)
        if info and info.name then
            if not ns.db.recipes[id] and ns.Scanner.CacheRecipeInto(ns.db, id, skill) then cached = true end
            if info.learned then learned[id] = true end
        end
    end
    if not next(learned) then return nil end
    local name = type(linkedName) == "string" and linkedName ~= "" and linkedName or "?"
    local key = KEY_PREFIX .. name
    local c = Linked.char
    if not (c and c.key == key) then
        c = { key = key, name = name, linked = true, professions = {}, bags = {}, bank = {} }
    end
    c.professions[skill] = {
        rank = base.skillLevel, max = base.maxSkillLevel, name = base.professionName,
        recipes = learned, scannedAt = GetServerTime(),
    }
    Linked.char = c
    if cached then ns.Recipes.Invalidate() end
    ns.Debug("linked profession", base.professionName, "from", name, #ids, "recipes")
    return c, skill
end
