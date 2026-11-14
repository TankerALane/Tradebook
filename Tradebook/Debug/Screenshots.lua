-- Debug/Screenshots.lua
-- /tb shots: pictures for the CurseForge/GitHub media section. Turns on the made-up account
-- (/tb fake), walks through the main screens, and takes one game screenshot per step. The
-- window's place on screen for each step is saved in TradebookDB.dev.shots so
-- scripts/crop_shots.py can cut each picture down to the window. Afterwards the tab,
-- window size and fake-data state are put back as they were.

local _, ns = ...
local L = ns.L

local Shots = {}
ns.Screenshots = Shots

Shots.DELAY = 1.5            -- seconds for the window to redraw before each picture
Shots.WIDTH, Shots.HEIGHT = 1100, 640

local TAILORING, LEATHERWORKING, ENGINEERING = 197, 165, 202

-- A recipe of the shown character with a reagent that can itself be crafted (so the reagent
-- tree has something to show). Returns recipeID and that reagent's index.
local function pickRecipe(skillLineID, charKey)
    local c = ns.db.characters[charKey or ns.charKey]
    local p = c and c.professions[skillLineID]
    if not p then return nil end
    local ids = {}
    for id in pairs(p.recipes) do if ns.db.recipes[id] and not ns.db.recipes[id].x then ids[#ids + 1] = id end end
    table.sort(ids, function(a, b) return a > b end)
    for _, id in ipairs(ids) do
        for i, node in ipairs(ns.Reagents.Tree(ns.db, id, 1)) do
            if #node.makers > 0 then return id, i end
        end
    end
    return ids[1], 1
end

local function profession(skillLineID, opts)
    return function()
        ns.UI.SelectTab(skillLineID)
        local view = ns.UI.views.profession
        local id, reagent = pickRecipe(skillLineID, view.charKey)
        if id then view:SelectRecipe(id) end
        if opts and opts.expand and reagent then
            view.details.expanded["r." .. reagent] = true
            view.details:Refresh()
        end
    end
end

-- Ask the game to load every item name/icon the pictures may show, before taking them.
local function preloadItems()
    local seen = {}
    local function want(itemID)
        if itemID and not seen[itemID] then
            seen[itemID] = true
            ns.Compat.Call("C_Item.RequestLoadItemDataByID", itemID)
        end
    end
    for _, c in pairs(ns.db.characters) do
        for _, p in pairs(c.professions) do
            for id in pairs(p.recipes) do
                local r = ns.db.recipes[id]
                if r then
                    want(r.o)
                    for _, reagent in ipairs(ns.Recipes.Reagents(r)) do want(reagent.itemID) end
                end
            end
        end
    end
    for _, ids in pairs(ns.Recipes.Camp(ns.db)) do
        for _, id in ipairs(ids) do
            for _, reagent in ipairs(ns.Recipes.Reagents(ns.db.recipes[id])) do want(reagent.itemID) end
        end
    end
end

-- The steps, in order. New steps go at the end so earlier pictures keep their numbers.
Shots.PLAN = {
    { name = "recipe", run = profession(TAILORING, { expand = true }) },
    { name = "skillup-filter", run = function()
        local f = ns.db.settings.filters
        f.skillup, f.skillupColors = true, { true, true, false }
        profession(TAILORING)()
    end },
    { name = "alt-readonly", run = function()
        local f = ns.db.settings.filters
        f.skillup, f.skillupColors = false, { true, true, true }
        profession(LEATHERWORKING, { expand = true })() -- only Thornick has it: shown read-only
    end },
    { name = "characters", run = function() ns.UI.ShowCharacters() end },
    { name = "camp", run = function()
        ns.fakeOpen = TAILORING -- Tailoring open: its camp recipes show Craft, Enchanting shows Open
        ns.UI.SelectTab("camp")
    end },
    { name = "who-can-craft", run = function() ns.UI.GlobalSearch("bolt") end },
    { name = "friends-guide", run = function()
        ns.UI.GlobalSearch("")
        ns.UI.SelectTab(ENGINEERING)
    end },
    { name = "shopping", run = function()
        profession(TAILORING)()
        ns.Shopping.ShowPinned()
    end, after = function() if ns.Shopping.Hide then ns.Shopping.Hide() end end },
}

-- Where the window is, as fractions of the screen (top-left origin), for cropping.
local function frameRect(frame)
    local s = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local left, right = frame:GetLeft() * s, frame:GetRight() * s
    local top, bottom = frame:GetTop() * s, frame:GetBottom() * s
    -- include the bottom tabs (they hang below the frame)
    bottom = bottom - 32 * s
    return { left = left / w, right = right / w, top = 1 - top / h, bottom = 1 - bottom / h }
end

function Shots.Run()
    if Shots.running then return end
    if InCombatLockdown() then
        ns.Print(L.SHOTS_COMBAT)
        return
    end
    Shots.running = true
    local wasFake = ns.Fake.IsOn()
    ns.Fake.On()
    ns.UI.Show()
    ns.UI.SetFakeBanner(false) -- keep the banner out of the pictures
    local frame = _G.TradebookFrame
    local saved = { tab = ns.db.settings.lastTab, w = frame:GetWidth(), h = frame:GetHeight() }
    local points = {}
    for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
    frame:SetSize(Shots.WIDTH, Shots.HEIGHT)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)

    TradebookDB.dev = TradebookDB.dev or {}
    local record = { startedAt = time(), steps = {} }
    TradebookDB.dev.shots = record
    ns.Print(L.SHOTS_START:format(#Shots.PLAN))
    preloadItems()

    local function finish()
        frame:SetSize(saved.w, saved.h)
        frame:ClearAllPoints()
        for _, p in ipairs(points) do frame:SetPoint(unpack(p)) end
        if wasFake then ns.UI.SetFakeBanner(true) else ns.Fake.Off() end
        if saved.tab then ns.UI.SelectTab(saved.tab) end
        Shots.running = false
        ns.Print(L.SHOTS_DONE:format(#Shots.PLAN))
    end

    local function step(i)
        local s = Shots.PLAN[i]
        if not s then return finish() end
        local ok, err = pcall(s.run)
        if not ok then ns.Debug("shot step failed", s.name, err) end
        C_Timer.After(Shots.DELAY, function()
            record.steps[i] = { name = s.name, rect = frameRect(frame) }
            Screenshot()
            C_Timer.After(1, function()
                if s.after then pcall(s.after) end
                step(i + 1)
            end)
        end)
    end
    C_Timer.After(3, function() step(1) end) -- give item names time to load
end
