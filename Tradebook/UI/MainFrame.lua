-- UI/MainFrame.lua
-- The Tradebook window: native portrait frame, header (global search, Characters,
-- Legacy, Default UI), a content inset that hosts one view at a time, and bottom tabs
-- for every profession plus Camp.

local _, ns = ...
local L, W = ns.L, ns.W

local UI = {}
ns.UI = UI

UI.views = {}
local frame, inset
local tabs = {}
local current = { tab = nil, view = nil }
local hideKeepsDefault = false

local CAMP = "camp"
local MIN_W, MIN_H = 940, 500

---------------------------------------------------------------------------
-- views
---------------------------------------------------------------------------

-- A view is { frame = <Frame>, Show = function(self, arg) end, Refresh = function(self) end }.
function UI.RegisterView(name, view)
    UI.views[name] = view
end

local function showView(name, arg)
    for key, view in pairs(UI.views) do
        if key ~= name and view.frame then view.frame:Hide() end
    end
    local view = UI.views[name]
    if not view then return end
    if not view.frame then view:Build(inset) end
    -- The skill bar belongs to the profession view; it sets it again when it refreshes.
    if name ~= "profession" then UI.SetRankBar(nil) end
    current.view = name
    view.frame:Show()
    view:Show(arg)
end

function UI.CurrentView()
    return current.view and UI.views[current.view]
end

function UI.Refresh()
    if not (frame and frame:IsShown()) then return end
    UI.UpdateTabs()
    local view = UI.CurrentView()
    if view and view.Refresh then view:Refresh() end
    ns.RankUp.Refresh()
end

---------------------------------------------------------------------------
-- tabs
---------------------------------------------------------------------------

