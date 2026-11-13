-- Core/Scanner.lua
-- Reads the logged-in character from the game and writes it into TradebookDB.
-- Only runs on relevant events, throttled. Phase 0 facts this relies on:
--   * GetAllRecipeIDs lists every recipe of the OPEN profession (learned and not).
--   * learned flags are only right for the open profession.
--   * recipe info and schematics can be read by ID at any time.

local _, ns = ...
local Compat, Characters, Recipes = ns.Compat, ns.Characters, ns.Recipes

local Scanner = {}
ns.Scanner = Scanner

local function now() return GetServerTime() end

---------------------------------------------------------------------------
-- identity and professions
---------------------------------------------------------------------------

local function gameRule(name)
    local rule = Enum and Enum.GameRule and Enum.GameRule[name]
    if not rule then return nil end
    return Compat.Call("C_GameRules.IsGameRuleActive", rule) == true
end

function Scanner.Identity()
    local name, second = Compat.Call("UnitFullName", "player")
    if not name or Compat.IsSecret(name) then return nil end
    local key = Characters.Key(name, second)
    if not key then return nil end
    local _, classFile = Compat.Call("UnitClass", "player")
    local _, raceFile = Compat.Call("UnitRace", "player")
    local info = {
        name = name,
        second = second,
        class = classFile,
        race = raceFile,
        level = Compat.Call("UnitLevel", "player"),
        faction = Compat.Call("UnitFactionGroup", "player"),
        realm = Compat.Call("GetRealmName"),
        realmID = Compat.Call("GetRealmID"),
        guid = Compat.Call("UnitGUID", "player"),
        playType = Characters.PlayType(gameRule("PvPRuleset"), gameRule("RPRuleset")),
    }
    for k, v in pairs(info) do
        if Compat.IsSecret(v) then info[k] = nil end
    end
    return key, info
end

