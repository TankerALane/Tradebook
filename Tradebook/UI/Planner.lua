-- UI/Planner.lua
-- "Leveling plan" window: the cheapest way from a character's skill to its cap (Core/Planner.lua),
-- as steps ("131-137: craft about 9 x Gray Woolen Shirt"), the materials (need / have / buy),
-- the cost, and a shopping list (which can be sent to Auctionator). Opened from the rank window.

local _, ns = ...
local L, W, Compat = ns.L, ns.W, ns.Compat

local PlannerUI = {}
ns.PlannerUI = PlannerUI

local popup

local function settings()
    local s = ns.db.settings
    if s.planTrainer == nil then s.planTrainer = true end
    if s.planOwned == nil then s.planOwned = true end
    return s
end

local function ensure()
    if popup then return popup end
    popup = CreateFrame("Frame", "TradebookPlannerFrame", UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(520, 520)
    popup:SetPoint("CENTER", 60, 20)
    popup:SetFrameStrata("DIALOG")
    popup:SetToplevel(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:SetClampedToScreen(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup.title = W.Text(popup, "GameFontHighlight", "CENTER")
    popup.title:SetPoint("TOP", 0, -5)

    popup.trainer = W.Check(popup, L.PLAN_TRAINER, function(on) settings().planTrainer = on; PlannerUI.Refresh() end)
    popup.trainer:SetPoint("TOPLEFT", 12, -28)
    popup.owned = W.Check(popup, L.PLAN_OWNED, function(on) settings().planOwned = on; PlannerUI.Refresh() end)
    popup.owned:SetPoint("TOPLEFT", popup.trainer, "BOTTOMLEFT", 0, 2)

    local body = CreateFrame("Frame", nil, popup)
    body:SetPoint("TOPLEFT", 14, -80)
    body:SetPoint("BOTTOMRIGHT", -10, 44)
    popup.pane = ns.Details.NewLinePane(body)

    popup.shop = W.Button(popup, L.SHOPPING_LIST, 140, 22)
    popup.shop:SetPoint("BOTTOMLEFT", 12, 12)
    popup.shop:SetScript("OnClick", function()
        if popup.entries then ns.Shopping.Show(popup.entries, L.PLAN_SHOPPING) end
    end)
    popup.note = W.Text(popup, "GameFontDisableSmall")
    popup.note:SetPoint("LEFT", popup.shop, "RIGHT", 10, 0)
    popup.note:SetPoint("RIGHT", popup, "RIGHT", -12, 0)
    popup.note:SetText(L.PLAN_NOTE)
    tinsert(UISpecialFrames, "TradebookPlannerFrame")
    popup:Hide()
    return popup
end

-- Candidates and callbacks for Core/Planner.lua.
local function planFor(c, skill)
    local db = ns.db
    local prof = c.professions[skill]
    local s = settings()
    local known = prof.recipes or {}
    local recipes, learnAt = {}, {}
    for _, id in ipairs(ns.Recipes.ForProfession(db, skill)) do
        local r = db.recipes[id]
        if r and r.r and r.n and r.n ~= "" and not r.x and not db.badThresholds[id] and ns.Sources.Thresholds(id) then
            if known[id] then
                recipes[#recipes + 1] = id
            elseif s.planTrainer then
                local kinds = ns.Sources.Kinds(id)
                local need = ns.Sources.Required(id)
                if kinds and kinds.trainer and need then
                    recipes[#recipes + 1] = id
                    learnAt[id] = need
                end
            end
        end
    end
    local inventory = {}
    if s.planOwned then
        for itemID, n in pairs(c.bags or {}) do inventory[itemID] = (inventory[itemID] or 0) + n end
        for itemID, n in pairs(c.bank or {}) do inventory[itemID] = (inventory[itemID] or 0) + n end
    end
    local priced = ns.Prices.Available()
    local plan = ns.Planner.Plan({
        rank = prof.rank or 0, target = prof.max or 0, recipes = recipes,
        thresholds = function(id) return ns.Sources.Thresholds(id) end,
        reagents = function(id) return ns.Recipes.Reagents(db.recipes[id]) end,
        price = function(itemID) return ns.Prices.Cheapest(ns.Prices.Get(itemID)) end,
        inventory = inventory,
        learnAt = function(id) return learnAt[id] end,
    })
    return plan, priced
end

function PlannerUI.Refresh()
    if not (popup and popup:IsShown() and popup.charKey) then return end
    local c = ns.db.characters[popup.charKey]
    local skill = popup.skill
    local prof = c and c.professions[skill]
    local def = ns.Professions.Get(skill)
    local profName = def and (L[def.name] or def.name) or ""
    local s = settings()
    popup.trainer:SetChecked(s.planTrainer)
    popup.owned:SetChecked(s.planOwned)
    local pane = popup.pane
    pane:Begin()
    popup.entries = nil
    popup.shop:Disable()
    if not prof then
        popup.title:SetText(L.PLAN_TITLE:format(profName))
        pane:Finish()
        return
    end
    popup.title:SetText(L.PLAN_TITLE:format(profName))
    pane:Add({ text = L.PLAN_FOR:format(W.ClassName(c), profName, prof.rank or 0, prof.max or 0) })
    if (prof.rank or 0) >= (prof.max or 0) then
        pane:Add({ indent = 1, text = L.PLAN_AT_CAP, color = W.GREY })
        pane:Finish()
        return
    end
    local plan, priced = planFor(c, skill)
    if not priced then pane:Add({ indent = 1, text = L.PLAN_NO_PRICES, color = W.GREY }) end
    pane:Gap()

    -- Steps.
    pane:Add({ text = L.PLAN_STEPS, font = "GameFontNormal", color = W.GOLD, right = ns.Prices.Money(plan.cost) })
    local entries = {}
    for _, step in ipairs(plan.steps) do
        local r = ns.db.recipes[step.recipeID]
        local text = L.PLAN_STEP:format(step.from, step.to, step.crafts, r.n)
        if step.learn then text = text .. "  " .. W.ColorText(W.GREY, L.PLAN_LEARN) end
        local right = step.unpriced and W.ColorText(W.GREY, L.PLAN_PRICE_UNKNOWN) or ns.Prices.Money(step.cost)
        pane:Add({ indent = 1, itemID = r.o, text = text, right = right,
            onClick = function() ns.UI.OpenRecipe(step.recipeID, popup.charKey, true) end,
            tooltip = { r.n, L.PLAN_STEP_TIP } })
        entries[#entries + 1] = { recipeID = step.recipeID, times = step.crafts }
    end
    if plan.reached < plan.target then
        pane:Add({ indent = 1, text = L.PLAN_STUCK:format(plan.reached), color = W.RED })
    end
    if plan.unpriced then pane:Add({ indent = 1, text = L.PLAN_SOME_UNPRICED, color = W.GREY }) end
    pane:Gap()

    -- Materials for the whole plan.
    local ids = {}
    for itemID in pairs(plan.materials) do ids[#ids + 1] = itemID end
    table.sort(ids, function(a, b)
        return (Compat.ItemInfo(a) or tostring(a)) < (Compat.ItemInfo(b) or tostring(b))
    end)
    if #ids > 0 then
        pane:Add({ text = L.PLAN_MATERIALS, font = "GameFontNormal", color = W.GOLD })
        for _, itemID in ipairs(ids) do
            local m = plan.materials[itemID]
            local buy = math.max(0, m.need - m.have)
            local right = L.PLAN_NEED_HAVE:format(m.need, math.min(m.have, m.need))
            if buy > 0 then right = right .. "  " .. W.ColorText(W.RED, L.PLAN_BUY:format(buy)) end
            pane:Add({ indent = 1, itemID = itemID, text = Compat.ItemInfo(itemID) or ("item:" .. itemID), right = right })
        end
    end
    pane:Finish()
    popup.entries = entries
    popup.shop:SetEnabled(#entries > 0)
end

-- Open for a character's profession (toggles when it's already showing that one).
function PlannerUI.Show(charKey, skill)
    local p = ensure()
    if p:IsShown() and p.charKey == charKey and p.skill == skill then
        p:Hide()
        return
    end
    p.charKey, p.skill = charKey, skill
    p:Show()
    PlannerUI.Refresh()
end

function PlannerUI.Hide()
    if popup then popup:Hide() end
end
