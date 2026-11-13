-- Core/Crafting.lua
-- Crafting for the logged-in character. Phase 0 rules:
--   * CraftRecipe only works from a click (hardware event); timers are blocked.
--   * It silently does nothing unless that recipe's profession is open.
-- So: one CraftRecipe call per click, and the UI only enables Craft when State() says so.

local _, ns = ...
local Compat, L = ns.Compat, ns.L

local Crafting = {}
ns.Crafting = Crafting

-- Can the current character craft this recipe right now?
-- Returns state ("ok", "combat", "other", "notlearned", "closed", "missing"), max craftable, reason text.
function Crafting.State(recipeID)
    local recipe = ns.db.recipes[recipeID]
    if not recipe then return "notlearned", 0, L.CRAFT_NOT_LEARNED end
    local prof = ns.Professions.Get(recipe.s)
    local profName = prof and (L[prof.name] or prof.name) or "?"
    local mine = ns.char and ns.char.professions[recipe.s]
    if not (mine and mine.recipes and mine.recipes[recipeID]) then
        local who = ns.Recipes.KnownBy(ns.db, recipeID)
        if #who > 0 then return "other", 0, L.CRAFT_OTHER_CHAR:format(ns.CharName(who[1])) end
        return "notlearned", 0, L.CRAFT_NOT_LEARNED
    end
    if InCombatLockdown() then return "combat", 0, L.CRAFT_COMBAT end
    local open = ns.Scanner.OpenProfession()
    if not open or open.professionID ~= recipe.s then
        return "closed", 0, L.CRAFT_NEED_OPEN:format(profName)
    end
    local count = Compat.Call("C_TradeSkillUI.GetCraftableCount", recipeID) or 0
    if count <= 0 then return "missing", 0, L.CRAFT_MISSING end
    return "ok", count
end

-- Must be called directly from a button's OnClick.
function Crafting.Craft(recipeID, times)
    local state, max = Crafting.State(recipeID)
    if state ~= "ok" then return false end
    times = math.max(1, math.min(tonumber(times) or 1, max))
    Compat.Call("C_TradeSkillUI.CraftRecipe", recipeID, times)
    ns.Debug("craft", recipeID, times)
    return true
end

-- Open one of the current character's professions. Must be called from a click.
function Crafting.OpenProfession(skillLineID)
    if InCombatLockdown() then return false end
    if not (ns.char and ns.char.professions[skillLineID]) then return false end
    local open = ns.Scanner.OpenProfession()
    if open and open.professionID == skillLineID then return true end
    return Compat.Call("C_TradeSkillUI.OpenTradeSkill", skillLineID) == true
end

-- The craft button's action from a click: open the profession if that's all that's
-- missing, otherwise craft. Returns true if something happened.
function Crafting.Click(recipeID, times)
    local state = Crafting.State(recipeID)
    if state == "closed" then
        local r = ns.db.recipes[recipeID]
        return r ~= nil and Crafting.OpenProfession(r.s)
    end
    return Crafting.Craft(recipeID, times)
end

-- Can "Open in default window" work? Only for the current character's professions.
function Crafting.CanOpenInDefault(recipeID)
    local r = recipeID and ns.db.recipes[recipeID]
    return r ~= nil and ns.char ~= nil and ns.char.professions[r.s] ~= nil and not InCombatLockdown()
end

-- Fallback: show this recipe in the default Professions window. Call from a click.
-- Opens the recipe's profession first (OpenRecipe alone only works within the open one).
function Crafting.OpenInDefault(recipeID)
    if not Crafting.CanOpenInDefault(recipeID) then return false end
    local r = ns.db.recipes[recipeID]
    ns.Takeover.UseDefault()
    local open = ns.Scanner.OpenProfession()
    if not open or open.professionID ~= r.s then
        Compat.Call("C_TradeSkillUI.OpenTradeSkill", r.s)
    end
    Compat.Call("C_TradeSkillUI.OpenRecipe", recipeID)
    return true
end