function Scanner.Professions()
    local c = ns.char
    if not c then return end
    local list = {}
    local s1, s2, s3, s4, s5, s6, s7 = Compat.Call("GetProfessions")
    -- pairs() skips the nil slots of characters without every profession.
    for _, index in pairs({ s1, s2, s3, s4, s5, s6, s7 }) do
        local name, _, rank, maxRank, _, _, skillLine = Compat.Call("GetProfessionInfo", index)
        local known = ns.Professions.Get(skillLine)
        if skillLine and known then
            list[#list + 1] = { id = skillLine, name = name, rank = rank, max = maxRank, primary = known.primary }
        end
    end
    Characters.UpdateProfessions(c, list, now())
    Recipes.Invalidate()
    ns.Fire("PROFESSIONS_UPDATED")
end

---------------------------------------------------------------------------
-- open profession: recipes
---------------------------------------------------------------------------

local categoryCache = {}

-- Category name/parent. Uses the saved copy when the API can't answer (profession closed).
local function category(id)
    if not id or id == 0 then return nil end
    local c = categoryCache[id]
    if c == nil then
        local info = Compat.Call("C_TradeSkillUI.GetCategoryInfo", id)
        if info and info.name then
            c = { n = info.name, p = info.parentCategoryID }
            categoryCache[id] = c
            ns.db.categories[id] = c
        else
            c = ns.db.categories[id]
        end
    end
    return c
end

-- Walk to the root category; return its name and whether the camp category is on the path.
local function classify(categoryID)
    local isCamp, rootName = false, nil
    local id, guard = categoryID, 0
    while id and id ~= 0 and guard < 8 do
        guard = guard + 1
        local c = category(id)
        if not c then break end
        if ns.Camp.IsCampCategory(id, c.n, c.p, ns.db.campCategories) then isCamp = true end
        rootName = c.n
        id = c.p
    end
    return rootName, isCamp
end

-- The profession currently open in the trade-skill session, if it's this character's own.
function Scanner.OpenProfession()
    if not Compat.Call("C_TradeSkillUI.IsTradeSkillReady") then return nil end
    if Compat.Call("C_TradeSkillUI.IsTradeSkillLinked") or Compat.Call("C_TradeSkillUI.IsTradeSkillGuild")
        or Compat.Call("C_TradeSkillUI.IsNPCCrafting") then
        return nil
    end
    local base = Compat.Call("C_TradeSkillUI.GetBaseProfessionInfo")
    if not base or not base.professionID or base.professionID == 0 then return nil end
    if not ns.Professions.Get(base.professionID) then return nil end
    return base
end

local function cacheRecipe(id, info, skillLineID, professionName)
    local cached = ns.db.recipes[id]
    local rootName, isCamp = classify(info.categoryID)
    local data = {
        s = skillLineID,
        n = info.name,
        c = info.categoryID,
        i = info.icon,
        t = info.maxTrivialLevel,
        camp = isCamp or nil,
        x = (rootName ~= nil and rootName ~= professionName) or nil,
    }
    if isCamp and info.categoryID then ns.db.campCategories[info.categoryID] = skillLineID end
    if not cached or not cached.r then
        local schem = Compat.Call("C_TradeSkillUI.GetRecipeSchematic", id, false)
        if schem then
            local reagents = {}
            for _, slot in ipairs(schem.reagentSlotSchematics or {}) do
                local first = slot.reagents and slot.reagents[1]
                -- Only required basic reagents; optional/finishing slots are skipped.
                if first and first.itemID and slot.required ~= false and slot.reagentType == 1 then
                    reagents[#reagents + 1] = { itemID = first.itemID, count = slot.quantityRequired or 1 }
                end
            end
            data.r = Recipes.PackReagents(reagents)
            data.o = schem.outputItemID
            data.q1, data.q2 = schem.quantityMin, schem.quantityMax
        end
    end
    Recipes.Store(ns.db, id, data)
end

function Scanner.Recipes()
    local c = ns.char
    local base = Scanner.OpenProfession()
    if not c or not base then return end
    local skillLineID = base.professionID
    local ids = Compat.Call("C_TradeSkillUI.GetAllRecipeIDs") or Compat.Call("C_TradeSkillUI.GetFilteredRecipeIDs") or {}
    local learned = {}
    for _, id in ipairs(ids) do
        local info = Compat.Call("C_TradeSkillUI.GetRecipeInfo", id)
        if info and info.name then
            cacheRecipe(id, info, skillLineID, base.professionName)
            if info.learned then learned[id] = info.relativeDifficulty or true end
        end
    end
    if next(learned) or #ids > 0 then
        Characters.SetRecipes(c, skillLineID, learned, now())
    end
    local p = c.professions[skillLineID]
    if p then
        p.rank, p.max = base.skillLevel or p.rank, base.maxSkillLevel or p.max
        p.name = p.name or base.professionName
    end
    Recipes.Invalidate()
    ns.Debug("scanned", base.professionName, #ids, "recipes")
    ns.Fire("RECIPES_UPDATED", skillLineID)
end

-- Quick scan without opening anything: check the bundled recipe list against the
-- spellbook. Only ADDS recipes (the full scan on open is authoritative), and does
-- nothing if the API can't see any recipe as known.
function Scanner.QuickRecipes()
    local c = ns.char
    if not c or not ns.RecipeLevels or not Compat.Has("C_SpellBook.IsSpellKnown") then return end
    local wanted = {}
    for skill, p in pairs(c.professions) do
        local def = ns.Professions.Get(skill)
        if def and not def.noRecipes then wanted[skill] = p end
    end
    local found = {}
    for id, lv in pairs(ns.RecipeLevels) do
        local p = wanted[lv[1]]
        if p and Compat.Call("C_SpellBook.IsSpellKnown", id) then
            found[lv[1]] = found[lv[1]] or {}
            found[lv[1]][id] = true
        end
    end
    local added = 0
    for skill, ids in pairs(found) do
        local p = wanted[skill]
        p.recipes = p.recipes or {}
        local profName = ns.Professions.Get(skill).name
        for id in pairs(ids) do
            if p.recipes[id] == nil then
                p.recipes[id] = ns.Sources.Difficulty(id, p.rank) or true
                added = added + 1
            end
            if not ns.db.recipes[id] or not ns.db.recipes[id].n then
                local info = Compat.Call("C_TradeSkillUI.GetRecipeInfo", id)
                if info and info.name then cacheRecipe(id, info, skill, profName) end
            end
        end
        p.quickAt = now()
    end
    if added > 0 then
        Recipes.Invalidate()
        ns.Fire("RECIPES_UPDATED")
    end
    ns.Debug("quick scan added", added, "recipes")
end

---------------------------------------------------------------------------
-- bags and banks
---------------------------------------------------------------------------

local function countContainers(bagIDs, into)
    for _, bag in ipairs(bagIDs) do
        local slots = Compat.Call("C_Container.GetContainerNumSlots", bag) or 0
        for slot = 1, slots do
            local info = Compat.Call("C_Container.GetContainerItemInfo", bag, slot)
            if info and info.itemID then
                into[info.itemID] = (into[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return into
end

function Scanner.Bags()
    local c = ns.char
    if not c then return end
    local bags = {}
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or ((NUM_BAG_SLOTS or 4) + 1)
    for bag = 0, last do bags[#bags + 1] = bag end
    c.bags = countContainers(bags, {})
    ns.Fire("ITEMS_UPDATED")
end

local function bankTabs(bankType)
    local ids = Compat.Call("C_Bank.FetchPurchasedBankTabIDs", bankType)
    return type(ids) == "table" and ids or {}
end

Scanner.bankOpen = false

function Scanner.Bank()
    local c = ns.char
    if not c or not Scanner.bankOpen or not Enum.BankType then return end
    -- Forever has only the character bank (no account/warband bank).
    if Compat.Call("C_Bank.CanViewBank", Enum.BankType.Character) then
        c.bank = countContainers(bankTabs(Enum.BankType.Character), {})
        c.bankAt = now()
    end
    ns.Fire("ITEMS_UPDATED")
end

---------------------------------------------------------------------------
-- legacy (read only, current character)
---------------------------------------------------------------------------

function Scanner.Legacy()
    local consts = Constants and Constants.LegacyConsts
    if not consts then return nil end
    local treeID = consts.LEGACY_TREE_PROFESSIONS_ID
    local configID = Compat.Call("C_Traits.GetConfigIDByTreeID", treeID)
    if not configID then return nil end
    local out = { nodes = {}, points = 0 }
    local currencies = Compat.Call("C_Traits.GetTreeCurrencyInfo", configID, treeID, false)
    for _, cur in ipairs(currencies or {}) do
        if cur.traitCurrencyID == consts.LEGACY_POINTS_TRAIT_CURRENCY_ID then out.points = cur.quantity or 0 end
    end
    for _, nodeID in ipairs(Compat.Call("C_Traits.GetTreeNodes", treeID) or {}) do
        local node = Compat.Call("C_Traits.GetNodeInfo", configID, nodeID)
        local entryID = node and node.entryIDs and node.entryIDs[1]
        local entry = entryID and Compat.Call("C_Traits.GetEntryInfo", configID, entryID)
        local def = entry and entry.definitionID and Compat.Call("C_Traits.GetDefinitionInfo", entry.definitionID)
        local name = def and (def.overrideName or (def.spellID and Compat.Call("C_Spell.GetSpellName", def.spellID)))
        local desc = def and def.spellID and Compat.Call("C_Spell.GetSpellDescription", def.spellID)
        if name and name ~= "" then
            out.nodes[#out.nodes + 1] = { name = name, rank = node.activeRank or 0, max = node.maxRanks or 0,
                spellID = def.spellID, description = desc }
        end
    end
    if ns.char then
        ns.char.legacy = { points = out.points, nodes = {}, at = now() }
        for _, n in ipairs(out.nodes) do
            ns.char.legacy.nodes[#ns.char.legacy.nodes + 1] = { name = n.name, rank = n.rank, max = n.max }
        end
    end
    return out
end

---------------------------------------------------------------------------
-- wiring
---------------------------------------------------------------------------

function Scanner.Start()
    ns.On("SKILL_LINES_CHANGED", function() ns.Throttle("professions", 1, Scanner.Professions) end)
    ns.On("TRADE_SKILL_SHOW", function() ns.Throttle("recipes", 0.3, Scanner.Recipes) end)
    ns.On("TRADE_SKILL_LIST_UPDATE", function() ns.Throttle("recipes", 1, Scanner.Recipes) end)
    ns.On("TRADE_SKILL_DATA_SOURCE_CHANGED", function() ns.Throttle("recipes", 0.3, Scanner.Recipes) end)
    ns.On("NEW_RECIPE_LEARNED", function()
        ns.Throttle("recipes", 0.5, Scanner.Recipes)
        ns.Throttle("professions", 1, Scanner.Professions)
        ns.Throttle("quick", 2, Scanner.QuickRecipes)
    end)
    ns.On("BAG_UPDATE_DELAYED", function()
        ns.Throttle("bags", 0.5, Scanner.Bags)
        if Scanner.bankOpen then ns.Throttle("bank", 0.5, Scanner.Bank) end
    end)
    ns.On("BANKFRAME_OPENED", function()
        Scanner.bankOpen = true
        ns.Throttle("bank", 0.5, Scanner.Bank)
    end)
    ns.On("BANKFRAME_CLOSED", function() Scanner.bankOpen = false end)
    for _, ev in ipairs({ "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED" }) do
        ns.On(ev, function() if Scanner.bankOpen then ns.Throttle("bank", 0.5, Scanner.Bank) end end)
    end
    ns.On("PLAYER_LEVEL_UP", function(_, level) if ns.char then ns.char.level = level end end)
    ns.On("PLAYER_LOGOUT", function() if ns.char then ns.char.lastSeen = now() end end)

    Scanner.Professions()
    Scanner.Bags()
    ns.Throttle("quick", 3, Scanner.QuickRecipes)
end
