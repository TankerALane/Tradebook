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

-- Which steps are ticked, per character and profession: settings.planSel[charKey:skill] =
-- { off = { [recipeID:to] = true } (unticked steps), firstTo = where the plan's first step
-- ended when the window closed }. Opening it again keeps the ticks, unless you've finished
-- that step since (your skill reached firstTo): then every step is ticked again.
local function selection(charKey, skill)
    local s = settings()
    s.planSel = s.planSel or {}
    local key = charKey .. ":" .. skill
    s.planSel[key] = s.planSel[key] or { off = {} }
    return s.planSel[key]
end

-- A plan stays as it is for FREEZE seconds (also when the window is closed and opened again),
-- so buying materials doesn't reshuffle the steps and costs you're shopping from. It's made
-- again when you change zones, change one of its options, press "Update plan", or the time
-- is up. What you have is still counted live (need / have / buy).
local FREEZE = 30 * 60
local frozen = {} -- [charKey:skill] = { plan, priced, at, zone, trainer, owned }

local function zone()
    return Compat.Call("C_Map.GetBestMapForUnit", "player")
end

local function stepKey(step)
    return step.recipeID .. ":" .. step.to
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
    popup.update = W.Button(popup, L.PLAN_UPDATE, 110, 22)
    popup.update:SetPoint("TOPRIGHT", -12, -30)
    popup.update:SetScript("OnClick", function()
        if popup.charKey and popup.skill then frozen[popup.charKey .. ":" .. popup.skill] = nil end
        PlannerUI.Refresh()
    end)
    W.Tooltip(popup.update, { L.PLAN_UPDATE, L.PLAN_UPDATE_TIP }, "ANCHOR_BOTTOM")
    -- While it's open: a new zone makes a new plan, and the "kept for" minutes count down.
    popup:SetScript("OnShow", function(self)
        self.ticker = self.ticker or C_Timer.NewTicker(60, function() PlannerUI.Refresh() end)
    end)
    ns.On("ZONE_CHANGED_NEW_AREA", function() PlannerUI.Refresh() end)

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
    -- Remember where the first step ends, to know next time whether you finished a step.
    popup:SetScript("OnHide", function(self)
        if self.charKey and self.skill and self.firstTo ~= nil then
            selection(self.charKey, self.skill).firstTo = self.firstTo or nil
        end
        self.firstTo = nil
        if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    end)
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
    -- The frozen plan, unless it's too old, you changed zones, or its options changed.
    local fkey = popup.charKey .. ":" .. skill
    local f = frozen[fkey]
    local now = GetTime()
    if not (f and now - f.at < FREEZE and f.zone == zone() and f.trainer == s.planTrainer
        and f.owned == s.planOwned) then
        local plan, priced = planFor(c, skill)
        f = { plan = plan, priced = priced, at = now, zone = zone(), trainer = s.planTrainer, owned = s.planOwned }
        frozen[fkey] = f
    end
    local plan, priced = f.plan, f.priced
    local age = math.floor((now - f.at) / 60)
    pane:Add({ indent = 1, color = W.GREY, text = L.PLAN_FROZEN:format(age, math.max(1, math.ceil((FREEZE - (now - f.at)) / 60))) })
    if not priced then pane:Add({ indent = 1, text = L.PLAN_NO_PRICES, color = W.GREY }) end
    pane:Gap()

    -- What you have now (the plan keeps its steps; "have" follows your bags and bank).
    local function haveNow(itemID)
        if not s.planOwned then return 0 end
        return (c.bags and c.bags[itemID] or 0) + (c.bank and c.bank[itemID] or 0)
    end
    -- Steps already finished (your skill passed their end) while the plan was frozen.
    local rank = prof.rank or 0
    local function done(step) return rank >= step.to end

    -- Steps.
    -- Ticked steps count for the cost, the materials and the shopping list.
    local sel = selection(popup.charKey, skill)
    local ticked, cost, anyUnpriced, nTicked = {}, 0, false, 0
    for i, step in ipairs(plan.steps) do
        ticked[i] = not sel.off[stepKey(step)] and not done(step)
        if ticked[i] then
            nTicked = nTicked + 1
            cost = cost + (step.cost or 0)
            anyUnpriced = anyUnpriced or step.unpriced
        end
    end
    -- Where the plan's first step ends now. Saved when the window closes: the ticks reset
    -- only once that step is finished after closing (finishing one with the window open
    -- doesn't count; you may be crafting one step and then fetching materials for the next).
    popup.firstTo = false
    local nOpen = 0
    for _, step in ipairs(plan.steps) do
        if not done(step) then
            nOpen = nOpen + 1
            if not popup.firstTo then popup.firstTo = step.to end
        end
    end
    local header = L.PLAN_STEPS
    if nTicked < nOpen then header = L.PLAN_STEPS_SOME:format(nTicked, nOpen) end
    pane:Add({ text = header, font = "GameFontNormal", color = W.GOLD, right = ns.Prices.Money(cost) })
    -- Need / have / buy, for the totals and a step's tooltip. Have: everything you have; buy:
    -- what's missing (a step's tooltip counts that step on its own).
    local function needHave(m)
        local buy = math.max(0, m.need - m.have)
        local right = L.PLAN_NEED_HAVE:format(m.need, m.have)
        if buy > 0 then right = right .. "  " .. W.ColorText(W.RED, L.PLAN_BUY:format(buy)) end
        return right
    end
    local function stepTooltip(step, r)
        local lines = { r.n }
        local ids = {}
        for itemID in pairs(step.materials or {}) do ids[#ids + 1] = itemID end
        table.sort(ids, function(a, b)
            return (Compat.ItemInfo(a) or tostring(a)) < (Compat.ItemInfo(b) or tostring(b))
        end)
        if #ids > 0 then
            lines[#lines + 1] = W.ColorText(W.GOLD, L.PLAN_STEP_MATERIALS:format(step.crafts))
            for _, itemID in ipairs(ids) do
                local tex = Compat.Call("C_Item.GetItemIconByID", itemID)
                local name = (tex and ("|T" .. tex .. ":0|t ") or "") .. (Compat.ItemInfo(itemID) or ("item:" .. itemID))
                lines[#lines + 1] = { "  " .. name,
                    needHave({ need = step.materials[itemID].need, have = haveNow(itemID) }) }
            end
        end
        if step.sure == false then lines[#lines + 1] = W.ColorText(W.DIFFICULTY[1], L.PLAN_NOT_SURE_TIP) end
        lines[#lines + 1] = W.ColorText(W.GREY, L.PLAN_STEP_TIP)
        return lines
    end

    local entries, totals = {}, {}
    for i, step in ipairs(plan.steps) do
        local r = ns.db.recipes[step.recipeID]
        local text = (step.sure == false and L.PLAN_STEP_CHANCE or L.PLAN_STEP):format(step.from, step.to,
            step.crafts, r.n)
        if step.learn then text = text .. "  " .. W.ColorText(W.GREY, L.PLAN_LEARN) end
        if step.sure == false then text = text .. "  " .. W.ColorText(W.DIFFICULTY[1], L.PLAN_NOT_SURE) end
        local right = step.unpriced and W.ColorText(W.GREY, L.PLAN_PRICE_UNKNOWN) or ns.Prices.Money(step.cost)
        local isDone = done(step)
        if not ticked[i] then
            text, right = W.ColorText(W.GREY, (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))), ""
            if isDone then right = W.ColorText(W.GREEN, L.PLAN_DONE) end
        end
        -- Done steps have no checkbox (nil); the others are ticked or not.
        local check
        if not isDone then check = ticked[i] and true or false end
        pane:Add({ indent = 0, itemID = r.o, spellID = not r.o and step.recipeID or nil, icon = r.i,
            text = text, right = right,
            check = check, checkSpace = isDone,
            onCheck = function(on)
                sel.off[stepKey(step)] = (not on) or nil
                PlannerUI.Refresh()
            end,
            onClick = function() ns.UI.OpenRecipe(step.recipeID, popup.charKey, true, step.crafts) end,
            tooltip = function() return stepTooltip(step, r) end })
        if ticked[i] then
            entries[#entries + 1] = { recipeID = step.recipeID, times = step.crafts }
            for itemID, m in pairs(step.materials or {}) do
                local t = totals[itemID]
                if not t then
                    t = { need = 0, have = haveNow(itemID) }
                    totals[itemID] = t
                end
                t.need = t.need + m.need
            end
        end
    end
    if plan.reached < plan.target then
        pane:Add({ indent = 1, text = L.PLAN_STUCK:format(plan.reached), color = W.RED })
    end
    if anyUnpriced then pane:Add({ indent = 1, text = L.PLAN_SOME_UNPRICED, color = W.GREY }) end
    pane:Gap()

    -- Materials for the ticked steps.
    local ids = {}
    for itemID in pairs(totals) do ids[#ids + 1] = itemID end
    table.sort(ids, function(a, b)
        return (Compat.ItemInfo(a) or tostring(a)) < (Compat.ItemInfo(b) or tostring(b))
    end)
    if #ids > 0 then
        pane:Add({ text = L.PLAN_MATERIALS, font = "GameFontNormal", color = W.GOLD })
        for _, itemID in ipairs(ids) do
            pane:Add({ indent = 1, itemID = itemID, text = Compat.ItemInfo(itemID) or ("item:" .. itemID),
                right = needHave(totals[itemID]) })
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
    -- Switching to another profession while open: remember the one being left, as closing would.
    if p:IsShown() and p.charKey and p.skill and p.firstTo ~= nil then
        selection(p.charKey, p.skill).firstTo = p.firstTo or nil
    end
    p.charKey, p.skill = charKey, skill
    -- Finished a step since it was last closed (your skill reached the end of its first
    -- step): start again with every step ticked. Otherwise the ticks stay as they were.
    local c = ns.db.characters[charKey]
    local prof = c and c.professions[skill]
    local sel = selection(charKey, skill)
    if sel.firstTo and prof and (prof.rank or 0) >= sel.firstTo then sel.off = {} end
    p.firstTo = nil
    p:Show()
    PlannerUI.Refresh()
end

function PlannerUI.Hide()
    if popup then popup:Hide() end
end
