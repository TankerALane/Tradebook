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

local BLACKSMITHING, TAILORING, ENGINEERING = 164, 197, 202

-- A recipe of the main fake character whose first reagent can itself be crafted (so the
-- reagent tree has something to show); else any known recipe of that profession.
local function pickRecipe(skillLineID)
    local p = ns.char and ns.char.professions[skillLineID]
    if not p then return nil end
    local ids = {}
    for id in pairs(p.recipes) do if ns.db.recipes[id] then ids[#ids + 1] = id end end
    table.sort(ids, function(a, b) return a > b end)
    for _, id in ipairs(ids) do
        local tree = ns.Reagents.Tree(ns.db, id, 1)
        for _, node in ipairs(tree) do
            if #node.makers > 0 then return id end
        end
    end
    return ids[1]
end

local function profession(skillLineID, opts)
    return function()
        ns.UI.SelectTab(skillLineID)
        local view = ns.UI.views.profession
        if opts and opts.charKey then
            view.charKey = opts.charKey
            view:Refresh()
        end
        local id = pickRecipe(skillLineID) or view.selected
        if id then view:SelectRecipe(id) end
        if opts and opts.expand then
            view.details.expanded["r.1"] = true
            view.details:Refresh()
        end
    end
end

-- The steps, in order. New steps go at the end so earlier pictures keep their numbers.
Shots.PLAN = {
    { name = "recipe", run = profession(BLACKSMITHING, { expand = true }) },
    { name = "skillup-filter", run = function()
        local f = ns.db.settings.filters
        f.skillup, f.skillupColors = true, { true, true, false }
        profession(BLACKSMITHING)()
    end },
    { name = "alt-readonly", run = function()
        local f = ns.db.settings.filters
        f.skillup, f.skillupColors = false, { true, true, true }
        profession(TAILORING, { charKey = ns.Characters.Key("Mirelle", ns.FakeData.SECOND) })()
    end },
    { name = "characters", run = function() ns.UI.ShowCharacters() end },
    { name = "camp", run = function() ns.UI.SelectTab("camp") end },
    { name = "who-can-craft", run = function() ns.UI.GlobalSearch("bolt") end },
    { name = "friends-guide", run = function()
        ns.UI.GlobalSearch("")
        ns.UI.SelectTab(ENGINEERING)
    end },
    { name = "shopping", run = function()
        profession(BLACKSMITHING)()
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
    step(1)
end