local function tabIDs()
    local ids = {}
    for _, p in ipairs(ns.Professions.list) do ids[#ids + 1] = p.id end
    ids[#ids + 1] = CAMP
    return ids
end

local function tabTooltip(tab)
    GameTooltip:SetOwner(tab, "ANCHOR_TOP")
    if tab.key == CAMP then
        GameTooltip:SetText(L.CAMP_TITLE, 1, 1, 1)
    else
        local p = ns.Professions.Get(tab.key)
        GameTooltip:SetText(L[p.name] or p.name, 1, 1, 1)
        local with = ns.Characters.WithProfession(ns.db, tab.key, ns.charKey)
        if #with == 0 then
            GameTooltip:AddLine(L.TAB_NOBODY:format(L[p.name] or p.name), 0.7, 0.7, 0.7, true)
        else
            if ns.char and ns.char.professions[tab.key] then GameTooltip:AddLine(L.TAB_YOU, 0.3, 1, 0.3) end
            for _, c in ipairs(with) do
                local prof = c.professions[tab.key]
                GameTooltip:AddDoubleLine(W.ClassName(c), L.SKILL_RANK:format(prof.rank or 0, prof.max or 0))
            end
        end
        -- Friends (Fellowship Ledger, if installed); top few only.
        local friends = ns.Friends.For(tab.key)
        if #friends > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.FRIENDS_HEADER, W.GOLD:GetRGB())
            UI.views.guide.AddFriendsToTooltip(GameTooltip, friends, 5)
        end
    end
    GameTooltip:Show()
end

local function buildTabs()
    for i, key in ipairs(tabIDs()) do
        local tab = CreateFrame("Button", nil, frame, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab.key = key
        if key == CAMP then
            tab:SetText(L.TAB_CAMP)
        else
            local p = ns.Professions.Get(key)
            tab:SetText(L[p.name] or p.name)
        end
        tab.badge = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        tab.badge:SetPoint("TOPRIGHT", -6, -4)
        tab:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            UI.SelectTab(self.key, true)
        end)
        tab:SetScript("OnEnter", tabTooltip)
        tab:SetScript("OnLeave", GameTooltip_Hide)
        tabs[i] = tab
    end
    frame.Tabs = tabs
    PanelTemplates_SetNumTabs(frame, #tabs)
end

-- Lay the visible tabs out along the bottom, shrinking them to fit the window width.
-- Gathering tabs can be hidden in settings (their data is still saved).
local TAB_GAP = 3 -- space between tabs (no overlap)
local MAX_TAB_WIDTH = 110
function UI.LayoutTabs()
    if not frame then return end
    local visible = {}
    for _, tab in ipairs(tabs) do
        local p = tab.key ~= CAMP and ns.Professions.Get(tab.key)
        local show = not (p and p.gathering and not ns.db.settings.showGathering)
        tab:SetShown(show)
        if show then visible[#visible + 1] = tab end
    end
    -- PanelTabButtonTemplate re-sizes itself on show from the parent's tabPadding /
    -- minTabWidth / maxTabWidth, so the limits live on the frame, not just in this call.
    -- A tab must never be narrower than its fixed-size left + right cap art, or the
    -- stretchy middle (and its hover highlight) gets a negative width and draws wrongly.
    local first = visible[1]
    local caps = first and first.Left and first.Right and (first.Left:GetWidth() + first.Right:GetWidth()) or 40
    local minWidth = math.ceil(caps) + 6
    frame.tabPadding, frame.minTabWidth, frame.maxTabWidth = 0, minWidth, MAX_TAB_WIDTH
    local available = frame:GetWidth() - 16
    local natural = 0
    for _, tab in ipairs(visible) do
        PanelTemplates_TabResize(tab, 0, nil, minWidth, MAX_TAB_WIDTH)
        natural = natural + tab:GetWidth()
    end
    natural = natural + TAB_GAP * (#visible - 1)
    if natural > available then
        local each = math.max(minWidth, math.floor((available - TAB_GAP * (#visible - 1)) / #visible))
        frame.maxTabWidth = each
        for _, tab in ipairs(visible) do PanelTemplates_TabResize(tab, 0, nil, minWidth, each) end
    end
    local prev
    for _, tab in ipairs(visible) do
        tab:ClearAllPoints()
        if prev then
            tab:SetPoint("LEFT", prev, "RIGHT", TAB_GAP, 0)
        else
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 8, 2)
        end
        prev = tab
    end
end

function UI.UpdateTabs()
    if not frame then return end
    -- Select first: PanelTemplates restyles every tab, then we color them.
    for i, tab in ipairs(tabs) do
        if tab.key == current.tab then PanelTemplates_SetTab(frame, i) end
    end
    local counts = ns.Characters.ProfessionCounts(ns.db, ns.charKey)
    for _, tab in ipairs(tabs) do
        local text = tab.Text or tab:GetFontString()
        if tab.key == CAMP then
            tab.badge:SetText("")
            if text then text:SetTextColor(W.GOLD:GetRGB()) end
        else
            local n = counts[tab.key] or 0
            tab.badge:SetText(n > 0 and tostring(n) or "")
            local mine = ns.char and ns.char.professions[tab.key]
            if text then
                if n == 0 then
                    text:SetTextColor(W.GREY:GetRGB())
                elseif mine then
                    text:SetTextColor(W.GOLD:GetRGB())
                else
                    text:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
                end
            end
        end
    end
end

-- Select a bottom tab. fromClick: a real click (allowed to open the profession).
-- Browse every recipe of a profession none of your characters have (or go back to its
-- guide page). Remembered per profession.
function UI.SetBrowse(skillLineID, on)
    ns.db.settings.browse = ns.db.settings.browse or {}
    ns.db.settings.browse[skillLineID] = on or nil
    if on then ns.Scanner.CacheProfession(ns.db, skillLineID) end
    UI.SelectTab(skillLineID)
end

function UI.SelectTab(key, fromClick)
    if not frame then UI.Create() end
    current.tab = key
    ns.db.settings.lastTab = key
    if key == CAMP then
        showView("camp")
    else
        local mine = ns.char and ns.char.professions[key]
        if fromClick and mine then ns.Crafting.OpenProfession(key) end
        local browse = ns.db.settings.browse and ns.db.settings.browse[key]
        if #ns.Characters.WithProfession(ns.db, key, ns.charKey) == 0 and not browse then
            showView("guide", key)
        else
            showView("profession", key)
        end
    end
    UI.UpdateTabs()
end

-- Which tab to show when the window opens.
local function defaultTab()
    local open = ns.Scanner.OpenProfession()
    if open then return open.professionID end
    local last = ns.db.settings.lastTab
    if last then return last end
    for _, p in ipairs(ns.Professions.list) do
        if ns.char and ns.char.professions[p.id] then return p.id end
    end
    return ns.Professions.list[1].id
end

---------------------------------------------------------------------------
-- window
---------------------------------------------------------------------------

local function savePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    local w = ns.db.settings.window
    w.point, w.relPoint, w.x, w.y = point, relPoint, x, y
    w.width, w.height = frame:GetSize()
end

local function restorePosition()
    local w = ns.db.settings.window
    frame:SetSize(math.max(MIN_W, w.width or MIN_W), math.max(MIN_H, w.height or MIN_H))
    frame:ClearAllPoints()
    if w.point then
        frame:SetPoint(w.point, UIParent, w.relPoint or w.point, w.x or 0, w.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

-- Scale 1.0 in settings is drawn at DB.BASE_SCALE.
function UI.ApplyScale()
    if frame then frame:SetScale((ns.db.settings.scale or 1) * ns.DB.BASE_SCALE) end
end

local function buildHeader()
    frame:SetPortraitToAsset(ns.Minimap.ICON)
    if frame.SetTitle then frame:SetTitle(L.ADDON_TITLE) end

    local defaultBtn = W.Button(frame, L.DEFAULT_UI, 96, 20)
    defaultBtn:SetPoint("TOPRIGHT", -28, -1)
    defaultBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
    defaultBtn:SetScript("OnClick", function() ns.Takeover.UseDefault() end)
    W.Tooltip(defaultBtn, L.DEFAULT_UI_TIP, "ANCHOR_BOTTOM")

    local charsBtn = W.Button(frame, L.TAB_CHARACTERS, 100, 22)
    charsBtn:SetPoint("TOPRIGHT", -10, -30)
    charsBtn:SetScript("OnClick", function() UI.ShowCharacters() end)

    local legacyBtn = W.Button(frame, L.TAB_LEGACY, 80, 22)
    legacyBtn:SetPoint("RIGHT", charsBtn, "LEFT", -4, 0)
    legacyBtn:SetScript("OnClick", function() showView("legacy") end)

    local search = W.SearchBox(frame, 260, function(text)
        if ns.util.Query(text) then showView("search", text) elseif current.view == "search" then
            UI.SelectTab(current.tab or defaultTab())
        end
    end)
    search:SetPoint("TOPLEFT", 66, -32)
    if search.Instructions then search.Instructions:SetText(L.SEARCH_ALL) end
    frame.globalSearch = search

    -- Skill bar between the search box and the Legacy button, styled like the default
    -- Professions window (its frame and background art, blue fill).
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetHeight(29)
    bar:SetPoint("LEFT", search, "RIGHT", 18, -3)
    bar:SetPoint("RIGHT", legacyBtn, "LEFT", -18, -3)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAtlas("Professions-skillbar-bg", true)
    bar.bg:SetPoint("TOPLEFT")
    bar.fill = CreateFrame("StatusBar", nil, bar)
    bar.fill:SetPoint("TOPLEFT", 5, -3)
    bar.fill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar.fill:SetStatusBarColor(0.22, 0.52, 1.0)
    -- Border art and number sit on a frame above the fill (a child frame draws over its
    -- parent's textures, so the border can't live on `bar` itself).
    bar.fill:SetFrameLevel(bar:GetFrameLevel() + 1)
    local overlay = CreateFrame("Frame", nil, bar)
    overlay:SetAllPoints(bar)
    overlay:SetFrameLevel(bar.fill:GetFrameLevel() + 2)
    bar.border = overlay:CreateTexture(nil, "ARTWORK")
    bar.border:SetAtlas("Professions-skillbar-frame", true)
    bar.border:SetPoint("TOPLEFT")
    bar.text = overlay:CreateFontString(nil, "OVERLAY", "Number12FontOutline")
    bar.text:SetPoint("CENTER", bar.fill, "CENTER", 0, 0)
    bar:SetScript("OnSizeChanged", function(self, w)
        self.bg:SetWidth(w)
        self.border:SetWidth(w - 2)
        self.fill:SetSize(math.max(1, w - 12), 18)
    end)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self.tip, 1, 1, 1)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", GameTooltip_Hide)
    -- "Train <rank>" button at the right end of the bar (UI/RankUp.lua), when the viewed
    -- character can train the next rank.
    bar.rankUp = W.Button(overlay, "", 110, 18)
    bar.rankUp:SetPoint("RIGHT", bar.fill, "RIGHT", -2, 0)
    bar.rankUp:SetFrameLevel(overlay:GetFrameLevel() + 2)
    bar.rankUp:SetScript("OnClick", function(self) if self.action then self.action() end end)
    bar.rankUp:Hide()
    bar:Hide()
    frame.rankBar = bar
end

-- Show the skill bar for a character's profession, or hide it (rank == nil).
-- label: shown in front of the numbers (the profession name).
-- rankUp: { text, onClick } shows the "Train <rank>" button.
function UI.SetRankBar(rank, max, tip, label, rankUp)
    local bar = frame and frame.rankBar
    if not bar then return end
    bar.rankUp:SetShown(rankUp ~= nil)
    if rankUp then
        bar.rankUp:SetText(rankUp.text)
        bar.rankUp:SetWidth(math.max(90, bar.rankUp:GetFontString():GetStringWidth() + 24))
        bar.rankUp.action = rankUp.onClick
    end
    if not rank or not max or max <= 0 then
        bar:Hide()
        return
    end
    bar.fill:SetMinMaxValues(0, max)
    bar.fill:SetValue(math.min(rank, max))
    local numbers = L.SKILL_RANK:format(rank, max)
    bar.text:SetText(label and (label .. "  " .. numbers) or numbers)
    bar.tip = tip
    bar:Show()
end

function UI.Create()
    if frame then return frame end
    -- One named frame so ESC closes it (UISpecialFrames needs a global name).
    frame = CreateFrame("Frame", "TradebookFrame", UIParent, "PortraitFrameTemplate")
    frame:SetToplevel(true)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition()
    end)
    frame:Hide()
    tinsert(UISpecialFrames, "TradebookFrame")
    -- The template's X calls HideUIPanel, which does nothing in combat. Tradebook isn't
    -- a protected frame, so hide it directly (return false = skip HideUIPanel).
    frame.onCloseCallback = function()
        UI.Hide()
        return false
    end

    inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 6, -60)
    inset:SetPoint("BOTTOMRIGHT", -6, 6)
    frame.inset = inset

    local resize = CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate")
    resize:SetPoint("BOTTOMRIGHT", -2, 2)
    resize:SetFrameLevel(frame:GetFrameLevel() + 20)
    resize:Init(frame, MIN_W, MIN_H, 1800, 1200)
    resize:SetOnResizeStoppedCallback(savePosition)

    buildHeader()
    buildTabs()
    restorePosition()
    UI.ApplyScale()
    UI.LayoutTabs()
    frame:HookScript("OnSizeChanged", function() UI.LayoutTabs() end)

    frame:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        UI.SelectTab(defaultTab())
        -- Tabs resize themselves in their own OnShow; lay out again once that's done.
        C_Timer.After(0, UI.LayoutTabs)
    end)
    frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        if not hideKeepsDefault then ns.Takeover.OnTradebookHidden() end
        hideKeepsDefault = false
    end)

    -- Refresh on data changes, only while shown.
    local function refreshSoon() if frame:IsShown() then ns.Throttle("ui", 0.2, UI.Refresh) end end
    ns.Listen("RECIPES_UPDATED", function(skillLineID)
        if frame:IsShown() and current.tab == skillLineID and current.view == "guide" then
            UI.SelectTab(skillLineID)
        end
        refreshSoon()
    end)
    ns.Listen("PROFESSIONS_UPDATED", refreshSoon)
    ns.Listen("ITEMS_UPDATED", refreshSoon)
    ns.On("TRADE_SKILL_SHOW", function()
        if not frame:IsShown() then return end
        local open = ns.Scanner.OpenProfession()
        local onProfession = current.view == "profession" or current.view == "guide"
        if open and open.professionID ~= current.tab and onProfession then
            UI.SelectTab(open.professionID)
        end
    end)
    ns.On("TRADE_SKILL_CLOSE", refreshSoon)
    -- Item names/icons not cached yet show as "item:123" until the game loads them.
    ns.On("GET_ITEM_INFO_RECEIVED", refreshSoon)
    ns.On("ITEM_DATA_LOAD_RESULT", refreshSoon)
    ns.On("PLAYER_REGEN_ENABLED", refreshSoon)
    ns.On("PLAYER_REGEN_DISABLED", refreshSoon)
    return frame
end

-- Title shows a banner while the made-up account (/tb fake) is on.
function UI.SetFakeBanner(on)
    if not (frame and frame.SetTitle) then return end
    frame:SetTitle(on and (L.ADDON_TITLE .. "  " .. W.ColorText(W.RED, L.FAKE_BANNER)) or L.ADDON_TITLE)
end

function UI.Show()
    UI.Create()
    if not frame:IsShown() then frame:Show() end
end

-- keepDefault: hide Tradebook but leave the default window open (Default UI button).
function UI.Hide(keepDefault)
    if not (frame and frame:IsShown()) then return end
    hideKeepsDefault = keepDefault and true or false
    frame:Hide()
end

function UI.Toggle()
    if frame and frame:IsShown() then UI.Hide() else UI.Show() end
end

function UI.IsShown()
    return frame ~= nil and frame:IsShown()
end

-- The default window closed by itself (ESC, walking away): close Tradebook too.
function UI.OnDefaultClosed()
    if frame and frame:IsShown() then
        hideKeepsDefault = true
        frame:Hide()
    end
end

function UI.ShowCharacters()
    UI.Create()
    if not frame:IsShown() then frame:Show() end
    showView("characters")
end

function UI.GlobalSearch(text)
    UI.Create()
    if not frame:IsShown() then frame:Show() end
    frame.globalSearch:SetText(text or "")
    if ns.util.Query(text) then showView("search", text) end
end

-- Jump to a recipe (from search, characters, camp). fromClick: also open the profession.
function UI.OpenRecipe(recipeID, charKey, fromClick)
    local r = ns.db.recipes[recipeID]
    if not r then return end
    UI.SelectTab(r.s, fromClick)
    local view = UI.views.profession
    if current.view == "profession" and view.SelectRecipe then view:SelectRecipe(recipeID, charKey) end
end

function UI.ShowView(name, arg)
    showView(name, arg)
end
